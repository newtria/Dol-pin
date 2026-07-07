import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/enums.dart';
import '../../../core/errors/failures.dart';
import '../../../core/errors/result.dart';
import '../../../data/datasources/payment_service.dart';
import '../../../data/datasources/storage_service.dart';
import '../../../data/datasources/supabase_client.dart';
import '../../../data/models/reservation_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/reservation_repository.dart';

final reservationActionControllerProvider =
    Provider<ReservationActionController>((ref) {
      return ReservationActionController(
        reservationRepository: ref.watch(reservationRepositoryProvider),
        storageService: ref.watch(storageServiceProvider),
        paymentService: ref.watch(paymentServiceProvider),
        chatRepository: ref.watch(chatRepositoryProvider),
        authRepository: ref.watch(authRepositoryProvider),
        supabaseClient: ref.watch(supabaseProvider),
      );
    });

class ReservationChatTarget {
  const ReservationChatTarget({
    required this.roomId,
    required this.otherUserId,
    this.partnerNickname,
  });

  final String roomId;
  final String otherUserId;
  final String? partnerNickname;
}

class ReservationActionController {
  const ReservationActionController({
    required ReservationRepository reservationRepository,
    required StorageService storageService,
    required PaymentService paymentService,
    required ChatRepository chatRepository,
    required AuthRepository authRepository,
    required SupabaseClient supabaseClient,
  }) : _reservationRepository = reservationRepository,
       _storageService = storageService,
       _paymentService = paymentService,
       _chatRepository = chatRepository,
       _authRepository = authRepository,
       _supabaseClient = supabaseClient;

  final ReservationRepository _reservationRepository;
  final StorageService _storageService;
  final PaymentService _paymentService;
  final ChatRepository _chatRepository;
  final AuthRepository _authRepository;
  final SupabaseClient _supabaseClient;

  Set<ReservationStatus> legalNextStates({
    required ReservationModel reservation,
    required String userId,
  }) {
    return _reservationRepository.legalNextStates(
      reservation: reservation,
      userId: userId,
    );
  }

  bool canOpenChat(ReservationModel reservation) {
    final status = ReservationStatus.fromString(reservation.status);
    return status != ReservationStatus.pending &&
        status != ReservationStatus.cancelled;
  }

  Future<Result<ReservationStatus>> cancel(String reservationId) {
    return _reservationRepository.cancel(reservationId);
  }

  Future<Result<ReservationStatus>> confirmPickup(String reservationId) {
    return _reservationRepository.confirmPickup(reservationId);
  }

  Future<Result<ReservationStatus>> openDispute(
    String reservationId, {
    String? reason,
  }) {
    return _reservationRepository.dispute(reservationId, reason: reason);
  }

  Future<Result<ReservationStatus>> confirmReturnPhoto({
    required ReservationModel reservation,
    required String userId,
    required File file,
  }) async {
    final uploadResult = await _storageService.uploadReturnPhoto(
      userId: userId,
      reservationId: reservation.id,
      file: file,
    );
    if (uploadResult.isFailure) {
      return Fail<ReservationStatus>(uploadResult.failure);
    }

    return _reservationRepository.confirmReturn(
      reservation.id,
      returnPhoto: uploadResult.value,
    );
  }

  Future<Result<int>> settle(ReservationModel reservation) {
    final authJwt = _supabaseClient.auth.currentSession?.accessToken;
    if (authJwt == null || authJwt.isEmpty) {
      return Future.value(
        const Fail<int>(AuthFailure('Authentication required')),
      );
    }
    return _paymentService.settle(
      reservationId: reservation.id,
      authJwt: authJwt,
    );
  }

  Future<Result<void>> refundPaid(ReservationModel reservation) {
    final paymentId = reservation.paymentId;
    if (paymentId == null || paymentId.isEmpty) {
      return Future.value(
        const Fail<void>(PaymentFailure('Payment reference is missing')),
      );
    }

    final authJwt = _supabaseClient.auth.currentSession?.accessToken;
    if (authJwt == null || authJwt.isEmpty) {
      return Future.value(
        const Fail<void>(AuthFailure('Authentication required')),
      );
    }

    return _paymentService.refund(
      paymentRef: paymentId,
      currency: reservation.currency,
      authJwt: authJwt,
    );
  }

  Future<Result<ReservationChatTarget>> openChat({
    required ReservationModel reservation,
    required String currentUserId,
  }) async {
    if (!canOpenChat(reservation)) {
      return const Fail(
        ValidationFailure('Chat is available after payment confirmation'),
      );
    }

    final otherUserId = currentUserId == reservation.borrowerId
        ? reservation.lenderId
        : reservation.borrowerId;
    final roomResult = await _chatRepository.getOrCreateRoom(
      currentUserId,
      otherUserId,
      itemId: reservation.itemId,
      reservationId: reservation.id,
    );
    if (roomResult.isFailure) {
      return Fail<ReservationChatTarget>(roomResult.failure);
    }

    final profileResult = await _authRepository.getProfile(otherUserId);
    final partnerNickname = profileResult.when<String?>(
      success: (profile) => profile?.nickname,
      failure: (_) => null,
    );
    return Success(
      ReservationChatTarget(
        roomId: roomResult.value,
        otherUserId: otherUserId,
        partnerNickname: partnerNickname,
      ),
    );
  }
}
