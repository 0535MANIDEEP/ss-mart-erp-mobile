import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/usecases/get_employees_usecase.dart';
import '../../domain/usecases/clock_in_usecase.dart';
import '../../domain/usecases/clock_out_usecase.dart';
import '../../domain/usecases/create_employee_usecase.dart';
import '../../domain/usecases/update_employee_usecase.dart';
import '../../domain/usecases/delete_employee_usecase.dart';
import '../../domain/usecases/get_employee_by_id_usecase.dart';
import '../../domain/usecases/validate_pin_usecase.dart';
import '../../domain/usecases/get_attendance_usecase.dart';

part 'employee_event.dart';
part 'employee_state.dart';

class EmployeeBloc extends Bloc<EmployeeEvent, EmployeeState> {
  final GetEmployeesUseCase getEmployeesUseCase;
  final ClockInUseCase clockInUseCase;
  final ClockOutUseCase clockOutUseCase;
  final CreateEmployeeUseCase createEmployeeUseCase;
  final UpdateEmployeeUseCase updateEmployeeUseCase;
  final DeleteEmployeeUseCase deleteEmployeeUseCase;
  final GetEmployeeByIdUseCase getEmployeeByIdUseCase;
  final ValidatePinUseCase validatePinUseCase;
  final GetAttendanceUseCase getAttendanceUseCase;

  EmployeeBloc({
    required this.getEmployeesUseCase,
    required this.clockInUseCase,
    required this.clockOutUseCase,
    required this.createEmployeeUseCase,
    required this.updateEmployeeUseCase,
    required this.deleteEmployeeUseCase,
    required this.getEmployeeByIdUseCase,
    required this.validatePinUseCase,
    required this.getAttendanceUseCase,
  }) : super(EmployeeInitial()) {
    on<LoadEmployees>(_onLoadEmployees);
    on<ClockInRequested>(_onClockIn);
    on<ClockOutRequested>(_onClockOut);
    on<LoadEmployeeById>(_onLoadEmployeeById);
    on<LoadAttendance>(_onLoadAttendance);
    on<CreateEmployee>(_onCreateEmployee);
    on<UpdateEmployee>(_onUpdateEmployee);
    on<DeleteEmployee>(_onDeleteEmployee);
  }

  Future<void> _onLoadEmployees(
    LoadEmployees event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(EmployeeLoading());
    final result = await getEmployeesUseCase(
      const GetEmployeesParams(),
    );
    result.fold(
      (failure) => emit(EmployeeError(message: failure.message)),
      (employees) => emit(EmployeesLoaded(employees: employees)),
    );
  }

  Future<void> _onClockIn(
    ClockInRequested event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(ClockInOutLoading());
    final result = await clockInUseCase(
      ClockInParams(employeeId: event.employeeId, pin: event.pin),
    );
    result.fold(
      (failure) => emit(EmployeeError(message: failure.message)),
      (attendance) => emit(ClockInSuccess(attendance: attendance)),
    );
  }

  Future<void> _onClockOut(
    ClockOutRequested event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(ClockInOutLoading());
    final result = await clockOutUseCase(
      ClockOutParams(employeeId: event.employeeId, pin: event.pin),
    );
    result.fold(
      (failure) => emit(EmployeeError(message: failure.message)),
      (attendance) => emit(ClockOutSuccess(attendance: attendance)),
    );
  }

  Future<void> _onLoadEmployeeById(
    LoadEmployeeById event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(EmployeeLoading());
    final result = await getEmployeeByIdUseCase(event.employeeId);
    result.fold(
      (failure) => emit(EmployeeError(message: failure.message)),
      (employee) => emit(EmployeeDetailLoaded(employee: employee)),
    );
  }

  Future<void> _onLoadAttendance(
    LoadAttendance event,
    Emitter<EmployeeState> emit,
  ) async {
    final result = await getAttendanceUseCase(
      GetAttendanceParams(employeeId: event.employeeId),
    );
    result.fold(
      (failure) => emit(EmployeeError(message: failure.message)),
      (attendance) => emit(AttendanceLoaded(attendance: attendance)),
    );
  }

  Future<void> _onCreateEmployee(
    CreateEmployee event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(EmployeeLoading());
    final result = await createEmployeeUseCase(event.employee);
    result.fold(
      (failure) => emit(EmployeeError(message: failure.message)),
      (employee) => emit(
        const EmployeeOperationSuccess(message: 'Employee created successfully'),
      ),
    );
  }

  Future<void> _onUpdateEmployee(
    UpdateEmployee event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(EmployeeLoading());
    final result = await updateEmployeeUseCase(event.employee);
    result.fold(
      (failure) => emit(EmployeeError(message: failure.message)),
      (employee) => emit(
        const EmployeeOperationSuccess(message: 'Employee updated successfully'),
      ),
    );
  }

  Future<void> _onDeleteEmployee(
    DeleteEmployee event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(EmployeeLoading());
    final result = await deleteEmployeeUseCase(event.employeeId);
    result.fold(
      (failure) => emit(EmployeeError(message: failure.message)),
      (_) => emit(
        const EmployeeOperationSuccess(message: 'Employee deleted successfully'),
      ),
    );
  }
}
