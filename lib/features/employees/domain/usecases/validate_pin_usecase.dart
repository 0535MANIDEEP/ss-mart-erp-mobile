import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../repositories/employee_repository.dart';

/// Use case for validating an employee's PIN for authentication.
class ValidatePinUseCase extends UseCase<bool, ValidatePinParams> {
  final EmployeeRepository repository;

  /// Creates an instance of [ValidatePinUseCase].
  ValidatePinUseCase(this.repository);

  /// Executes PIN validation.
  ///
  /// Returns true if the PIN matches, false otherwise.
  @override
  Future<Either<Failure, bool>> call(ValidatePinParams params) async {
    return await repository.validatePin(params.employeeId, params.pin);
  }
}

/// Parameters for PIN validation.
class ValidatePinParams {
  /// The employee identifier.
  final String employeeId;

  /// The PIN to validate.
  final String pin;

  /// Creates [ValidatePinParams] with the given employee ID and PIN.
  const ValidatePinParams({required this.employeeId, required this.pin});
}
