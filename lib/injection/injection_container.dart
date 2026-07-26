import 'package:get_it/get_it.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../database/app_database.dart';
import '../database/database_dao.dart';
import '../core/network/network_info.dart';
import '../features/auth/data/datasources/auth_local_datasource.dart';
import '../features/auth/data/datasources/auth_remote_datasource.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/login_usecase.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
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
import '../features/loyalty/data/datasources/loyalty_local_datasource.dart';
import '../features/loyalty/data/datasources/loyalty_remote_datasource.dart';
import '../features/loyalty/data/repositories/loyalty_repository_impl.dart';
import '../features/loyalty/domain/repositories/loyalty_repository.dart';
import '../features/loyalty/domain/usecases/get_loyalty_balance_usecase.dart';
import '../features/loyalty/domain/usecases/earn_points_usecase.dart';
import '../features/loyalty/domain/usecases/redeem_points_usecase.dart';
import '../features/loyalty/presentation/bloc/loyalty_bloc.dart';
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
import '../features/billing/data/datasources/bill_local_datasource.dart';
import '../features/billing/data/datasources/bill_remote_datasource.dart';
import '../features/billing/data/repositories/bill_repository_impl.dart';
import '../features/billing/domain/repositories/bill_repository.dart';
import '../features/billing/domain/usecases/bill_usecases.dart';
import '../features/billing/presentation/bloc/billing_bloc.dart';
import '../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../features/dashboard/domain/usecases/get_dashboard_stats_usecase.dart';
import '../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../features/import_export/data/repositories/import_export_repository_impl.dart';
import '../features/import_export/domain/repositories/import_export_repository.dart';
import '../features/import_export/domain/usecases/import_export_usecases.dart';
import '../features/import_export/presentation/bloc/import_export_bloc.dart';
import '../features/sync/data/repositories/sync_repository_impl.dart';
import '../features/sync/domain/repositories/sync_repository.dart';
import '../features/sync/presentation/bloc/sync_bloc.dart';
import '../features/settings/data/datasources/settings_local_datasource.dart';
import '../features/settings/data/repositories/settings_repository_impl.dart';
import '../features/settings/domain/repositories/settings_repository.dart';
import '../features/settings/domain/usecases/settings_usecases.dart';
import '../features/reports/data/repositories/report_repository_impl.dart';
import '../features/reports/domain/repositories/report_repository.dart';
import '../features/reports/domain/usecases/get_report_usecase.dart';
import '../features/reports/domain/usecases/export_report_usecase.dart';
import '../features/reports/presentation/bloc/reports_bloc.dart';
import '../core/services/backup_service.dart';
import '../core/services/sync_service.dart';
import '../core/services/network_monitor.dart';
import '../core/services/bluetooth_printer_service.dart';
import '../core/services/rate_engine.dart';
import '../core/services/discount_engine.dart';
import '../core/services/scheme_engine.dart';
import '../core/services/bundle_pack_manager.dart';

/// Dependency Injection container for the SS MART ERP application.
///
/// Uses the `get_it` service locator to manage object lifetimes and
/// resolve dependencies across all feature modules. The container
/// follows a layered registration pattern:
///
/// 1. **External dependencies** (database, connectivity) — shared infrastructure
/// 2. **Core services** (network info) — cross-cutting concerns
/// 3. **Feature modules** (auth, products, customers, etc.) — each registered
///    in a consistent order: Bloc → UseCase → Repository → DataSource
///
/// ## Lifetime choices:
/// - **LazySingleton**: Objects created on first access, shared across the app.
///   Used for repositories, data sources, use cases, and the database —
///   these are stateless or stateful services that should persist.
/// - **Factory**: New instance on every request. Used for Blocs — each screen
///   gets a fresh Bloc to avoid stale state leaks between navigations.
///
/// ## Registration order per feature:
/// Each feature registers in dependency order (bottom-up):
/// 1. DataSource (local → remote)
/// 2. Repository (depends on data sources + network info)
/// 3. UseCase (depends on repository)
/// 4. Bloc (depends on use cases)
final sl = GetIt.instance;

/// Initializes the dependency injection container.
///
/// Must be called once at app startup (before any feature access).
/// Registers all external, core, and feature-level dependencies.
Future<void> init() async {
  // ─── External Dependencies ────────────────────────────────────────────────
  // Database and connectivity are shared across all features.
  // LazySingleton ensures only one instance is created per app lifecycle.
  final database = AppDatabase();
  final databaseDao = DatabaseDao(database);

  sl.registerLazySingleton(() => database);
  sl.registerLazySingleton(() => databaseDao);
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton(() => http.Client());

  // ─── Core Services ────────────────────────────────────────────────────────
  // NetworkInfo is a cross-cutting concern used by all repository
  // implementations to determine online/offline behavior.
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(connectivity: sl()),
  );

  // ─── Infrastructure Services ──────────────────────────────────────────────
  // Backup, Sync, and NetworkMonitor services shared across features.
  sl.registerLazySingleton<BackupService>(
    () => BackupService(),
  );
  sl.registerLazySingleton<SyncService>(
    () => SyncService(dao: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton<NetworkMonitor>(
    () => NetworkMonitor(connectivity: sl()),
  );
  sl.registerLazySingleton<BluetoothPrinterService>(
    () => BluetoothPrinterService(),
  );

  // ─── Feature: Rate Engine (v2) ──────────────────────────────────────────
  // Multi-rate pricing with party-wise overrides — Marg-style rate system.
  sl.registerLazySingleton<RateEngine>(
    () => RateEngine(dao: sl()),
  );

  // ─── Feature: Discount Engine (v2) ──────────────────────────────────────
  // Multi-level discount calculations — 4 bill-level + item-level discounts.
  sl.registerLazySingleton<DiscountEngine>(
    () => DiscountEngine(dao: sl()),
  );

  // ─── Feature: Scheme Engine (v2) ────────────────────────────────────────
  // Promotional scheme calculations — Buy X Get Y, volume, date-wise schemes.
  sl.registerLazySingleton<SchemeEngine>(
    () => SchemeEngine(dao: sl()),
  );

  // ─── Feature: Bundle Pack Manager (v2) ──────────────────────────────────
  // Bundle pack creation, editing, and loading for billing.
  sl.registerLazySingleton<BundlePackManager>(
    () => BundlePackManager(dao: sl()),
  );

  // ─── Feature: Auth ────────────────────────────────────────────────────────
  // Authentication feature — login, token management, session persistence.
  // Bloc is Factory (new instance per navigation); everything else is LazySingleton.
  sl.registerFactory(() => AuthBloc(loginUseCase: sl()));
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
      dao: sl(),
    ),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(dao: sl()),
  );

  // ─── Feature: Products ────────────────────────────────────────────────────
  // Product catalog management — CRUD, search, barcode lookup.
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

  // ─── Feature: Customers ───────────────────────────────────────────────────
  // Customer management — B2B/B2C profiles, credit accounts, transaction history.
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

  // ─── Feature: Inventory ───────────────────────────────────────────────────
  // Stock management — quantity tracking, adjustments, transfers, low-stock alerts.
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

  // ─── Feature: Employees ───────────────────────────────────────────────────
  // Employee management and attendance tracking — clock-in/clock-out with PIN auth.
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

  // ─── Feature: Loyalty ─────────────────────────────────────────────────────
  // Loyalty program — point accrual, redemption, balance tracking, expiry management.
  sl.registerFactory(() => LoyaltyBloc(
    getLoyaltyBalanceUseCase: sl(),
    earnPointsUseCase: sl(),
    redeemPointsUseCase: sl(),
  ));
  sl.registerLazySingleton(() => GetLoyaltyBalanceUseCase(sl()));
  sl.registerLazySingleton(() => EarnPointsUseCase(sl()));
  sl.registerLazySingleton(() => RedeemPointsUseCase(sl()));
  sl.registerLazySingleton<LoyaltyRepository>(
    () => LoyaltyRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<LoyaltyRemoteDataSource>(
    () => LoyaltyRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<LoyaltyLocalDataSource>(
    () => LoyaltyLocalDataSourceImpl(database: sl()),
  );

  // ─── Feature: Purchases ───────────────────────────────────────────────────
  // Purchase order management — procurement from suppliers, goods receipt, stock update.
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

  // ─── Feature: Billing ─────────────────────────────────────────────────────
  // POS billing — bill creation, returns, daily sales, invoice generation.
  // BillRepository depends on Stock, Loyalty, and Sync repositories for
  // atomic bill creation (stock deduction + loyalty accrual + sync enqueue).
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

  // ─── Feature: Dashboard ───────────────────────────────────────────────────
  // Dashboard data aggregation — reads from DAO to compile cross-feature metrics.
  sl.registerFactory(() => DashboardBloc(
    getDashboardStatsUseCase: sl(),
    repository: sl(),
  ));
  sl.registerLazySingleton(() => GetDashboardStatsUseCase(sl()));
  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(dao: sl(), connectivity: sl()),
  );

  // ─── Feature: Import/Export ───────────────────────────────────────────────
  // Bulk data import/export — CSV/Excel parsing, field mapping, validation, rollback.
  sl.registerFactory(() => ImportExportBloc(
    startImportUseCase: sl(),
    validateImportDataUseCase: sl(),
    exportDataUseCase: sl(),
    getImportLogsUseCase: sl(),
    rollbackImportUseCase: sl(),
    previewImportFileUseCase: sl(),
  ));
  sl.registerLazySingleton(() => StartImportUseCase(sl()));
  sl.registerLazySingleton(() => ValidateImportDataUseCase(sl()));
  sl.registerLazySingleton(() => ExportDataUseCase(sl()));
  sl.registerLazySingleton(() => GetImportLogsUseCase(sl()));
  sl.registerLazySingleton(() => RollbackImportUseCase(sl()));
  sl.registerLazySingleton(() => PreviewImportFileUseCase(sl()));
  sl.registerLazySingleton<ImportExportRepository>(
    () => ImportExportRepositoryImpl(dao: sl()),
  );

  // ─── Feature: Sync ────────────────────────────────────────────────────────
  // Offline-to-online sync — queue management, retry logic, conflict resolution.
  sl.registerFactory(() => SyncBloc(syncRepository: sl()));
  sl.registerLazySingleton<SyncRepository>(
    () => SyncRepositoryImpl(dao: sl()),
  );

  // ─── Feature: Settings ────────────────────────────────────────────────────
  // Application settings — key-value prefs, business profile, sync configuration.
  // Settings are local-only (no remote data source needed).
  sl.registerLazySingleton<SettingsLocalDataSource>(
    () => SettingsLocalDataSourceImpl(dao: sl()),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetSettingUseCase(sl()));
  sl.registerLazySingleton(() => SetSettingUseCase(sl()));
  sl.registerLazySingleton(() => GetAllSettingsUseCase(sl()));
  sl.registerLazySingleton(() => DeleteSettingUseCase(sl()));
  sl.registerLazySingleton(() => GetBusinessProfileUseCase(sl()));
  sl.registerLazySingleton(() => SaveBusinessProfileUseCase(sl()));
  sl.registerLazySingleton(() => GetAllBusinessProfilesUseCase(sl()));
  sl.registerLazySingleton(() => GetSyncSettingsUseCase(sl()));
  sl.registerLazySingleton(() => SaveSyncSettingsUseCase(sl()));

  // ─── Feature: Reports ─────────────────────────────────────────────────
  // Report generation and export — reads from DAO to compile cross-feature
  // analytics: sales, inventory, customer, employee, and purchase reports.
  // Bloc is Factory (new instance per navigation); everything else is LazySingleton.
  sl.registerFactory(() => ReportsBloc(
    getReportUseCase: sl(),
    exportReportUseCase: sl(),
  ));
  sl.registerLazySingleton(() => GetReportUseCase(sl()));
  sl.registerLazySingleton(() => ExportReportUseCase(sl()));
  sl.registerLazySingleton<ReportRepository>(
    () => ReportRepositoryImpl(dao: sl()),
  );

  // ─── Feature: Categories ─────────────────────────────────────────────
  // Product category management — CRUD, filtering, color/icon assignment.
  sl.registerLazySingleton(() => GetCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => CreateCategoryUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCategoryUseCase(sl()));
  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<CategoryLocalDataSource>(
    () => CategoryLocalDataSourceImpl(database: sl()),
  );

  // ─── Feature: Suppliers ──────────────────────────────────────────────
  // Supplier/vendor management — CRUD, contact details, GSTIN/PAN, credit terms.
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
