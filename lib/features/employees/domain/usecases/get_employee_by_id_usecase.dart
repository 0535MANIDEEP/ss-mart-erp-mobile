import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/employee_entity.dart';
import '../repositories/employee_repository.dart';

/// Use case for retrieving a single employee by their unique identifier.
class GetEmployeeByIdUseCase extends UseCase<Employee, String> {
  final EmployeeRepository repository;

  /// Creates an instance of [GetEmployeeByIdUseCase].
  GetEmployeeByIdUseCase(this.repository);

  /// Executes the employee retrieval.
  @override
  Future<Either<Failure, Employee>> call(String id) async {
    return await repository.getEmployeeById(id);
  }
}
