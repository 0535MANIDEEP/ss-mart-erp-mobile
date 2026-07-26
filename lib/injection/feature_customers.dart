import 'package:get_it/get_it.dart';
import '../features/customers/data/datasources/customer_local_datasource.dart';
import '../features/customers/data/datasources/customer_remote_datasource.dart';
import '../features/customers/data/repositories/customer_repository_impl.dart';
import '../features/customers/domain/repositories/customer_repository.dart';
import '../features/customers/domain/usecases/get_customers_usecase.dart';
import '../features/customers/domain/usecases/create_customer_usecase.dart';
import '../features/customers/domain/usecases/update_customer_usecase.dart';
import '../features/customers/domain/usecases/delete_customer_usecase.dart';
import '../features/customers/domain/usecases/get_customer_by_id_usecase.dart';
import '../features/customers/presentation/bloc/customer_bloc.dart';

/// Registers customers feature dependencies.
///
/// Customer management — B2B/B2C profiles, credit accounts, transaction history.
void registerCustomersFeature(GetIt sl) {
  sl.registerFactory(() => CustomerBloc(
    getCustomersUseCase: sl(),
    createCustomerUseCase: sl(),
    updateCustomerUseCase: sl(),
    deleteCustomerUseCase: sl(),
    getCustomerByIdUseCase: sl(),
  ));
  sl.registerLazySingleton(() => GetCustomersUseCase(sl()));
  sl.registerLazySingleton(() => CreateCustomerUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCustomerUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCustomerUseCase(sl()));
  sl.registerLazySingleton(() => GetCustomerByIdUseCase(sl()));
  sl.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<CustomerRemoteDataSource>(
    () => CustomerRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<CustomerLocalDataSource>(
    () => CustomerLocalDataSourceImpl(database: sl()),
  );
}
