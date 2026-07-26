import 'package:get_it/get_it.dart';
import '../features/billing/data/datasources/bill_local_datasource.dart';
import '../features/billing/data/datasources/bill_remote_datasource.dart';
import '../features/billing/data/repositories/bill_repository_impl.dart';
import '../features/billing/domain/repositories/bill_repository.dart';
import '../features/billing/domain/usecases/bill_usecases.dart';
import '../features/billing/presentation/bloc/billing_bloc.dart';

/// Registers billing feature dependencies.
///
/// POS billing — bill creation, returns, daily sales, invoice generation.
/// BillRepository depends on Stock, Loyalty, and Sync repositories for
/// atomic bill creation (stock deduction + loyalty accrual + sync enqueue).
void registerBillingFeature(GetIt sl) {
  sl.registerFactory(() => BillingBloc(
    createBillUseCase: sl(),
    getDaySalesTotalUseCase: sl(),
    getRecentBillsUseCase: sl(),
  ));
  sl.registerLazySingleton(() => CreateBillUseCase(sl()));
  sl.registerLazySingleton(() => GetBillByIdUseCase(sl()));
  sl.registerLazySingleton(() => GetBillsUseCase(sl()));
  sl.registerLazySingleton(() => GetDaySalesTotalUseCase(sl()));
  sl.registerLazySingleton(() => GetRecentBillsUseCase(sl()));
  sl.registerLazySingleton(() => ProcessReturnUseCase(sl()));
  sl.registerLazySingleton(() => GetTodayBillCountUseCase(sl()));
  sl.registerLazySingleton<BillLocalDataSource>(
    () => BillLocalDataSourceImpl(database: sl()),
  );
  sl.registerLazySingleton<BillRemoteDataSource>(
    () => BillRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<BillRepository>(
    () => BillRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      stockRepository: sl(),
      loyaltyRepository: sl(),
      syncRepository: sl(),
    ),
  );
}
