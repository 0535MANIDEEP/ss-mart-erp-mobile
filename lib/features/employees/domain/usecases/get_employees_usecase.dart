import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/employee_entity.dart';
import '../repositories/employee_repository.dart';

class GetEmployeesUseCase extends UseCase<List<Employee>, GetEmployeesParams> {
  final EmployeeRepository repository;

  GetEmployeesUseCase(this.repository);

  @override
  Future<Either<Failure, List<Employee>>> call(GetEmployeesParams params) async {
    return await repository.getEmployees(
      role: params.role,
      isActive: params.isActive,
      page: params.page,
      perPage: params.perPage,
    );
  }
}

class GetEmployeesParams {
  final String? role;
  final bool isActive;
  final int page;
  final int perPage;

  const GetEmployeesParams({
    this.role,
    this.isActive = true,
    this.page = 1,
    this.perPage = 20,
  });
}
