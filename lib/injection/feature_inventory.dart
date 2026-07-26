import 'package:get_it/get_it.dart';
import '../features/inventory/data/datasources/stock_local_datasource.dart';
import '../features/inventory/data/datasources/stock_remote_datasource.dart';
import '../features/inventory/data/repositories/stock_repository_impl.dart';
import '../features/inventory/domain/repositories/stock_repository.dart';
import '../features/inventory/domain/usecases/get_stock_usecase.dart';
import '../features/inventory/domain/usecases/adjust_stock_usecase.dart';
import '../features/inventory/domain/usecases/transfer_stock_usecase.dart';
import '../features/inventory/domain/usecases/get_stock_by_product_id_usecase.dart';
import '../features/inventory/domain/usecases/search_stock_usecase.dart';
import '../features/inventory/domain/usecases/get_expiring_products_usecase.dart';
import '../features/inventory/domain/usecases/get_batch_stock_usecase.dart';
import '../features/inventory/presentation/bloc/inventory_bloc.dart';

/// Registers inventory feature dependencies.
///
/// Stock management — quantity tracking, adjustments, transfers, low-stock alerts.
void registerInventoryFeature(GetIt sl) {
  sl.registerFactory(() => InventoryBloc(
    getStockUseCase: sl(),
    adjustStockUseCase: sl(),
    transferStockUseCase: sl(),
    getStockByProductIdUseCase: sl(),
    searchStockUseCase: sl(),
    getExpiringProductsUseCase: sl(),
    getBatchStockUseCase: sl(),
  ));
  sl.registerLazySingleton(() => GetStockUseCase(sl()));
  sl.registerLazySingleton(() => AdjustStockUseCase(sl()));
  sl.registerLazySingleton(() => TransferStockUseCase(sl()));
  sl.registerLazySingleton(() => GetStockByProductIdUseCase(sl()));
  sl.registerLazySingleton(() => SearchStockUseCase(sl()));
  sl.registerLazySingleton(() => GetExpiringProductsUseCase(sl()));
  sl.registerLazySingleton(() => GetBatchStockUseCase(sl()));
  sl.registerLazySingleton<StockRepository>(
    () => StockRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<StockRemoteDataSource>(
    () => StockRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<StockLocalDataSource>(
    () => StockLocalDataSourceImpl(database: sl()),
  );
}
