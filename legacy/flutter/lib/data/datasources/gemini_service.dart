import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/env.dart';
import '../../core/errors/result.dart';
import 'gemini_edge_client.dart';
import 'gemini_image_payload_builder.dart';
import 'supabase_client.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final client = ref.watch(supabaseProvider);
  final service = GeminiService(
    supabaseUrl: Env.supabaseUrl,
    supabaseAnonKey: Env.supabaseAnonKey,
    accessToken: client.auth.currentSession?.accessToken,
  );
  ref.onDispose(service.close);
  return service;
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
       _httpClient = httpClient;

  final String _functionUrl;
  final String _supabaseAnonKey;
  final String? _accessToken;
  final http.Client? _httpClient;
  final GeminiImagePayloadBuilder _payloadBuilder =
      const GeminiImagePayloadBuilder();
  GeminiEdgeClient? _edgeClient;

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
    final payloadResult = await _payloadBuilder.build(imageFile);
    if (payloadResult.isFailure) {
      return Fail(payloadResult.failure);
    }
    return _client.analyze(payload: payloadResult.value, prompt: prompt);
  }

  GeminiEdgeClient get _client {
    return _edgeClient ??= GeminiEdgeClient(
      functionUrl: _functionUrl,
      supabaseAnonKey: _supabaseAnonKey,
      accessToken: _accessToken,
      httpClient: _httpClient,
    );
  }

  void close() {
    _edgeClient?.close();
  }
}
