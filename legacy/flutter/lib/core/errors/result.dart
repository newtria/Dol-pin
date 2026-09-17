import 'failures.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Fail<T>;

  T get value => switch (this) {
    Success(:final data) => data,
    Fail(:final error) => throw StateError(
      'Called value on Fail: ${error.message}',
    ),
  };

  Failure get failure => switch (this) {
    Fail(:final error) => error,
    Success() => throw StateError('Called failure on Success'),
  };

  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failure,
  }) {
    return switch (this) {
      Success(:final data) => success(data),
      Fail(:final error) => failure(error),
    };
  }
}

class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

class Fail<T> extends Result<T> {
  const Fail(this.error);
  final Failure error;
}
