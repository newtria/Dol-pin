import '../../core/errors/result.dart';
import 'payment_models.dart';

/// Abstract payment gateway interface.
///
/// Gateway implementations are responsible for their own provider-specific
/// request shapes; the [Result] error branch should carry a payment failure so
/// UI can render a consistent message.
abstract class PaymentGateway {
  Future<Result<PaymentResult>> initiatePayment({
    required String reservationId,
    required int amount,
    required String currency,
    required String description,
  });

  /// Verifies a prior charge. [paymentRef] is the provider's transaction id
  /// (PortOne `imp_uid`, Stripe `payment_intent_id`, Xendit `invoice_id`).
  Future<Result<PaymentResult>> checkStatus(
    String paymentRef, {
    String? authJwt,
  });

  /// Requests a refund. [paymentRef] matches the one from [checkStatus].
  Future<Result<void>> refund(
    String paymentRef, {
    int? amount,
    String? authJwt,
  });
}
