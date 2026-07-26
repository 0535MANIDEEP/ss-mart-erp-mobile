import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../repositories/employee_repository.dart';

/// Use case for soft-deleting an employee by marking them inactive.
class DeleteEmployeeUseCase extends UseCase<void, String> {
  final EmployeeRepository repository;

  /// Creates an instance of [DeleteEmployeeUseCase].
  DeleteEmployeeUseCase(this.repository);

  /// Executes the employee deletion.
  @override
  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteEmployee(id);
  }
}
