import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/employee_entity.dart';
import '../repositories/employee_repository.dart';

/// Use case for creating a new employee in the system.
///
/// Validates that the employee name is not empty before delegating to the repository.
class CreateEmployeeUseCase extends UseCase<Employee, Employee> {
  final EmployeeRepository repository;

  /// Creates an instance of [CreateEmployeeUseCase].
  CreateEmployeeUseCase(this.repository);

  /// Executes the employee creation with validation.
  ///
  /// Returns [ValidationFailure] if employee name is empty.
  @override
  Future<Either<Failure, Employee>> call(Employee employee) async {
    if (employee.name.isEmpty) {
      return const Left(ValidationFailure(message: 'Employee name cannot be empty'));
    }
    return await repository.createEmployee(employee);
  }
}
