import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/env.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';

/// Timeout for every outbound payment-gateway request. Payment flows are
/// user-blocking so indefinite hangs are the worst possible failure mode.
const Duration _paymentTimeout = Duration(seconds: 20);

enum PaymentStatus {
  success,
  pending,
  failed;

  static PaymentStatus fromString(String s) =>
      values.firstWhere((e) => e.name == s, orElse: () => failed);
}

/// Payment result data.
///
/// Two distinct identifiers live here because PortOne (and most PG providers)
/// expose a merchant-side order id and a PG-side transaction id that are
/// generated at different points in the flow:
///
///   * [merchantUid] — our own order id, generated client-side before payment
///     is initiated (e.g. `dolpin_<reservationId>_<epoch>`). Always set.
///   * [impUid]      — PortOne's imp_uid, issued **after** PortOne charges the
///     card. Null until the PortOne WebView callback fires.
///
/// The old single-field `transactionId` conflated the two and made it
/// impossible for callers to know which identifier to pass to server-side
/// verification or refund endpoints.
class PaymentResult {
  const PaymentResult({
    required this.merchantUid,
    this.impUid,
    required this.status,
    required this.amount,
    required this.currency,
  });

  final String merchantUid;
  final String? impUid;
  final PaymentStatus status;
  final int amount;
  final String currency;
}

/// Parameters for PortOne payment screen
class PortOnePaymentParams {
  final String merchantUid;
  final String pgProvider;
  final String payMethod;
  final int amount;
  final String itemName;
  final String buyerName;
  final String buyerTel;
  final String buyerEmail;

  const PortOnePaymentParams({
    required this.merchantUid,
    required this.pgProvider,
    required this.payMethod,
    required this.amount,
    required this.itemName,
    required this.buyerName,
    required this.buyerTel,
    this.buyerEmail = '',
  });
}

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
  Future<Result<PaymentResult>> checkStatus(String paymentRef);

  /// Requests a refund. [paymentRef] matches the one from [checkStatus].
  Future<Result<void>> refund(String paymentRef, {int? amount});
}

/// PortOne (Korea) implementation
class PortOneGateway implements PaymentGateway {
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
    return Success(PaymentResult(
      merchantUid: _generateMerchantUid(reservationId),
      impUid: null,
      status: PaymentStatus.pending,
      amount: amount,
      currency: currency,
    ));
  }

  /// Verifies payment status via the `verify-payment` edge function.
  /// The server holds the imp_secret and calls the PortOne API on our behalf.
  @override
  Future<Result<PaymentResult>> checkStatus(String paymentRef) async {
    try {
      final res = await http
          .post(
            Uri.parse('${Env.supabaseUrl}/functions/v1/verify-payment'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Env.supabaseAnonKey}',
            },
            body: jsonEncode({'imp_uid': paymentRef}),
          )
          .timeout(_paymentTimeout);
      if (res.statusCode != 200) {
        return Fail(PaymentFailure(
          'Failed to verify payment (${res.statusCode})',
        ));
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return Success(PaymentResult(
        merchantUid: data['merchant_uid'] as String? ?? '',
        impUid: data['imp_uid'] as String?,
        status: PaymentStatus.fromString(data['status'] as String? ?? ''),
        amount: (data['amount'] as num?)?.toInt() ?? 0,
        currency: data['currency'] as String? ?? 'KRW',
      ));
    } on TimeoutException {
      return const Fail(PaymentFailure('Payment verification timed out'));
    } catch (e) {
      return Fail(PaymentFailure(e.toString()));
    }
  }

  /// Requests a refund via the `refund-payment` edge function.
  @override
  Future<Result<void>> refund(String paymentRef, {int? amount}) async {
    try {
      final body = <String, dynamic>{'imp_uid': paymentRef};
      if (amount != null) body['amount'] = amount;

      final res = await http
          .post(
            Uri.parse('${Env.supabaseUrl}/functions/v1/refund-payment'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Env.supabaseAnonKey}',
            },
            body: jsonEncode(body),
          )
          .timeout(_paymentTimeout);
      if (res.statusCode != 200) {
        return Fail(PaymentFailure('Refund failed (${res.statusCode})'));
      }
      return const Success(null);
    } on TimeoutException {
      return const Fail(PaymentFailure('Refund request timed out'));
    } catch (e) {
      return Fail(PaymentFailure(e.toString()));
    }
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
  Future<Result<PaymentResult>> checkStatus(String paymentRef) async {
    return const Fail(ServerFailure('Xendit not yet configured'));
  }

  @override
  Future<Result<void>> refund(String paymentRef, {int? amount}) async {
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
  Future<Result<PaymentResult>> checkStatus(String paymentRef) async {
    return const Fail(ServerFailure('Stripe not yet configured'));
  }

  @override
  Future<Result<void>> refund(String paymentRef, {int? amount}) async {
    return const Fail(ServerFailure('Stripe not yet configured'));
  }
}

/// Routes to the correct payment gateway based on currency
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

class PaymentService {
  PaymentGateway gatewayForCurrency(String currency) => switch (currency) {
        'KRW' => PortOneGateway(),
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
    int? amount,
  }) {
    final gateway = gatewayForCurrency(currency);
    return gateway.refund(paymentRef, amount: amount);
  }
}
