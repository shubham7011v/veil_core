import 'package:equatable/equatable.dart';

/// Abstract class defining the contract for all failures in the application.
abstract class Failure extends Equatable {
  final String message;
  final dynamic originalError;

  const Failure(this.message, [this.originalError]);

  @override
  List<Object?> get props => [message, originalError];
}

/// General server failure (e.g. 500 errors, invalid JSON).
class ServerFailure extends Failure {
  const ServerFailure(super.message, [super.originalError]);
}

/// Network connectivity failure (e.g. no internet, timeout).
class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection',
    super.originalError,
  ]);
}

/// Authentication failure (e.g. wrong password, user banned).
class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.originalError]);
}

/// Cache/Local Storage failure.
class CacheFailure extends Failure {
  const CacheFailure(super.message, [super.originalError]);
}

/// Unknown/Unexpected failure.
class UnknownFailure extends Failure {
  const UnknownFailure([
    super.message = 'An unexpected error occurred',
    super.originalError,
  ]);
}

/// Session/Game specific failure.
class SessionFailure extends Failure {
  const SessionFailure(super.message, [super.originalError]);
}
