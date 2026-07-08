import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import 'payment_edge_client.dart';
import 'payment_models.dart';
import 'portone_payment_mapper.dart';

export 'payment_models.dart';

/// Abstract payment gateway interface.
///
/// Gateway implementations are responsible for their own provider-specific
/// request shapes; the [Result] error branch should carry a [PaymentFailure]
/// so UI can render a consistent message.
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

/// PortOne (Korea) implementation
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
