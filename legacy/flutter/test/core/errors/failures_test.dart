import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dolpin/core/errors/failures.dart';

void main() {
  group('mapException', () {
    test('maps SocketException to NetworkFailure', () {
      final failure = mapException(const SocketException('no internet'));
      expect(failure, isA<NetworkFailure>());
    });

    test('maps AuthException to AuthFailure', () {
      final failure = mapException(AuthException('bad token'));
      expect(failure, isA<AuthFailure>());
      expect(failure.message, 'bad token');
    });

    test('maps PostgrestException to ServerFailure', () {
      final failure = mapException(
        PostgrestException(message: 'db error', code: '500'),
      );
      expect(failure, isA<ServerFailure>());
    });

    test('maps PostgrestException PGRST116 to NotFoundFailure', () {
      final failure = mapException(
        PostgrestException(message: 'not found', code: 'PGRST116'),
      );
      expect(failure, isA<NotFoundFailure>());
    });

    test('maps unknown exception to ServerFailure', () {
      final failure = mapException(Exception('random'));
      expect(failure, isA<ServerFailure>());
    });
  });
}
