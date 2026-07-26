import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/employee_entity.dart';
import '../entities/attendance_entity.dart';

/// Abstract repository contract for employee and attendance data operations.
///
/// This interface defines the data access boundary for the employees feature.
/// Handles both employee profile management and real-time attendance tracking
/// (clock-in/clock-out) with PIN-based authentication.
///
/// All methods return [Either<Failure, T>] to enable functional error handling
/// without exceptions, following the Clean Architecture data flow convention.
abstract class EmployeeRepository {
  /// Retrieves a paginated list of employees with optional filtering.
  ///
  /// [role] filters by employee role ('admin', 'manager', 'cashier', 'inventory').
  /// [isActive] filters by active/inactive status (default: active only).
  Future<Either<Failure, List<Employee>>> getEmployees({
    String? role,
    bool isActive = true,
    int page = 1,
    int perPage = 20,
  });

  /// Retrieves a single employee by their unique identifier.
  Future<Either<Failure, Employee>> getEmployeeById(String id);

  /// Creates a new employee record. Enqueues a sync item for server upload.
  Future<Either<Failure, Employee>> createEmployee(Employee employee);

  /// Updates an existing employee record. Enqueues a sync item for server upload.
  Future<Either<Failure, Employee>> updateEmployee(Employee employee);

  /// Soft-deletes an employee by marking them inactive.
  /// Enqueues a sync item for server propagation.
  Future<Either<Failure, void>> deleteEmployee(String id);

  /// Validates an employee's PIN for authentication.
  /// Returns true if the PIN matches, false otherwise.
  Future<Either<Failure, bool>> validatePin(String employeeId, String pin);

  /// Records a clock-in event for the employee.
  /// Validates the PIN before creating the attendance record.
  Future<Either<Failure, Attendance>> clockIn(String employeeId, String pin);

  /// Records a clock-out event for the employee.
  /// Validates the PIN and updates the existing attendance record for today.
  Future<Either<Failure, Attendance>> clockOut(String employeeId, String pin);

  /// Retrieves attendance records with optional date range and employee filtering.
  /// [startDate] and [endDate] define the reporting period.
  Future<Either<Failure, List<Attendance>>> getAttendance({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  });
}
