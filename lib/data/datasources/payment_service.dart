import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/result.dart';
import 'payment_edge_client.dart';
import 'payment_gateway.dart';
import 'payment_models.dart';
import 'portone_gateway.dart';
import 'unsupported_payment_gateways.dart';

export 'payment_gateway.dart';
export 'payment_models.dart';
export 'portone_gateway.dart';
export 'unsupported_payment_gateways.dart';

/// Routes to the correct payment gateway based on currency
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(edgeClient: ref.watch(paymentEdgeClientProvider));
});

class PaymentService {
  PaymentService({PaymentEdgeClient? edgeClient})
    : _edgeClient = edgeClient ?? PaymentEdgeClient();

  final PaymentEdgeClient _edgeClient;

  PaymentGateway gatewayForCurrency(String currency) => switch (currency) {
    'KRW' => PortOneGateway(edgeClient: _edgeClient),
    'IDR' => XenditGateway(),
    _ => StripeGateway(),
  };

  Future<Result<PaymentResult>> pay({
    required String reservationId,
    required int amount,
    required String currency,
    required String description,
  }) {
    final gateway = gatewayForCurrency(currency);
    return gateway.initiatePayment(
      reservationId: reservationId,
      amount: amount,
      currency: currency,
      description: description,
    );
  }

  Future<Result<void>> refund({
    required String paymentRef,
    required String currency,
    required String authJwt,
    int? amount,
  }) {
    final gateway = gatewayForCurrency(currency);
    return gateway.refund(paymentRef, amount: amount, authJwt: authJwt);
  }

  /// Calls the `settle-reservation` Edge Function. Refunds the deposit
  /// portion to the borrower and advances state `returned → settled`.
  /// Lender-only — see docs/escrow-state-machine.md.
  ///
  /// Returned int is the deposit amount actually refunded by PortOne
  /// (may differ from the reservation's `deposit` column if PortOne
  /// adjusted for fees).
  Future<Result<int>> settle({
    required String reservationId,
    required String authJwt,
  }) async {
    final result = await _edgeClient.postJson(
      functionName: 'settle-reservation',
      authJwt: authJwt,
      body: {'reservation_id': reservationId},
      timeoutMessage: 'Settlement request timed out',
      failureMessage: 'Settlement failed',
    );
    if (result.isFailure) {
      return Fail(result.failure);
    }
    return Success((result.value['refunded_amount'] as num?)?.toInt() ?? 0);
  }
}
