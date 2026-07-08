import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import 'gemini_image_payload_builder.dart';

/// Timeout for the single round trip to the Gemini edge function. VLM
/// inference typically completes in 2-8s; anything beyond 30s indicates a
/// stuck network path and should surface to the user.
const Duration defaultGeminiTimeout = Duration(seconds: 30);

class GeminiEdgeClient {
  GeminiEdgeClient({
    required String functionUrl,
    required String supabaseAnonKey,
    String? accessToken,
    http.Client? httpClient,
    this.timeout = defaultGeminiTimeout,
  }) : _functionUrl = functionUrl,
       _supabaseAnonKey = supabaseAnonKey,
       _accessToken = accessToken,
       _httpClient = httpClient ?? http.Client();

  final String _functionUrl;
  final String _supabaseAnonKey;
  final String? _accessToken;
  final http.Client _httpClient;
  final Duration timeout;

  Future<Result<String>> analyze({
    required GeminiImagePayload payload,
    required String prompt,
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'apikey': _supabaseAnonKey,
      };
      if (_accessToken != null) {
        headers['Authorization'] = 'Bearer $_accessToken';
      }

      final response = await _httpClient
          .post(
            Uri.parse(_functionUrl),
            headers: headers,
            body: jsonEncode({
              'image': payload.image,
              'mimeType': payload.mimeType,
              'prompt': prompt,
            }),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        return Fail(
          ServerFailure('Gemini analysis failed (${response.statusCode})'),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultText = data['result'] as String?;
      if (resultText == null || resultText.isEmpty) {
        return const Fail(ServerFailure('No analysis result returned'));
      }

      return Success(resultText);
    } on TimeoutException {
      return const Fail(NetworkFailure('Gemini request timed out'));
    } catch (e) {
      return Fail(mapException(e));
    }
  }

  void close() {
    _httpClient.close();
  }
}
