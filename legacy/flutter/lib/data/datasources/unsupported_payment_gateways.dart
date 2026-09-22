import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import 'payment_gateway.dart';
import 'payment_models.dart';

/// Xendit (Indonesia) implementation — not yet wired to Xendit. Each method
/// returns a typed failure so calling code surfaces a clear "currency not
/// supported" message instead of silently succeeding.
class XenditGateway implements PaymentGateway {
  @override
  Future<Result<PaymentResult>> initiatePayment({
    required String reservationId,
    required int amount,
    required String currency,
    required String description,
  }) async {
    return const Fail(ServerFailure('Xendit not yet configured'));
  }

  @override
  Future<Result<PaymentResult>> checkStatus(
    String paymentRef, {
    String? authJwt,
  }) async {
    return const Fail(ServerFailure('Xendit not yet configured'));
  }

  @override
  Future<Result<void>> refund(
    String paymentRef, {
    int? amount,
    String? authJwt,
  }) async {
    return const Fail(ServerFailure('Xendit not yet configured'));
  }
}

/// Stripe (Japan/Global) implementation — not yet wired to Stripe.
class StripeGateway implements PaymentGateway {
  @override
  Future<Result<PaymentResult>> initiatePayment({
    required String reservationId,
    required int amount,
    required String currency,
    required String description,
  }) async {
    return const Fail(ServerFailure('Stripe not yet configured'));
  }

  @override
  Future<Result<PaymentResult>> checkStatus(
    String paymentRef, {
    String? authJwt,
  }) async {
    return const Fail(ServerFailure('Stripe not yet configured'));
  }

  @override
  Future<Result<void>> refund(
    String paymentRef, {
    int? amount,
    String? authJwt,
  }) async {
    return const Fail(ServerFailure('Stripe not yet configured'));
  }
}
