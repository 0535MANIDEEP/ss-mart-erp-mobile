import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/attendance_entity.dart';
import '../repositories/employee_repository.dart';

class ClockInUseCase extends UseCase<Attendance, ClockInParams> {
  final EmployeeRepository repository;

  ClockInUseCase(this.repository);

  @override
  Future<Either<Failure, Attendance>> call(ClockInParams params) async {
    return await repository.clockIn(params.employeeId, params.pin);
  }
}

class ClockInParams {
  final String employeeId;
  final String pin;

  const ClockInParams({required this.employeeId, required this.pin});
}
