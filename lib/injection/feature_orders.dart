import 'package:get_it/get_it.dart';
import '../features/orders/data/datasources/order_local_datasource.dart';
import '../features/orders/data/repositories/order_repository_impl.dart';
import '../features/orders/domain/repositories/order_repository.dart';
import '../features/orders/domain/usecases/get_sales_orders_usecase.dart';
import '../features/orders/domain/usecases/get_purchase_orders_usecase.dart';
import '../features/orders/domain/usecases/get_sales_order_by_id_usecase.dart';
import '../features/orders/domain/usecases/get_purchase_order_by_id_usecase.dart';
import '../features/orders/domain/usecases/create_sales_order_usecase.dart';
import '../features/orders/domain/usecases/create_purchase_order_usecase.dart';
import '../features/orders/domain/usecases/update_order_status_usecase.dart';
import '../features/orders/domain/usecases/delete_order_usecase.dart';
import '../features/orders/domain/usecases/convert_sales_order_to_bill_usecase.dart';
import '../features/orders/domain/usecases/convert_purchase_order_to_receipt_usecase.dart';
import '../features/orders/presentation/bloc/orders_bloc.dart';

/// Registers orders feature dependencies.
///
/// Sales orders and purchase orders — order lifecycle management,
/// status tracking, and conversion to bills/stock receipts.
void registerOrdersFeature(GetIt sl) {
  // BLoC — registered as Factory so each screen gets a fresh instance.
  sl.registerFactory(() => OrdersBloc(
        getSalesOrdersUseCase: sl(),
        getPurchaseOrdersUseCase: sl(),
        getSalesOrderByIdUseCase: sl(),
        getPurchaseOrderByIdUseCase: sl(),
        createSalesOrderUseCase: sl(),
        createPurchaseOrderUseCase: sl(),
        updateOrderStatusUseCase: sl(),
        deleteOrderUseCase: sl(),
        convertSalesOrderToBillUseCase: sl(),
        convertPurchaseOrderToReceiptUseCase: sl(),
      ));

  // Use cases — registered as LazySingleton (stateless, shared).
  sl.registerLazySingleton(() => GetSalesOrdersUseCase(sl()));
  sl.registerLazySingleton(() => GetPurchaseOrdersUseCase(sl()));
  sl.registerLazySingleton(() => GetSalesOrderByIdUseCase(sl()));
  sl.registerLazySingleton(() => GetPurchaseOrderByIdUseCase(sl()));
  sl.registerLazySingleton(() => CreateSalesOrderUseCase(sl()));
  sl.registerLazySingleton(() => CreatePurchaseOrderUseCase(sl()));
  sl.registerLazySingleton(() => UpdateOrderStatusUseCase(sl()));
  sl.registerLazySingleton(() => DeleteOrderUseCase(sl()));
  sl.registerLazySingleton(() => ConvertSalesOrderToBillUseCase(sl()));
  sl.registerLazySingleton(() => ConvertPurchaseOrderToReceiptUseCase(sl()));

  // Repository — registered as LazySingleton.
  sl.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(
      localDataSource: sl(),
    ),
  );

  // Data sources — registered as LazySingleton.
  sl.registerLazySingleton<OrderLocalDataSource>(
    () => OrderLocalDataSourceImpl(database: sl()),
  );
}
