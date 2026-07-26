part of 'employee_bloc.dart';

abstract class EmployeeEvent extends Equatable {
  const EmployeeEvent();

  @override
  List<Object> get props => [];
}

class LoadEmployees extends EmployeeEvent {
  const LoadEmployees();
}

class ClockInRequested extends EmployeeEvent {
  final String employeeId;
  final String pin;

  const ClockInRequested({required this.employeeId, required this.pin});

  @override
  List<Object> get props => [employeeId, pin];
}

class ClockOutRequested extends EmployeeEvent {
  final String employeeId;
  final String pin;

  const ClockOutRequested({required this.employeeId, required this.pin});

  @override
  List<Object> get props => [employeeId, pin];
}

/// Event to load a single employee by their unique identifier.
class LoadEmployeeById extends EmployeeEvent {
  final String employeeId;

  const LoadEmployeeById({required this.employeeId});

  @override
  List<Object> get props => [employeeId];
}

/// Event to create a new employee in the system.
class CreateEmployee extends EmployeeEvent {
  final Employee employee;

  const CreateEmployee({required this.employee});

  @override
  List<Object> get props => [employee];
}

/// Event to update an existing employee record.
class UpdateEmployee extends EmployeeEvent {
  final Employee employee;

  const UpdateEmployee({required this.employee});

  @override
  List<Object> get props => [employee];
}

/// Event to soft-delete an employee by their identifier.
class DeleteEmployee extends EmployeeEvent {
  final String employeeId;

  const DeleteEmployee({required this.employeeId});

  @override
  List<Object> get props => [employeeId];
}

/// Event to load attendance records for an employee.
class LoadAttendance extends EmployeeEvent {
  final String? employeeId;

  const LoadAttendance({this.employeeId});

  @override
  List<Object> get props => [employeeId ?? ''];
}
