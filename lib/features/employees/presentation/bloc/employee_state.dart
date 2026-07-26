part of 'employee_bloc.dart';

abstract class EmployeeState extends Equatable {
  const EmployeeState();

  @override
  List<Object> get props => [];
}

class EmployeeInitial extends EmployeeState {
  const EmployeeInitial();
}

class EmployeeLoading extends EmployeeState {
  const EmployeeLoading();
}

class ClockInOutLoading extends EmployeeState {
  const ClockInOutLoading();
}

class EmployeesLoaded extends EmployeeState {
  final List<Employee> employees;

  const EmployeesLoaded({required this.employees});

  @override
  List<Object> get props => [employees];
}

class ClockInSuccess extends EmployeeState {
  final Attendance attendance;

  const ClockInSuccess({required this.attendance});

  @override
  List<Object> get props => [attendance];
}

class ClockOutSuccess extends EmployeeState {
  final Attendance attendance;

  const ClockOutSuccess({required this.attendance});

  @override
  List<Object> get props => [attendance];
}

/// State emitted after a successful create, update, or delete operation.
class EmployeeOperationSuccess extends EmployeeState {
  final String message;

  const EmployeeOperationSuccess({required this.message});

  @override
  List<Object> get props => [message];
}

/// State emitted when a single employee detail is loaded successfully.
class EmployeeDetailLoaded extends EmployeeState {
  final Employee employee;

  const EmployeeDetailLoaded({required this.employee});

  @override
  List<Object> get props => [employee];
}

/// State emitted when attendance records are loaded successfully.
class AttendanceLoaded extends EmployeeState {
  final List<Attendance> attendance;

  const AttendanceLoaded({required this.attendance});

  @override
  List<Object> get props => [attendance];
}

class EmployeeError extends EmployeeState {
  final String message;

  const EmployeeError({required this.message});

  @override
  List<Object> get props => [message];
}
