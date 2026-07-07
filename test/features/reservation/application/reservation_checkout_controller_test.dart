import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/core/errors/result.dart';
import 'package:dolpin/data/datasources/payment_service.dart';
import 'package:dolpin/data/models/rental_item_model.dart';
import 'package:dolpin/features/reservation/application/reservation_checkout_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReservationCheckoutPolicy', () {
    test('calculates at least one rental day', () {
      final start = DateTime(2026, 6, 23);
      final end = DateTime(2026, 6, 23);

      expect(ReservationCheckoutPolicy.rentalDays(start, end), 1);
    });

    test('checks item availability boundaries', () {
      final item = _item(
        availableFrom: DateTime(2026, 6, 20),
        availableTo: DateTime(2026, 6, 30),
      );

      expect(
        ReservationCheckoutPolicy.isWithinAvailability(
          item: item,
          rentalDate: DateTime(2026, 6, 23),
          returnDate: DateTime(2026, 6, 25),
        ),
        isTrue,
      );
      expect(
        ReservationCheckoutPolicy.isWithinAvailability(
          item: item,
          rentalDate: DateTime(2026, 6, 19),
          returnDate: DateTime(2026, 6, 25),
        ),
        isFalse,
      );
      expect(
        ReservationCheckoutPolicy.isWithinAvailability(
          item: item,
          rentalDate: DateTime(2026, 6, 23),
          returnDate: DateTime(2026, 7, 1),
        ),
        isFalse,
      );
    });

    test('keeps checkout currency support explicit', () {
      expect(
        ReservationCheckoutPolicy.isCheckoutCurrencyConfigured('KRW'),
        true,
      );
      expect(
        ReservationCheckoutPolicy.isCheckoutCurrencyConfigured('IDR'),
        false,
      );
      expect(
        ReservationCheckoutPolicy.isCheckoutCurrencyConfigured('JPY'),
        false,
      );
    });
  });

  group('PaymentVerificationRetrier', () {
    test('returns success after a retry', () async {
      final gateway = _FakeGateway([
        const Fail(PaymentFailure('pending')),
        const Success(
          PaymentResult(
            merchantUid: 'merchant-1',
            impUid: 'imp-1',
            status: PaymentStatus.success,
            amount: 1000,
            currency: 'KRW',
          ),
        ),
      ]);
      final retrier = PaymentVerificationRetrier(
        retryDelay: (_) => Duration.zero,
      );

      final result = await retrier.verify(
        gateway: gateway,
        paymentRef: 'imp-1',
        authJwt: 'jwt',
      );

      expect(result.isSuccess, isTrue);
      expect(result.value.status, PaymentStatus.success);
      expect(gateway.checkStatusCalls, 2);
    });

    test('returns final failure after all attempts are exhausted', () async {
      final gateway = _FakeGateway([
        const Fail(PaymentFailure('first')),
        const Fail(PaymentFailure('second')),
      ]);
      final retrier = PaymentVerificationRetrier(
        attempts: 2,
        retryDelay: (_) => Duration.zero,
      );

      final result = await retrier.verify(
        gateway: gateway,
        paymentRef: 'imp-1',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure.message, 'second');
      expect(gateway.checkStatusCalls, 2);
    });
  });
}

RentalItemModel _item({DateTime? availableFrom, DateTime? availableTo}) {
  return RentalItemModel(
    id: 'item-1',
    lenderId: 'lender-1',
    category: 'lightstick',
    title: 'Lightstick',
    photos: const [],
    dailyPrice: 1000,
    currency: 'KRW',
    deposit: 5000,
    pickupMethod: 'direct',
    availableFrom: availableFrom,
    availableTo: availableTo,
  );
}

class _FakeGateway implements PaymentGateway {
  _FakeGateway(this._responses);

  final List<Result<PaymentResult>> _responses;
  int checkStatusCalls = 0;

  @override
  Future<Result<PaymentResult>> checkStatus(
    String paymentRef, {
    String? authJwt,
  }) async {
    final index = checkStatusCalls;
    checkStatusCalls += 1;
    return _responses[index.clamp(0, _responses.length - 1)];
  }

  @override
  Future<Result<PaymentResult>> initiatePayment({
    required String reservationId,
    required int amount,
    required String currency,
    required String description,
  }) async {
    return const Fail(PaymentFailure('not used'));
  }

  @override
  Future<Result<void>> refund(
    String paymentRef, {
    int? amount,
    String? authJwt,
  }) async {
    return const Fail(PaymentFailure('not used'));
  }
}
