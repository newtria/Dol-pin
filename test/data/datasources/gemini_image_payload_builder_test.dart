import 'dart:convert';
import 'dart:io';

import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/data/datasources/gemini_image_payload_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeminiImagePayloadBuilder', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('gemini_payload_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('builds base64 image payload and MIME type', () async {
      final file = File('${tempDir.path}/photo.PNG');
      await file.writeAsBytes([1, 2, 3]);

      final result = await const GeminiImagePayloadBuilder().build(file);

      expect(result.isSuccess, isTrue);
      expect(result.value.image, base64Encode([1, 2, 3]));
      expect(result.value.mimeType, 'image/png');
    });

    test('rejects images larger than the configured byte cap', () async {
      final file = File('${tempDir.path}/large.jpg');
      await file.writeAsBytes([1, 2, 3, 4]);

      final result = await const GeminiImagePayloadBuilder(
        maxBytes: 3,
      ).build(file);

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ValidationFailure>());
      expect(result.failure.message, contains('Image too large for analysis'));
    });

    test('maps known MIME types and defaults to jpeg', () {
      expect(
        GeminiImagePayloadBuilder.mimeTypeForPath('cover.gif'),
        'image/gif',
      );
      expect(
        GeminiImagePayloadBuilder.mimeTypeForPath('cover.webp'),
        'image/webp',
      );
      expect(
        GeminiImagePayloadBuilder.mimeTypeForPath('cover.unknown'),
        'image/jpeg',
      );
    });
  });
}
