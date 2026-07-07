import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/env.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';
import 'supabase_client.dart';

/// Hard cap on image payload sent to the Gemini edge function.
/// Gemini edge function body limit is ~6MB; raw JPEG from modern phones can
/// exceed that once base64-encoded (1.33x expansion), so we gate at 4MB raw.
const int _maxGeminiImageBytes = 4 * 1024 * 1024;

/// Timeout for the single round trip to the Gemini edge function. VLM
/// inference typically completes in 2–8s; anything beyond 30s indicates a
/// stuck network path and should surface to the user.
const Duration _geminiTimeout = Duration(seconds: 30);

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final client = ref.watch(supabaseProvider);
  return GeminiService(
    supabaseUrl: Env.supabaseUrl,
    supabaseAnonKey: Env.supabaseAnonKey,
    accessToken: client.auth.currentSession?.accessToken,
  );
});

class GeminiService {
  GeminiService({
    required String supabaseUrl,
    required String supabaseAnonKey,
    String? accessToken,
    http.Client? httpClient,
  }) : _functionUrl = '$supabaseUrl/functions/v1/gemini-analyze',
       _supabaseAnonKey = supabaseAnonKey,
       _accessToken = accessToken,
       _httpClient = httpClient ?? http.Client();

  final String _functionUrl;
  final String _supabaseAnonKey;
  final String? _accessToken;
  final http.Client _httpClient;

  /// Analyzes a rental item photo and returns auto-generated tags.
  /// Returns a VLM tag string like "BTS Official Lightstick Ver.4, Black, Good Condition"
  Future<Result<String>> analyzeItemPhoto(File imageFile) async {
    return _callEdgeFunction(
      imageFile: imageFile,
      prompt:
          'You are analyzing a K-pop concert rental item photo. '
          'Identify the item and generate a concise tag string. '
          'Include: item type (lightstick/phone/camera/slogan/costume), '
          'brand/artist if identifiable, model/version if known, '
          'color, and visible condition. '
          'Return ONLY the tag string, no explanation. '
          'Example: "BTS Official Lightstick Ver.4, Purple, Like New" '
          'Example: "iPhone 15 Pro, Natural Titanium, Minor Scratches"',
    );
  }

  /// Suggests a category based on the item photo.
  Future<Result<String>> suggestCategory(File imageFile) async {
    final result = await _callEdgeFunction(
      imageFile: imageFile,
      prompt:
          'Look at this K-pop concert rental item photo. '
          'Classify it into exactly ONE of these categories: '
          'lightstick, phone, camera, slogan, costume, etc. '
          'Return ONLY the category name, nothing else.',
    );

    return result.when(
      success: (text) {
        final category = text.toLowerCase();
        const valid = {
          'lightstick',
          'phone',
          'camera',
          'slogan',
          'costume',
          'etc',
        };
        return Success(valid.contains(category) ? category : 'etc');
      },
      failure: (f) => Fail(f),
    );
  }

  Future<Result<String>> _callEdgeFunction({
    required File imageFile,
    required String prompt,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      if (bytes.length > _maxGeminiImageBytes) {
        return Fail(
          ValidationFailure(
            'Image too large for analysis '
            '(${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB, '
            'max ${_maxGeminiImageBytes ~/ 1024 ~/ 1024}MB)',
          ),
        );
      }
      final base64Image = base64Encode(bytes);
      final mimeType = _getMimeType(imageFile.path);

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
              'image': base64Image,
              'mimeType': mimeType,
              'prompt': prompt,
            }),
          )
          .timeout(_geminiTimeout);

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

  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
