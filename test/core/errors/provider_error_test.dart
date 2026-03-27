import 'package:flutter_test/flutter_test.dart';
import 'package:dolpin/core/errors/failures.dart';
import 'package:dolpin/core/errors/result.dart';

void main() {
  group('Provider error pattern', () {
    test('Failure objects can be thrown and caught with type info preserved', () {
      const failure = NetworkFailure('No connection');
      final result = Fail<String>(failure);

      try {
        result.when(
          success: (data) => data,
          failure: (f) => throw f,
        );
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<NetworkFailure>());
        expect((e as Failure).message, 'No connection');
      }
    });

    test('Failure type is preserved through throw', () {
      final failures = <Failure>[
        const ServerFailure('server down'),
        const AuthFailure('invalid token'),
        const NetworkFailure(),
        const NotFoundFailure('item missing'),
        const ValidationFailure('bad input'),
      ];

      for (final failure in failures) {
        final result = Fail<int>(failure);
        try {
          result.when(
            success: (data) => data,
            failure: (f) => throw f,
          );
        } catch (e) {
          expect(e.runtimeType, failure.runtimeType);
          expect((e as Failure).message, failure.message);
        }
      }
    });

    test('Success does not throw', () {
      const result = Success<int>(42);
      final value = result.when(
        success: (data) => data,
        failure: (f) => throw f,
      );
      expect(value, 42);
    });
  });
}
