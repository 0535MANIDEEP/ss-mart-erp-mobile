import 'package:dartz/dartz.dart';
import '../error/failures.dart';

/// Abstract base class for all use cases in the application.
///
/// Use cases encapsulate a single business operation, following the Clean
/// Architecture convention. Each use case defines:
/// - [Type]: The return type on success
/// - [Params]: The input parameters type (use [NoParams] for parameterless operations)
///
/// Use cases are invoked via the [call] method, enabling clean syntax:
/// ```dart
/// final result = await getProductsUseCase(GetProductsParams(search: 'milk'));
/// ```
///
/// All use cases return [Either<Failure, T>] to enable functional error handling
/// without exceptions. The presentation layer (Bloc) handles the Left/Right branching.
abstract class UseCase<Type, Params> {
  /// Executes the use case with the given parameters.
  /// Returns [Right(Type)] on success or [Left(Failure)] on error.
  Future<Either<Failure, Type>> call(Params params);
}

/// Sentinel class for use cases that require no input parameters.
/// Pass an instance of this class to [UseCase.call] when no arguments are needed.
class NoParams {
  const NoParams();
}
