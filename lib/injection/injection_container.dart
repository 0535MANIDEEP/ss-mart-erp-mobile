import 'package:get_it/get_it.dart';
import 'external_deps.dart';
import 'core_services.dart';
import 'feature_auth.dart';
import 'feature_products.dart';
import 'feature_customers.dart';
import 'feature_inventory.dart';
import 'feature_employees.dart';
import 'feature_loyalty.dart';
import 'feature_purchases.dart';
import 'feature_billing.dart';
import 'feature_dashboard.dart';
import 'feature_import_export.dart';
import 'feature_sync.dart';
import 'feature_settings.dart';
import 'feature_reports.dart';
import 'feature_orders.dart';
import 'feature_challans.dart';
import 'feature_accounting.dart';
import 'feature_labels.dart';

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
  registerExternalDependencies(sl);
  registerCoreServices(sl);
  registerAuthFeature(sl);
  registerProductsFeature(sl);
  registerCustomersFeature(sl);
  registerInventoryFeature(sl);
  registerEmployeesFeature(sl);
  registerLoyaltyFeature(sl);
  registerPurchasesFeature(sl);
  registerBillingFeature(sl);
  registerDashboardFeature(sl);
  registerImportExportFeature(sl);
  registerSyncFeature(sl);
  registerSettingsFeature(sl);
  registerReportsFeature(sl);
  registerChallansFeature(sl);
  registerAccountingFeature(sl);
  registerOrdersFeature(sl);
}
