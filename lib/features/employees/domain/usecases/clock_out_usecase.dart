import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/attendance_entity.dart';
import '../repositories/employee_repository.dart';

class ClockOutUseCase extends UseCase<Attendance, ClockOutParams> {
  final EmployeeRepository repository;

  ClockOutUseCase(this.repository);

  @override
  Future<Either<Failure, Attendance>> call(ClockOutParams params) async {
    return await repository.clockOut(params.employeeId, params.pin);
  }
}

class ClockOutParams {
  final String employeeId;
  final String pin;

  const ClockOutParams({required this.employeeId, required this.pin});
}
