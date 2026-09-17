import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import 'payment_edge_client.dart';
import 'payment_gateway.dart';
import 'payment_models.dart';
import 'portone_payment_mapper.dart';

/// PortOne (Korea) implementation.
class PortOneGateway implements PaymentGateway {
  PortOneGateway({PaymentEdgeClient? edgeClient})
    : _edgeClient = edgeClient ?? PaymentEdgeClient();

  final PaymentEdgeClient _edgeClient;

  static String _generateMerchantUid(String reservationId) =>
      'dolpin_${reservationId}_${DateTime.now().millisecondsSinceEpoch}';

  /// Build payment params for the PaymentScreen widget.
  /// The actual payment happens in IamportPayment (WebView).
  PortOnePaymentParams buildParams({
    required String reservationId,
    required int amount,
    required String itemName,
    required String buyerName,
    required String buyerTel,
    String pgProvider = 'html5_inicis',
    String payMethod = 'card',
  }) {
    return PortOnePaymentParams(
      merchantUid: _generateMerchantUid(reservationId),
      pgProvider: pgProvider,
      payMethod: payMethod,
      amount: amount,
      itemName: itemName,
      buyerName: buyerName,
      buyerTel: buyerTel,
    );
  }

  // ---------------------------------------------------------------------------
  // IMPORTANT: Payment verification (checkStatus) and refund MUST happen
  // server-side. The PortOne imp_secret must NEVER be included in client code.
  // The `verify-payment` and `refund-payment` Supabase Edge Functions hold the
  // imp_secret in server-side environment variables and call the PortOne API
  // on the client's behalf.
  // ---------------------------------------------------------------------------

  @override
  Future<Result<PaymentResult>> initiatePayment({
    required String reservationId,
    required int amount,
    required String currency,
    required String description,
  }) async {
    // Payment is initiated via PaymentScreen widget (IamportPayment).
    // This method returns a pending result with the merchant UID. `impUid` is
    // unknown until the PortOne WebView callback fires.
    return Success(
      PaymentResult(
        merchantUid: _generateMerchantUid(reservationId),
        impUid: null,
        status: PaymentStatus.pending,
        amount: amount,
        currency: currency,
      ),
    );
  }

  /// Verifies payment status via the `verify-payment` edge function.
  /// The server holds the imp_secret and calls the PortOne API on our behalf.
  @override
  Future<Result<PaymentResult>> checkStatus(
    String paymentRef, {
    String? authJwt,
  }) async {
    if (authJwt == null || authJwt.isEmpty) {
      return const Fail(PaymentFailure('Authentication required'));
    }
    final result = await _edgeClient.postJson(
      functionName: 'verify-payment',
      authJwt: authJwt,
      body: {'imp_uid': paymentRef},
      timeoutMessage: 'Payment verification timed out',
      failureMessage: 'Failed to verify payment',
    );
    if (result.isFailure) {
      return Fail(result.failure);
    }
    return Success(PortOnePaymentMapper.fromVerificationJson(result.value));
  }

  /// Requests a refund via the `refund-payment` edge function.
  @override
  Future<Result<void>> refund(
    String paymentRef, {
    int? amount,
    String? authJwt,
  }) async {
    if (authJwt == null || authJwt.isEmpty) {
      return const Fail(PaymentFailure('Authentication required'));
    }
    final body = <String, dynamic>{'imp_uid': paymentRef};
    if (amount != null) body['amount'] = amount;

    final result = await _edgeClient.postJson(
      functionName: 'refund-payment',
      authJwt: authJwt,
      body: body,
      timeoutMessage: 'Refund request timed out',
      failureMessage: 'Refund failed',
    );
    if (result.isFailure) {
      return Fail(result.failure);
    }
    return const Success(null);
  }
}
