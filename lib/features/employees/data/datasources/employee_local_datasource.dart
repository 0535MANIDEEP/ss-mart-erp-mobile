/// Employee Local Data Source — Local persistence layer for employee and attendance data.
///
/// ## Architecture Role
/// Sits between [EmployeeRepositoryImpl] and the Drift database. Abstracts all
/// details of how employee and attendance rows are stored, queried, and converted
/// to/from domain entities. The repository never touches raw SQL or DAO objects.
///
/// ## Responsibilities
/// - CRUD operations on the [Employees] table.
/// - CRUD operations on the [AttendanceData] table.
/// - Filtering employees by role and active/inactive status.
/// - Querying attendance records by employee ID or by date.
/// - Bidirectional mapping for both [Employee] and [Attendance] domain entities.
///
/// ## Data Flow
/// ```
/// Repository → EmployeeLocalDataSource → DatabaseDao (Drift) → SQLite
/// ```
///
/// ## Design Decisions
/// - This datasource manages two related entities (Employee + Attendance) in a
///   single class because attendance is tightly coupled to employees — it always
///   queries/creates attendance in the context of an employee. Splitting them
///   would create unnecessary cross-datasource dependencies in the repository.
/// - Attendance queries default to today's date (`DateTime.now()`). This is a
///   deliberate simplification for the mobile POS use case where attendance is
///   only relevant for the current business day. Historical attendance reports
///   should go through a dedicated reporting datasource.
/// - The DAO is created once in the constructor and cached, following the same
///   pattern as [CustomerLocalDataSourceImpl] and [StockLocalDataSourceImpl].
library;

import '../../../../database/app_database.dart' as db;
import '../../domain/entities/employee_entity.dart';
import '../../domain/entities/attendance_entity.dart';

/// Abstract contract for local employee and attendance persistence.
///
/// The repository layer depends on this interface, not on the concrete
/// implementation, enabling unit testing with fakes/mocks.
abstract class EmployeeLocalDataSource {
  /// Returns a list of employees, optionally filtered by [role] and/or
  /// [isActive] status. Defaults to active employees only.
  Future<List<Employee>> getEmployees({String? role, bool isActive = true});

  /// Returns a single employee by its unique [id], or `null` if not found.
  Future<Employee?> getEmployeeById(String id);

  /// Upserts an employee record — inserts if new, updates if the ID exists.
  Future<void> saveEmployee(Employee employee);

  /// Soft/hard-deletes an employee by its [id].
  Future<void> deleteEmployee(String id);

  /// Persists an attendance record (clock-in, clock-out, or status update).
  Future<void> saveAttendance(Attendance attendance);

  /// Returns attendance records, optionally filtered by [employeeId].
  /// When no employeeId is provided, returns all attendance for today.
  Future<List<Attendance>> getAttendance({String? employeeId});
}

/// Concrete implementation backed by Drift's [AppDatabase].
///
/// Handles the mapping between domain entities ([Employee], [Attendance]) and
/// their respective Drift row/companion objects. Each entity has its own pair
/// of mapping methods (`_toEntity`/`_toCompanion`) to keep concerns isolated.
class EmployeeLocalDataSourceImpl implements EmployeeLocalDataSource {
  final db.DatabaseDao _dao;

  EmployeeLocalDataSourceImpl({required db.AppDatabase database})
      : _dao = db.DatabaseDao(database);

  @override
  Future<List<Employee>> getEmployees({
    String? role,
    bool isActive = true,
  }) async {
    List<db.Employee> rows;

    // Choose the appropriate DAO method based on the active-status filter.
    if (isActive) {
      rows = await _dao.getActiveEmployees();
    } else {
      rows = await _dao.getAllEmployees();
    }

    var employees = rows.map(_toEntity).toList();

    // Apply role filter in memory. This is a pragmatic choice: the role values
    // are few and the employee list is bounded, so SQL-level filtering adds
    // complexity without meaningful performance gain.
    if (role != null) {
      employees = employees.where((e) => e.role == role).toList();
    }

    return employees;
  }

  @override
  Future<Employee?> getEmployeeById(String id) async {
    final row = await _dao.getEmployeeById(id);
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<void> saveEmployee(Employee employee) async {
    await _dao.insertEmployee(_toCompanion(employee));
  }

  @override
  Future<void> deleteEmployee(String id) async {
    await _dao.deleteEmployee(id);
  }

  @override
  Future<void> saveAttendance(Attendance attendance) async {
    await _dao.insertAttendance(_attendanceToCompanion(attendance));
  }

  @override
  Future<List<Attendance>> getAttendance({String? employeeId}) async {
    List<db.AttendanceData> rows;

    // When an employeeId is provided, fetch their attendance for today.
    // When no employeeId is provided, fetch all employees' attendance for today.
    // Both cases default to today's date — see design decision in class doc.
    if (employeeId != null) {
      rows = await _dao.getAttendanceByEmployee(
        employeeId,
        DateTime.now(),
      );
    } else {
      rows = await _dao.getAttendanceByDate(DateTime.now());
    }

    return rows.map(_attendanceToEntity).toList();
  }

  /// Converts a Drift [db.Employee] row into a domain [Employee] entity.
  Employee _toEntity(db.Employee row) {
    return Employee(
      id: row.id,
      name: row.name,
      phone: row.phone,
      email: row.email,
      role: row.role,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      version: row.version,
    );
  }

  /// Converts a domain [Employee] entity into a Drift [EmployeesCompanion] for writes.
  ///
  /// Uses `EmployeesCompanion.insert()` which requires `id`, `name`, `createdAt`,
  /// and `updatedAt` as mandatory fields. All other fields use `db.Value()` to
  /// explicitly mark them as provided (even if null).
  db.EmployeesCompanion _toCompanion(Employee employee) {
    return db.EmployeesCompanion.insert(
      id: employee.id,
      name: employee.name,
      createdAt: employee.createdAt,
      updatedAt: employee.updatedAt,
      role: db.Value(employee.role),
      phone: db.Value(employee.phone),
      email: db.Value(employee.email),
      isActive: db.Value(employee.isActive),
      version: db.Value(employee.version),
    );
  }

  /// Converts a Drift [db.AttendanceData] row into a domain [Attendance] entity.
  Attendance _attendanceToEntity(db.AttendanceData row) {
    return Attendance(
      id: row.id,
      employeeId: row.employeeId,
      attendanceDate: row.attendanceDate,
      clockIn: row.clockIn,
      clockOut: row.clockOut,
      status: row.status,
      notes: row.notes,
    );
  }

  /// Converts a domain [Attendance] entity into a Drift [AttendanceCompanion] for writes.
  ///
  /// `clockIn` and `clockOut` are nullable — they start as null when the
  /// employee clocks in and are populated when they clock out.
  db.AttendanceCompanion _attendanceToCompanion(Attendance attendance) {
    return db.AttendanceCompanion.insert(
      id: attendance.id,
      employeeId: attendance.employeeId,
      attendanceDate: attendance.attendanceDate,
      status: db.Value(attendance.status),
      clockIn: db.Value(attendance.clockIn),
      clockOut: db.Value(attendance.clockOut),
      notes: db.Value(attendance.notes),
    );
  }
}
