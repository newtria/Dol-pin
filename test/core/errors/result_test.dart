import 'package:flutter_test/flutter_test.dart';
import 'package:dolpin/core/errors/result.dart';
import 'package:dolpin/core/errors/failures.dart';

void main() {
  group('Result', () {
    test('Success should have correct properties', () {
      const result = Success(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.value, 42);
    });

    test('Fail should have correct properties', () {
      const result = Fail<int>(ServerFailure('test error'));
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.failure.message, 'test error');
    });

    test('when should call success callback on Success', () {
      const result = Success<int>(42);
      final output = result.when(
        success: (data) => 'success: $data',
        failure: (f) => 'failure: ${f.message}',
      );
      expect(output, 'success: 42');
    });

    test('when should call failure callback on Fail', () {
      const Result<int> result = Fail(ServerFailure('oops'));
      final output = result.when(
        success: (data) => 'success: $data',
        failure: (f) => 'failure: ${f.message}',
      );
      expect(output, 'failure: oops');
    });

    test('Success<void> should work', () {
      const result = Success<void>(null);
      expect(result.isSuccess, isTrue);
    });

    test('value on Fail should throw StateError', () {
      const Result<int> result = Fail(ServerFailure('oops'));
      expect(() => result.value, throwsStateError);
    });

    test('failure on Success should throw StateError', () {
      const result = Success(42);
      expect(() => result.failure, throwsStateError);
    });
  });
}
