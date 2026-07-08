import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../core/errors/result.dart';
import '../../../data/datasources/payment_service.dart';
import '../../../data/datasources/supabase_client.dart';
import '../../../data/models/rental_item_model.dart';
import '../../../data/models/reservation_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/reservation_repository.dart';

final reservationCheckoutControllerProvider =
    Provider<ReservationCheckoutController>((ref) {
      return ReservationCheckoutController(
        reservationRepository: ref.watch(reservationRepositoryProvider),
        authRepository: ref.watch(authRepositoryProvider),
        chatRepository: ref.watch(chatRepositoryProvider),
        paymentService: ref.watch(paymentServiceProvider),
        supabaseClient: ref.watch(supabaseProvider),
      );
    });

typedef PaymentRetryDelay = Duration Function(int attemptIndex);

class ReservationCheckoutSelection {
  const ReservationCheckoutSelection({
    required this.rentalDate,
    required this.returnDate,
  });

  final DateTime rentalDate;
  final DateTime returnDate;
}

enum ReservationCheckoutValidationError {
  datesOutsideAvailability,
  paymentNotConfigured,
}

class ReservationCheckoutQuote {
  const ReservationCheckoutQuote({
    required this.selection,
    required this.days,
    required this.rentalFee,
    required this.deposit,
    required this.total,
    required this.currency,
    this.validationError,
  });

  final ReservationCheckoutSelection selection;
  final int days;
  final int rentalFee;
  final int deposit;
  final int total;
  final String currency;
  final ReservationCheckoutValidationError? validationError;
}

class ReservationCheckoutPolicy {
  const ReservationCheckoutPolicy._();

  static ReservationCheckoutSelection normalizeSelection(
    DateTime rentalDate,
    DateTime returnDate,
  ) {
    return ReservationCheckoutSelection(
      rentalDate: rentalDate,
      returnDate: returnDate.isAfter(rentalDate)
          ? returnDate
          : rentalDate.add(const Duration(days: 1)),
    );
  }

  static int rentalDays(DateTime rentalDate, DateTime returnDate) =>
      returnDate.difference(rentalDate).inDays.clamp(1, 365);

  static bool isWithinAvailability({
    required RentalItemModel item,
    required DateTime rentalDate,
    required DateTime returnDate,
  }) {
    final availableFrom = item.availableFrom;
    final availableTo = item.availableTo;
    if (availableFrom == null || availableTo == null) return true;
    return !rentalDate.isBefore(availableFrom) &&
        !returnDate.isAfter(availableTo);
  }

  static bool isCheckoutCurrencyConfigured(String currency) =>
      currency == 'KRW';

  static ReservationCheckoutQuote quote({
    required RentalItemModel item,
    required DateTime rentalDate,
    required DateTime returnDate,
  }) {
    final selection = normalizeSelection(rentalDate, returnDate);
    final days = rentalDays(selection.rentalDate, selection.returnDate);
    final rentalFee = item.dailyPrice * days;
    final validationError =
        !isWithinAvailability(
          item: item,
          rentalDate: selection.rentalDate,
          returnDate: selection.returnDate,
        )
        ? ReservationCheckoutValidationError.datesOutsideAvailability
        : !isCheckoutCurrencyConfigured(item.currency)
        ? ReservationCheckoutValidationError.paymentNotConfigured
        : null;

    return ReservationCheckoutQuote(
      selection: selection,
      days: days,
      rentalFee: rentalFee,
      deposit: item.deposit,
      total: rentalFee + item.deposit,
      currency: item.currency,
      validationError: validationError,
    );
  }
}

class PaymentVerificationRetrier {
  const PaymentVerificationRetrier({
    this.attempts = 3,
    this.retryDelay = _defaultRetryDelay,
  });

  final int attempts;
  final PaymentRetryDelay retryDelay;

  static Duration _defaultRetryDelay(int attemptIndex) =>
      Duration(seconds: attemptIndex + 1);

  Future<Result<PaymentResult>> verify({
    required PaymentGateway gateway,
    required String paymentRef,
    String? authJwt,
  }) async {
    if (attempts <= 0) {
      return const Fail(ValidationFailure('Verification attempts must be > 0'));
    }

    Result<PaymentResult>? lastResult;
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      lastResult = await gateway.checkStatus(paymentRef, authJwt: authJwt);
      if (lastResult.isSuccess) return lastResult;
      if (attempt < attempts - 1) {
        await Future<void>.delayed(retryDelay(attempt));
      }
    }

    return lastResult ??
        const Fail(PaymentFailure('Payment verification did not run'));
  }
}

enum CheckoutNextStep { chat, reservationDetail, stay }

class PortOneCheckoutAttempt {
  const PortOneCheckoutAttempt({
    required this.reservation,
    required this.item,
    required this.lenderName,
    required this.paymentParams,
  });

  final ReservationModel reservation;
  final RentalItemModel item;
  final String lenderName;
  final PortOnePaymentParams paymentParams;
}

class CheckoutCompletion {
  const CheckoutCompletion({
    required this.nextStep,
    required this.reservationId,
    required this.lenderId,
    required this.lenderName,
    this.roomId,
    this.failure,
  });

  final CheckoutNextStep nextStep;
  final String reservationId;
  final String lenderId;
  final String lenderName;
  final String? roomId;
  final Failure? failure;
}

class ReservationCheckoutController {
  const ReservationCheckoutController({
    required ReservationRepository reservationRepository,
    required AuthRepository authRepository,
    required ChatRepository chatRepository,
    required PaymentService paymentService,
    required SupabaseClient supabaseClient,
    PaymentVerificationRetrier verificationRetrier =
        const PaymentVerificationRetrier(),
  }) : _reservationRepository = reservationRepository,
       _authRepository = authRepository,
       _chatRepository = chatRepository,
       _paymentService = paymentService,
       _supabaseClient = supabaseClient,
       _verificationRetrier = verificationRetrier;

  final ReservationRepository _reservationRepository;
  final AuthRepository _authRepository;
  final ChatRepository _chatRepository;
  final PaymentService _paymentService;
  final SupabaseClient _supabaseClient;
  final PaymentVerificationRetrier _verificationRetrier;

  Future<Result<PortOneCheckoutAttempt>> startPortOneCheckout({
    required RentalItemModel item,
    required DateTime rentalDate,
    required DateTime returnDate,
    required String buyerName,
    required String buyerTel,
    required String fallbackLenderName,
  }) async {
    if (!ReservationCheckoutPolicy.isCheckoutCurrencyConfigured(
      item.currency,
    )) {
      return Fail(
        PaymentFailure('Payment not configured for ${item.currency}'),
      );
    }

    final gateway = _paymentService.gatewayForCurrency(item.currency);
    if (gateway is! PortOneGateway) {
      return Fail(
        PaymentFailure('Payment not configured for ${item.currency}'),
      );
    }

    final reservationResult = await _reservationRepository.createIntent(
      itemId: item.id,
      rentalDate: rentalDate,
      returnDate: returnDate,
    );
    if (reservationResult.isFailure) {
      return Fail(reservationResult.failure);
    }
    final reservation = reservationResult.value;

    final profileResult = await _authRepository.getProfile(item.lenderId);
    final lenderName = profileResult.when(
      success: (user) => user?.nickname ?? fallbackLenderName,
      failure: (_) => fallbackLenderName,
    );

    final params = gateway.buildParams(
      reservationId: reservation.id,
      amount: reservation.totalPaid,
      itemName: item.title,
      buyerName: buyerName,
      buyerTel: buyerTel,
    );

    final attemptResult = await _reservationRepository.startPaymentAttempt(
      reservationId: reservation.id,
      merchantUid: params.merchantUid,
    );
    if (attemptResult.isFailure) {
      return Fail(attemptResult.failure);
    }

    return Success(
      PortOneCheckoutAttempt(
        reservation: reservation,
        item: item,
        lenderName: lenderName,
        paymentParams: params,
      ),
    );
  }

  Future<Result<CheckoutCompletion>> completePortOneCheckout({
    required PortOneCheckoutAttempt attempt,
    required PaymentResult? paymentResult,
    required String currentUserId,
  }) async {
    final reservation = attempt.reservation;
    final item = attempt.item;

    if (paymentResult == null ||
        paymentResult.status != PaymentStatus.success) {
      await _reservationRepository.cancel(reservation.id);
      return Success(
        CheckoutCompletion(
          nextStep: CheckoutNextStep.stay,
          reservationId: reservation.id,
          lenderId: item.lenderId,
          lenderName: attempt.lenderName,
          failure: const PaymentFailure('Payment was not completed'),
        ),
      );
    }

    final impUid = paymentResult.impUid;
    if (impUid == null || impUid.isEmpty) {
      return Success(
        CheckoutCompletion(
          nextStep: CheckoutNextStep.reservationDetail,
          reservationId: reservation.id,
          lenderId: item.lenderId,
          lenderName: attempt.lenderName,
          failure: const PaymentFailure('Payment verification failed'),
        ),
      );
    }

    final gateway = _paymentService.gatewayForCurrency(item.currency);
    if (gateway is! PortOneGateway) {
      return Fail(
        PaymentFailure('Payment not configured for ${item.currency}'),
      );
    }

    final verificationResult = await _verificationRetrier.verify(
      gateway: gateway,
      paymentRef: impUid,
      authJwt: _supabaseClient.auth.currentSession?.accessToken,
    );
    if (verificationResult.isFailure) {
      return Success(
        CheckoutCompletion(
          nextStep: CheckoutNextStep.reservationDetail,
          reservationId: reservation.id,
          lenderId: item.lenderId,
          lenderName: attempt.lenderName,
          failure: verificationResult.failure,
        ),
      );
    }

    if (verificationResult.value.status != PaymentStatus.success) {
      await _reservationRepository.cancel(reservation.id);
      return Success(
        CheckoutCompletion(
          nextStep: CheckoutNextStep.stay,
          reservationId: reservation.id,
          lenderId: item.lenderId,
          lenderName: attempt.lenderName,
          failure: const PaymentFailure('Payment verification failed'),
        ),
      );
    }

    var roomId = verificationResult.value.roomId;
    if (roomId == null || roomId.isEmpty) {
      final roomResult = await _chatRepository.getOrCreateRoom(
        currentUserId,
        item.lenderId,
        itemId: item.id,
        reservationId: reservation.id,
      );
      if (roomResult.isSuccess) {
        roomId = roomResult.value;
      }
    }

    if (roomId == null || roomId.isEmpty) {
      return Success(
        CheckoutCompletion(
          nextStep: CheckoutNextStep.reservationDetail,
          reservationId: reservation.id,
          lenderId: item.lenderId,
          lenderName: attempt.lenderName,
        ),
      );
    }

    return Success(
      CheckoutCompletion(
        nextStep: CheckoutNextStep.chat,
        reservationId: reservation.id,
        lenderId: item.lenderId,
        lenderName: attempt.lenderName,
        roomId: roomId,
      ),
    );
  }
}
