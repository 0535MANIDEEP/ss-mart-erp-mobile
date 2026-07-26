/// Exception thrown when a remote server request fails.
///
/// This is the low-level exception type used in data layer implementations
/// (data sources). It is caught and converted to [ServerFailure] by the
/// repository implementation layer before reaching the domain/presentation layers.
class ServerException implements Exception {
  /// Human-readable error description.
  final String message;

  /// HTTP status code from the server response (e.g., 400, 404, 500).
  final int? statusCode;

  ServerException({required this.message, this.statusCode});
}

/// Exception thrown when a local cache/database operation fails.
///
/// This is the low-level exception type used in local data source implementations.
/// It is caught and converted to [CacheFailure] by the repository layer.
class CacheException implements Exception {
  /// Human-readable error description.
  final String message;

  CacheException({required this.message});
}

/// Exception thrown when a network connectivity issue is detected.
///
/// This is the low-level exception type used to signal connectivity problems.
/// It is caught and converted to [NetworkFailure] by the repository layer.
class NetworkException implements Exception {
  /// Human-readable error description.
  final String message;

  NetworkException({required this.message});
}

/// Exception thrown when business rule validation fails.
///
/// This is the low-level exception type used in data source implementations
/// to signal validation errors. It is caught and converted to [ValidationFailure]
/// by the repository layer.
class ValidationException implements Exception {
  /// Human-readable error description.
  final String message;

  /// Field-level error details: { fieldName: errorMessage }.
  final Map<String, String>? errors;

  ValidationException({required this.message, this.errors});
}
