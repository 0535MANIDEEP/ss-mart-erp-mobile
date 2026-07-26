import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/employee_entity.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';

/// Abstract contract for remote employee operations.
///
/// Defines the interface for communicating with the employees API endpoints.
/// Implementations handle HTTP requests, JSON serialization, and error mapping.
abstract class EmployeeRemoteDataSource {
  /// Fetches a paginated list of employees with optional filters.
  ///
  /// [role] filters by employee role.
  /// [isActive] filters by active status.
  /// [page] and [perPage] control pagination.
  Future<List<Employee>> getEmployees({
    String? role,
    bool isActive = true,
    int page = 1,
    int perPage = 20,
  });

  /// Fetches a single employee by their unique [id].
  Future<Employee> getEmployeeById(String id);

  /// Creates a new employee record.
  Future<Employee> createEmployee(Employee employee);

  /// Updates an existing employee record.
  Future<Employee> updateEmployee(Employee employee);

  /// Deletes the employee identified by [id].
  Future<void> deleteEmployee(String id);

  /// Validates the PIN for the given [employeeId].
  ///
  /// Returns `true` if the PIN is correct, `false` otherwise.
  Future<bool> validatePin(String employeeId, String pin);

  /// Clocks in the employee identified by [employeeId] using their [pin].
  ///
  /// Returns the created [Attendance] record with clock-in time.
  Future<Attendance> clockIn(String employeeId, String pin);

  /// Clocks out the employee identified by [employeeId] using their [pin].
  ///
  /// Returns the updated [Attendance] record with clock-out time.
  Future<Attendance> clockOut(String employeeId, String pin);

  /// Fetches attendance records with optional date range and employee filters.
  Future<List<Attendance>> getAttendance({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  });
}

/// Remote data source implementation for employee endpoints.
///
/// Communicates with `/employees` and `/attendance` REST endpoints using
/// the base URL from [AppConstants].
class EmployeeRemoteDataSourceImpl implements EmployeeRemoteDataSource {
  final http.Client _client;

  /// Creates an [EmployeeRemoteDataSourceImpl] with the given HTTP [client].
  EmployeeRemoteDataSourceImpl({required http.Client client}) : _client = client;

  Employee _parseEmployee(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'cashier',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> _employeeToJson(Employee e) {
    return {
      'id': e.id,
      'name': e.name,
      'phone': e.phone,
      'email': e.email,
      'role': e.role,
      'isActive': e.isActive,
      'createdAt': e.createdAt.toIso8601String(),
      'updatedAt': e.updatedAt.toIso8601String(),
      'version': e.version,
    };
  }

  Attendance _parseAttendance(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      attendanceDate: DateTime.parse(json['attendanceDate'] as String),
      clockIn: json['clockIn'] != null
          ? DateTime.parse(json['clockIn'] as String)
          : null,
      clockOut: json['clockOut'] != null
          ? DateTime.parse(json['clockOut'] as String)
          : null,
      status: json['status'] as String? ?? 'present',
      notes: json['notes'] as String?,
    );
  }

  @override
  Future<List<Employee>> getEmployees({
    String? role,
    bool isActive = true,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      'is_active': isActive.toString(),
    };
    if (role != null && role.isNotEmpty) {
      queryParams['role'] = role;
    }

    final url = Uri.parse('${AppConstants.baseUrl}/employees')
        .replace(queryParameters: queryParams);
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data is Map<String, dynamic> && data.containsKey('data')
          ? data['data'] as List
          : data as List;
      return items
          .map((e) => _parseEmployee(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ServerException(
        message: 'Failed to fetch employees: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Employee> getEmployeeById(String id) async {
    final url = Uri.parse('${AppConstants.baseUrl}/employees/$id');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return _parseEmployee(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to fetch employee: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Employee> createEmployee(Employee employee) async {
    final url = Uri.parse('${AppConstants.baseUrl}/employees');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(_employeeToJson(employee)),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _parseEmployee(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to create employee: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Employee> updateEmployee(Employee employee) async {
    final url = Uri.parse('${AppConstants.baseUrl}/employees/${employee.id}');
    final response = await _client.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(_employeeToJson(employee)),
    );

    if (response.statusCode == 200) {
      return _parseEmployee(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to update employee: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<void> deleteEmployee(String id) async {
    final url = Uri.parse('${AppConstants.baseUrl}/employees/$id');
    final response = await _client.delete(url);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ServerException(
        message: 'Failed to delete employee: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<bool> validatePin(String employeeId, String pin) async {
    final url = Uri.parse('${AppConstants.baseUrl}/employees/$employeeId/validate-pin');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pin': pin}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['valid'] as bool? ?? false;
    } else {
      throw ServerException(
        message: 'Failed to validate PIN: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Attendance> clockIn(String employeeId, String pin) async {
    final url = Uri.parse('${AppConstants.baseUrl}/employees/$employeeId/clock-in');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pin': pin}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _parseAttendance(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to clock in: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Attendance> clockOut(String employeeId, String pin) async {
    final url = Uri.parse('${AppConstants.baseUrl}/employees/$employeeId/clock-out');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pin': pin}),
    );

    if (response.statusCode == 200) {
      return _parseAttendance(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to clock out: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<List<Attendance>> getAttendance({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (employeeId != null && employeeId.isNotEmpty) {
      queryParams['employee_id'] = employeeId;
    }
    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }

    final url = Uri.parse('${AppConstants.baseUrl}/attendance')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data is Map<String, dynamic> && data.containsKey('data')
          ? data['data'] as List
          : data as List;
      return items
          .map((e) => _parseAttendance(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ServerException(
        message: 'Failed to fetch attendance: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}
