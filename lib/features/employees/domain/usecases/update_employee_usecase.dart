import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/employee_entity.dart';
import '../repositories/employee_repository.dart';

/// Use case for updating an existing employee.
class UpdateEmployeeUseCase extends UseCase<Employee, Employee> {
  final EmployeeRepository repository;

  /// Creates an instance of [UpdateEmployeeUseCase].
  UpdateEmployeeUseCase(this.repository);

  /// Executes the employee update.
  @override
  Future<Either<Failure, Employee>> call(Employee employee) async {
    return await repository.updateEmployee(employee);
  }
}
