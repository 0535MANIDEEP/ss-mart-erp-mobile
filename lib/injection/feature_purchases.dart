import 'package:get_it/get_it.dart';
import '../features/purchases/data/datasources/purchase_local_datasource.dart';
import '../features/purchases/data/datasources/purchase_remote_datasource.dart';
import '../features/purchases/data/datasources/supplier_local_datasource.dart';
import '../features/purchases/data/datasources/supplier_remote_datasource.dart';
import '../features/purchases/data/repositories/purchase_repository_impl.dart';
import '../features/purchases/data/repositories/supplier_repository_impl.dart';
import '../features/purchases/domain/repositories/purchase_repository.dart';
import '../features/purchases/domain/repositories/supplier_repository.dart';
import '../features/purchases/domain/usecases/get_purchases_usecase.dart';
import '../features/purchases/domain/usecases/create_purchase_usecase.dart';
import '../features/purchases/domain/usecases/receive_purchase_usecase.dart';
import '../features/purchases/domain/usecases/get_suppliers_usecase.dart';
import '../features/purchases/domain/usecases/create_supplier_usecase.dart';
import '../features/purchases/domain/usecases/delete_supplier_usecase.dart';
import '../features/purchases/presentation/bloc/purchases_bloc.dart';

/// Registers purchases feature dependencies (includes suppliers).
///
/// Purchase order management — procurement from suppliers, goods receipt, stock update.
///
/// Supplier/vendor management — CRUD, contact details, GSTIN/PAN, credit terms.
void registerPurchasesFeature(GetIt sl) {
  // ─── Feature: Purchases ─────────────────────────────────────────────────
  sl.registerFactory(() => PurchasesBloc(
    getPurchasesUseCase: sl(),
    createPurchaseUseCase: sl(),
    receivePurchaseUseCase: sl(),
  ));
  sl.registerLazySingleton(() => GetPurchasesUseCase(sl()));
  sl.registerLazySingleton(() => CreatePurchaseUseCase(sl()));
  sl.registerLazySingleton(() => ReceivePurchaseUseCase(sl()));
  sl.registerLazySingleton<PurchaseRepository>(
    () => PurchaseRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<PurchaseRemoteDataSource>(
    () => PurchaseRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<PurchaseLocalDataSource>(
    () => PurchaseLocalDataSourceImpl(dao: sl()),
  );

  // ─── Feature: Suppliers ────────────────────────────────────────────────
  sl.registerLazySingleton(() => GetSuppliersUseCase(sl()));
  sl.registerLazySingleton(() => CreateSupplierUseCase(sl()));
  sl.registerLazySingleton(() => DeleteSupplierUseCase(sl()));
  sl.registerLazySingleton<SupplierRepository>(
    () => SupplierRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<SupplierRemoteDataSource>(
    () => SupplierRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<SupplierLocalDataSource>(
    () => SupplierLocalDataSourceImpl(database: sl()),
  );
}
