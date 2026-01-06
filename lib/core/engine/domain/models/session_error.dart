enum SessionError {
  connectionLost,
  invalidMove,
  serverError,
  timeout,
  unauthorized,
  roomFull,
  roomNotFound,
}

extension SessionErrorExtension on SessionError {
  String get message {
    switch (this) {
      case SessionError.connectionLost:
        return 'Connection lost. Reconnecting...';
      case SessionError.invalidMove:
        return 'Invalid move. Please try again.';
      case SessionError.serverError:
        return 'Server error occurred.';
      case SessionError.timeout:
        return 'Request timed out.';
      case SessionError.unauthorized:
        return 'Unauthorized action.';
      case SessionError.roomFull:
        return 'Room is full.';
      case SessionError.roomNotFound:
        return 'Room not found.';
    }
  }

  bool get isRecoverable {
    switch (this) {
      case SessionError.connectionLost:
      case SessionError.timeout:
        return true;
      default:
        return false;
    }
  }
}
