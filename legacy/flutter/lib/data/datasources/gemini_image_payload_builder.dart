import 'dart:convert';
import 'dart:io';

import '../../core/errors/failures.dart';
import '../../core/errors/result.dart';

/// Hard cap on image payload sent to the Gemini edge function.
/// Gemini edge function body limit is ~6MB; raw JPEG from modern phones can
/// exceed that once base64-encoded (1.33x expansion), so we gate at 4MB raw.
const int defaultMaxGeminiImageBytes = 4 * 1024 * 1024;

class GeminiImagePayload {
  const GeminiImagePayload({required this.image, required this.mimeType});

  final String image;
  final String mimeType;
}

class GeminiImagePayloadBuilder {
  const GeminiImagePayloadBuilder({this.maxBytes = defaultMaxGeminiImageBytes});

  final int maxBytes;

  Future<Result<GeminiImagePayload>> build(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    if (bytes.length > maxBytes) {
      return Fail(
        ValidationFailure(
          'Image too large for analysis '
          '(${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB, '
          'max ${maxBytes ~/ 1024 ~/ 1024}MB)',
        ),
      );
    }

    return Success(
      GeminiImagePayload(
        image: base64Encode(bytes),
        mimeType: mimeTypeForPath(imageFile.path),
      ),
    );
  }

  static String mimeTypeForPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
