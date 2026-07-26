import 'package:get_it/get_it.dart';
import '../features/products/data/datasources/product_local_datasource.dart';
import '../features/products/data/datasources/product_remote_datasource.dart';
import '../features/products/data/datasources/category_local_datasource.dart';
import '../features/products/data/repositories/product_repository_impl.dart';
import '../features/products/data/repositories/category_repository_impl.dart';
import '../features/products/domain/repositories/product_repository.dart';
import '../features/products/domain/repositories/category_repository.dart';
import '../features/products/domain/usecases/get_products_usecase.dart';
import '../features/products/domain/usecases/create_product_usecase.dart';
import '../features/products/domain/usecases/update_product_usecase.dart';
import '../features/products/domain/usecases/delete_product_usecase.dart';
import '../features/products/domain/usecases/get_product_by_id_usecase.dart';
import '../features/products/domain/usecases/get_categories_usecase.dart';
import '../features/products/domain/usecases/create_category_usecase.dart';
import '../features/products/domain/usecases/delete_category_usecase.dart';
import '../features/products/presentation/bloc/product_bloc.dart';

/// Registers products feature dependencies (includes categories).
///
/// Product catalog management — CRUD, search, barcode lookup.
///
/// Product category management — CRUD, filtering, color/icon assignment.
void registerProductsFeature(GetIt sl) {
  // ─── Feature: Products ──────────────────────────────────────────────────
  sl.registerFactory(() => ProductBloc(
    getProductsUseCase: sl(),
    createProductUseCase: sl(),
    updateProductUseCase: sl(),
    deleteProductUseCase: sl(),
    getProductByIdUseCase: sl(),
  ));
  sl.registerLazySingleton(() => GetProductsUseCase(sl()));
  sl.registerLazySingleton(() => CreateProductUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProductUseCase(sl()));
  sl.registerLazySingleton(() => DeleteProductUseCase(sl()));
  sl.registerLazySingleton(() => GetProductByIdUseCase(sl()));
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<ProductLocalDataSource>(
    () => ProductLocalDataSourceImpl(database: sl()),
  );

  // ─── Feature: Categories ───────────────────────────────────────────────
  sl.registerLazySingleton(() => GetCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => CreateCategoryUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCategoryUseCase(sl()));
  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<CategoryLocalDataSource>(
    () => CategoryLocalDataSourceImpl(database: sl()),
  );
}
