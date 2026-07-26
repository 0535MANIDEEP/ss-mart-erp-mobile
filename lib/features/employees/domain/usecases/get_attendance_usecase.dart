import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/attendance_entity.dart';
import '../repositories/employee_repository.dart';

/// Use case for retrieving attendance records with optional employee filtering.
class GetAttendanceUseCase extends UseCase<List<Attendance>, GetAttendanceParams> {
  final EmployeeRepository repository;

  /// Creates an instance of [GetAttendanceUseCase].
  GetAttendanceUseCase(this.repository);

  /// Executes the attendance retrieval.
  @override
  Future<Either<Failure, List<Attendance>>> call(GetAttendanceParams params) async {
    return await repository.getAttendance(employeeId: params.employeeId);
  }
}

/// Parameters for retrieving attendance records.
class GetAttendanceParams {
  /// Optional employee ID to filter attendance records for a specific employee.
  final String? employeeId;

  /// Creates [GetAttendanceParams] with optional employee filtering.
  const GetAttendanceParams({this.employeeId});
}
