import 'package:get_it/get_it.dart';
import '../core/network/network_info.dart';
import '../core/services/backup_service.dart';
import '../core/services/sync_service.dart';
import '../core/services/network_monitor.dart';
import '../core/services/bluetooth_printer_service.dart';
import '../core/services/rate_engine.dart';
import '../core/services/discount_engine.dart';
import '../core/services/scheme_engine.dart';
import '../core/services/bundle_pack_manager.dart';

/// Registers core services shared across features.
///
/// NetworkInfo is a cross-cutting concern used by all repository
/// implementations to determine online/offline behavior.
///
/// Infrastructure services (Backup, Sync, NetworkMonitor) are shared
/// across features.
void registerCoreServices(GetIt sl) {
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(connectivity: sl()),
  );

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
}
