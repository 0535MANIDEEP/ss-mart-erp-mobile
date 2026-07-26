import 'package:equatable/equatable.dart';

/// Base class for all domain-level failures in the Clean Architecture pattern.
///
/// Failures represent recoverable error conditions that are propagated up
/// from the data layer to the domain/presentation layers via [Either<Failure, T>].
/// Unlike exceptions, failures are value objects that carry a human-readable
/// [message] and can be pattern-matched in the presentation layer.
///
/// The hierarchy distinguishes between different failure sources:
/// - [ServerFailure]: API/network response errors (4xx/5xx status codes)
/// - [CacheFailure]: Local database read/write errors
/// - [NetworkFailure]: Connectivity issues (no internet, timeout)
/// - [ValidationFailure]: Business rule validation errors with field-level details
abstract class Failure extends Equatable {
  /// Human-readable error message suitable for user-facing display.
  final String message;

  const Failure({required this.message});

  @override
  List<Object> get props => [message];
}

/// Failure caused by an API or remote server error.
///
/// Typically wraps HTTP 4xx/5xx responses. The [message] should describe
/// the server's error response or a user-friendly fallback.
class ServerFailure extends Failure {
  const ServerFailure({required super.message});
}

/// Failure caused by a local cache or database operation error.
///
/// Wraps SQLite read/write exceptions. Usually indicates data corruption
/// or an unexpected schema state.
class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

/// Failure caused by a network connectivity issue.
///
/// Indicates the device cannot reach the server (no internet, DNS failure,
/// connection timeout). The app should operate in offline mode when this
/// failure is encountered.
class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

/// Failure caused by business rule validation errors.
///
/// Contains a map of field-level validation errors ([errors]) where keys
/// are field names and values are error messages. Useful for displaying
/// inline form validation feedback in the UI.
class ValidationFailure extends Failure {
  /// Field-level error map: { fieldName: errorMessage }.
  final Map<String, String>? errors;

  const ValidationFailure({required super.message, this.errors});
}
