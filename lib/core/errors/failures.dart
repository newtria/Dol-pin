import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

sealed class Failure {
  const Failure(this.message);
  final String message;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error occurred']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Resource not found']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Validation failed']);
}

class PaymentFailure extends Failure {
  const PaymentFailure([super.message = 'Payment failed']);
}

/// Maps raw exceptions from Supabase/network into typed [Failure].
Failure mapException(Object e) {
  if (e is SocketException) return const NetworkFailure();
  if (e is AuthException) return AuthFailure(e.message);
  if (e is PostgrestException) {
    if (e.code == 'PGRST116') return NotFoundFailure(e.message);
    return ServerFailure(e.message);
  }
  if (e is StorageException) return ServerFailure(e.message);
  return ServerFailure(e.toString());
}
