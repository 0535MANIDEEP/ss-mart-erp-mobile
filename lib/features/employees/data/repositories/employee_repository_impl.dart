import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_remote_datasource.dart';
import '../datasources/employee_local_datasource.dart';

/// Implementation of [EmployeeRepository] for employee management and
/// attendance tracking in the SS MART ERP Mobile App.
///
/// ## Architecture & Sync Strategy
///
/// Unlike other repositories in this codebase, [EmployeeRepositoryImpl]
/// follows a **remote-first read / local-cache write** pattern:
///
/// ### Read Pattern
/// - **getEmployees (list)**: Remote-first when online (returns remote data
///   directly), falls back to local cache when offline. Remote data is NOT
///   re-cached locally on each read (unlike Product/Customer repos).
/// - **getEmployeeById**: Remote-only — always calls the remote API.
///   This reflects the sensitivity of employee data (attendance, PINs)
///   which should always be authoritative from the server.
///
/// ### Write Pattern (Remote-First)
/// - Create, update, and delete operations are performed on the remote
///   API first, then the result is cached locally. This is because
///   employee data (especially attendance) requires server-side validation
///   and state management (e.g., preventing duplicate clock-ins).
///
/// ### Attendance (Clock In/Out)
/// - Clock in/out operations are remote-first: the server validates the
///   employee PIN and returns the authoritative attendance record.
/// - The attendance record is then saved locally for offline reference.
/// - PIN validation is always remote (security-sensitive, never cached).
///
/// ### Error Handling
/// - Uses both [ServerException] (from remote datasource) and general
///   [Exception] catch. [ServerException] is converted to [ServerFailure].
/// - All methods return `Either<Failure, T>`.
///
/// ### Relationship Between Local and Remote
/// - Remote is the authoritative source for employee and attendance data.
/// - Local serves as a read cache for offline browsing of employee lists.
/// - PIN validation and attendance operations always require connectivity.
class EmployeeRepositoryImpl implements EmployeeRepository {
  final EmployeeRemoteDataSource remoteDataSource;
  final EmployeeLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  EmployeeRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Fetches a list of employees filtered by role and active status.
  ///
  /// **Strategy**: Remote-first when online, local fallback when offline.
  /// Employee data is fetched from the server to ensure the latest roles
  /// and status are displayed. The local cache provides offline read access.
  @override
  Future<Either<Failure, List<Employee>>> getEmployees({
    String? role,
    bool isActive = true,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      if (await networkInfo.isConnected) {
        final remoteEmployees = await remoteDataSource.getEmployees(
          role: role,
          isActive: isActive,
          page: page,
          perPage: perPage,
        );
        return Right(remoteEmployees);
      } else {
        final localEmployees = await localDataSource.getEmployees(
          role: role,
          isActive: isActive,
        );
        return Right(localEmployees);
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Retrieves a single employee by ID from the remote API.
  ///
  /// Always fetches from the remote to ensure the latest employee data
  /// (role, permissions, active status) is returned.
  @override
  Future<Either<Failure, Employee>> getEmployeeById(String id) async {
    try {
      final employee = await remoteDataSource.getEmployeeById(id);
      return Right(employee);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Creates a new employee on the remote server, then caches the result locally.
  ///
  /// Remote-first write ensures server-side validation (duplicate checks,
  /// role assignment, PIN hashing) before the employee appears locally.
  @override
  Future<Either<Failure, Employee>> createEmployee(Employee employee) async {
    try {
      final result = await remoteDataSource.createEmployee(employee);
      await localDataSource.saveEmployee(result);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Updates an employee on the remote server, then updates the local cache.
  @override
  Future<Either<Failure, Employee>> updateEmployee(Employee employee) async {
    try {
      final result = await remoteDataSource.updateEmployee(employee);
      await localDataSource.saveEmployee(result);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Deletes an employee from both remote and local datastores.
  ///
  /// Dual deletion ensures consistency. Remote deletion is primary; local
  /// deletion removes the cached copy.
  @override
  Future<Either<Failure, void>> deleteEmployee(String id) async {
    try {
      await remoteDataSource.deleteEmployee(id);
      await localDataSource.deleteEmployee(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Validates an employee's PIN against the remote server.
  ///
  /// Always remote — PIN validation is security-sensitive and must never
  /// be performed against stale local data. Requires network connectivity.
  @override
  Future<Either<Failure, bool>> validatePin(String employeeId, String pin) async {
    try {
      final isValid = await remoteDataSource.validatePin(employeeId, pin);
      return Right(isValid);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Records a clock-in event for an employee.
  ///
  /// Remote-first: the server validates the PIN, prevents duplicate clock-ins,
  /// and returns the authoritative [Attendance] record. The record is then
  /// saved locally for offline reference in attendance reports.
  @override
  Future<Either<Failure, Attendance>> clockIn(String employeeId, String pin) async {
    try {
      final attendance = await remoteDataSource.clockIn(employeeId, pin);
      await localDataSource.saveAttendance(attendance);
      return Right(attendance);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Records a clock-out event for an employee.
  ///
  /// Remote-first pattern identical to [clockIn]. The server calculates
  /// total hours worked and returns the updated attendance record.
  @override
  Future<Either<Failure, Attendance>> clockOut(String employeeId, String pin) async {
    try {
      final attendance = await remoteDataSource.clockOut(employeeId, pin);
      await localDataSource.saveAttendance(attendance);
      return Right(attendance);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Fetches attendance records for an employee within a date range.
  ///
  /// Always fetched from the remote API to ensure the latest attendance
  /// data (including real-time clock-in/out status) is displayed.
  @override
  Future<Either<Failure, List<Attendance>>> getAttendance({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final attendance = await remoteDataSource.getAttendance(
        employeeId: employeeId,
        startDate: startDate,
        endDate: endDate,
      );
      return Right(attendance);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
