import 'package:dartz/dartz.dart';

import 'exceptions.dart';
import 'failures.dart';
import '../utils/logger.dart';

/// Centralized error handler that converts exceptions to failures.
///
/// Follows the Clean Architecture convention: data sources throw exceptions,
/// repositories catch them and convert to [Failure] via this handler, and
/// the presentation layer receives [Either<Failure, T>].
///
/// ## Usage
///
/// ```dart
/// Future<Either<Failure, Product>> getProduct(String id) async {
///   return ErrorHandler.handle(() async {
///     final remote = await remoteDataSource.getProduct(id);
///     return remote;
///   });
/// }
/// ```
class ErrorHandler {
  ErrorHandler._();

  static final Logger _log = Logger(tag: 'ErrorHandler');

  /// Executes [operation] and catches known exceptions, converting them
  /// to typed [Failure] objects wrapped in [Left].
  ///
  /// Returns [Right] with the operation's result on success.
  static Future<Either<Failure, T>> handle<T>(
    Future<T> Function() operation,
  ) async {
    try {
      final result = await operation();
      return Right(result);
    } on ServerException catch (e) {
      _log.error('Server error: ${e.message}', error: e);
      return Left(ServerFailure(message: e.message));
    } on CacheException catch (e) {
      _log.error('Cache error: ${e.message}', error: e);
      return Left(CacheFailure(message: e.message));
    } on NetworkException catch (e) {
      _log.error('Network error: ${e.message}', error: e);
      return Left(NetworkFailure(message: e.message));
    } on ValidationException catch (e) {
      _log.warn('Validation error: ${e.message}', error: e);
      return Left(ValidationFailure(message: e.message, errors: e.errors));
    } on FormatException catch (e) {
      _log.error('Format error: ${e.message}', error: e);
      return const Left(ServerFailure(message: 'Invalid data format received'));
    } catch (e, st) {
      _log.error('Unhandled error: $e', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  /// Synchronous variant of [handle] for operations that don't await.
  static Either<Failure, T> handleSync<T>(T Function() operation) {
    try {
      return Right(operation());
    } on ServerException catch (e) {
      _log.error('Server error: ${e.message}', error: e);
      return Left(ServerFailure(message: e.message));
    } on CacheException catch (e) {
      _log.error('Cache error: ${e.message}', error: e);
      return Left(CacheFailure(message: e.message));
    } on ValidationException catch (e) {
      _log.warn('Validation error: ${e.message}', error: e);
      return Left(ValidationFailure(message: e.message, errors: e.errors));
    } catch (e, st) {
      _log.error('Unhandled sync error: $e', error: e, stackTrace: st);
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }
}
