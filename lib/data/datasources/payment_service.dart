import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/env.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';

enum PaymentStatus {
  success,
  pending,
  failed;

  static PaymentStatus fromString(String s) =>
      values.firstWhere((e) => e.name == s, orElse: () => failed);
}

/// Payment result data
class PaymentResult {
  final String transactionId;
  final PaymentStatus status;
  final int amount;
  final String currency;

  const PaymentResult({
    required this.transactionId,
    required this.status,
    required this.amount,
    required this.currency,
  });
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

/// Abstract payment gateway interface
abstract class PaymentGateway {
  Future<Result<PaymentResult>> initiatePayment({
    required String reservationId,
    required int amount,
    required String currency,
    required String description,
  });

  Future<Result<PaymentResult>> checkStatus(String transactionId);

  Future<Result<void>> refund(String transactionId, {int? amount});
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
  // Use a Supabase Edge Function or your own backend to call the PortOne API
  // with the imp_secret stored in server-side environment variables.
  // ---------------------------------------------------------------------------

  @override
  Future<Result<PaymentResult>> initiatePayment({
    required String reservationId,
    required int amount,
    required String currency,
    required String description,
  }) async {
    // Payment is initiated via PaymentScreen widget (IamportPayment).
    // This method returns a pending result with the merchant UID.
    return Success(PaymentResult(
      transactionId: _generateMerchantUid(reservationId),
      status: PaymentStatus.pending,
      amount: amount,
      currency: currency,
    ));
  }

  /// Verifies payment status via a server-side endpoint.
  /// The server (Supabase Edge Function) holds the imp_secret and calls
  /// the PortOne API on our behalf. Never call PortOne directly from the client.
  @override
  Future<Result<PaymentResult>> checkStatus(String impUid) async {
    try {
      final res = await http.post(
        Uri.parse('${Env.supabaseUrl}/functions/v1/verify-payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Env.supabaseAnonKey}',
        },
        body: jsonEncode({'imp_uid': impUid}),
      );
      if (res.statusCode != 200) {
        return const Fail(PaymentFailure('Failed to verify payment'));
      }
      final data = jsonDecode(res.body);
      return Success(PaymentResult(
        transactionId: data['imp_uid'] as String,
        status: PaymentStatus.fromString(data['status'] as String),
        amount: data['amount'] as int,
        currency: 'KRW',
      ));
    } catch (e) {
      return Fail(PaymentFailure(e.toString()));
    }
  }

  /// Requests a refund via a server-side endpoint.
  /// The server (Supabase Edge Function) holds the imp_secret and calls
  /// the PortOne cancel API on our behalf.
  @override
  Future<Result<void>> refund(String impUid, {int? amount}) async {
    try {
      final body = <String, dynamic>{'imp_uid': impUid};
      if (amount != null) body['amount'] = amount;

      final res = await http.post(
        Uri.parse('${Env.supabaseUrl}/functions/v1/refund-payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Env.supabaseAnonKey}',
        },
        body: jsonEncode(body),
      );
      if (res.statusCode != 200) {
        return const Fail(PaymentFailure('Refund failed'));
      }
      return const Success(null);
    } catch (e) {
      return Fail(PaymentFailure(e.toString()));
    }
  }
}

/// Xendit (Indonesia) implementation
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
  Future<Result<PaymentResult>> checkStatus(String transactionId) async {
    return const Fail(ServerFailure('Xendit not yet configured'));
  }

  @override
  Future<Result<void>> refund(String transactionId, {int? amount}) async {
    return const Fail(ServerFailure('Xendit not yet configured'));
  }
}

/// Stripe (Japan/Global) implementation
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
  Future<Result<PaymentResult>> checkStatus(String transactionId) async {
    return const Fail(ServerFailure('Stripe not yet configured'));
  }

  @override
  Future<Result<void>> refund(String transactionId, {int? amount}) async {
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
    required String transactionId,
    required String currency,
    int? amount,
  }) {
    final gateway = gatewayForCurrency(currency);
    return gateway.refund(transactionId, amount: amount);
  }
}
