/// Base class for all application errors.
abstract class AppError implements Exception {
  final String message;
  final String? code;

  const AppError({required this.message, this.code});

  @override
  String toString() => message;
}

/// Network-related errors.
class NetworkError extends AppError {
  const NetworkError({
    required super.message,
    super.code,
  });
}

/// Offline mode - no network available.
class NoNetworkError extends NetworkError {
  const NoNetworkError()
      : super(
          message:
              'No network connection available. Some features are limited offline.',
          code: 'NO_NETWORK',
        );
}

/// Server unreachable or connection refused.
class ConnectionError extends NetworkError {
  const ConnectionError()
      : super(
          message:
              'Cannot connect to the server. Check your network connection.',
          code: 'CONNECTION_FAILED',
        );
}

/// HTTP error from the server.
class HttpError extends NetworkError {
  final int? statusCode;

  const HttpError({
    required super.message,
    super.code,
    this.statusCode,
  });
}

/// Local database errors.
class DatabaseError extends AppError {
  const DatabaseError({
    required super.message,
    super.code = 'DATABASE_ERROR',
  });
}

/// Validation errors.
class ValidationException extends AppError {
  final Map<String, String> fieldErrors;

  const ValidationException({
    required super.message,
    this.fieldErrors = const {},
  }) : super(code: 'VALIDATION_ERROR');
}

/// File-related errors.
class FileError extends AppError {
  final String? filePath;

  const FileError({
    required super.message,
    this.filePath,
    super.code = 'FILE_ERROR',
  });
}

/// Sync-related errors.
class SyncError extends AppError {
  final String? entityId;
  final SyncErrorType type;

  const SyncError({
    required super.message,
    this.entityId,
    required this.type,
  }) : super(code: 'SYNC_ERROR');
}

enum SyncErrorType { conflict, timeout, partial, unknown }
