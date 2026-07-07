import '../../../core/errors/failures.dart';
import '../../../core/errors/result.dart';
import '../../../data/datasources/payment_service.dart';
import '../../../data/models/rental_item_model.dart';

typedef PaymentRetryDelay = Duration Function(int attemptIndex);

class ReservationCheckoutPolicy {
  const ReservationCheckoutPolicy._();

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
