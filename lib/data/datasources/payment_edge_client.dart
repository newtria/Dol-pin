import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/env.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';

/// Timeout for every outbound payment-gateway request. Payment flows are
/// user-blocking so indefinite hangs are the worst possible failure mode.
const Duration defaultPaymentTimeout = Duration(seconds: 20);

final paymentEdgeClientProvider = Provider<PaymentEdgeClient>((ref) {
  final client = PaymentEdgeClient();
  ref.onDispose(client.close);
  return client;
});

class PaymentEdgeClient {
  PaymentEdgeClient({
    http.Client? httpClient,
    this.timeout = defaultPaymentTimeout,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final Duration timeout;

  Future<Result<Map<String, dynamic>>> postJson({
    required String functionName,
    required String authJwt,
    required Map<String, dynamic> body,
    required String timeoutMessage,
    required String failureMessage,
  }) async {
    if (authJwt.isEmpty) {
      return const Fail(PaymentFailure('Authentication required'));
    }
    try {
      final response = await _httpClient
          .post(
            Uri.parse('${Env.supabaseUrl}/functions/v1/$functionName'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authJwt',
              'apikey': Env.supabaseAnonKey,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        return Fail(
          PaymentFailure(
            edgeErrorMessage(
              response,
              '$failureMessage (${response.statusCode})',
            ),
          ),
        );
      }
      return Success(jsonDecode(response.body) as Map<String, dynamic>);
    } on TimeoutException {
      return Fail(PaymentFailure(timeoutMessage));
    } catch (e) {
      return Fail(PaymentFailure(e.toString()));
    }
  }

  void close() {
    _httpClient.close();
  }
}

String edgeErrorMessage(http.Response response, String fallback) {
  try {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final error = data['error']?.toString();
    final impUid = data['imp_uid']?.toString();
    if (error == null || error.isEmpty) return fallback;
    if (impUid == null || impUid.isEmpty) return error;
    return '$error (imp_uid: $impUid)';
  } catch (_) {
    return fallback;
  }
}
