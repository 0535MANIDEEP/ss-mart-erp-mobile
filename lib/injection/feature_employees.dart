import 'package:get_it/get_it.dart';
import '../features/employees/data/datasources/employee_local_datasource.dart';
import '../features/employees/data/datasources/employee_remote_datasource.dart';
import '../features/employees/data/repositories/employee_repository_impl.dart';
import '../features/employees/domain/repositories/employee_repository.dart';
import '../features/employees/domain/usecases/get_employees_usecase.dart';
import '../features/employees/domain/usecases/clock_in_usecase.dart';
import '../features/employees/domain/usecases/clock_out_usecase.dart';
import '../features/employees/domain/usecases/create_employee_usecase.dart';
import '../features/employees/domain/usecases/update_employee_usecase.dart';
import '../features/employees/domain/usecases/delete_employee_usecase.dart';
import '../features/employees/domain/usecases/get_employee_by_id_usecase.dart';
import '../features/employees/domain/usecases/validate_pin_usecase.dart';
import '../features/employees/domain/usecases/get_attendance_usecase.dart';
import '../features/employees/presentation/bloc/employee_bloc.dart';

/// Registers employees feature dependencies.
///
/// Employee management and attendance tracking — clock-in/clock-out with PIN auth.
void registerEmployeesFeature(GetIt sl) {
  sl.registerFactory(() => EmployeeBloc(
    getEmployeesUseCase: sl(),
    clockInUseCase: sl(),
    clockOutUseCase: sl(),
    createEmployeeUseCase: sl(),
    updateEmployeeUseCase: sl(),
    deleteEmployeeUseCase: sl(),
    getEmployeeByIdUseCase: sl(),
    validatePinUseCase: sl(),
    getAttendanceUseCase: sl(),
  ));
  sl.registerLazySingleton(() => GetEmployeesUseCase(sl()));
  sl.registerLazySingleton(() => ClockInUseCase(sl()));
  sl.registerLazySingleton(() => ClockOutUseCase(sl()));
  sl.registerLazySingleton(() => CreateEmployeeUseCase(sl()));
  sl.registerLazySingleton(() => UpdateEmployeeUseCase(sl()));
  sl.registerLazySingleton(() => DeleteEmployeeUseCase(sl()));
  sl.registerLazySingleton(() => GetEmployeeByIdUseCase(sl()));
  sl.registerLazySingleton(() => ValidatePinUseCase(sl()));
  sl.registerLazySingleton(() => GetAttendanceUseCase(sl()));
  sl.registerLazySingleton<EmployeeRepository>(
    () => EmployeeRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<EmployeeRemoteDataSource>(
    () => EmployeeRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<EmployeeLocalDataSource>(
    () => EmployeeLocalDataSourceImpl(database: sl()),
  );
}
