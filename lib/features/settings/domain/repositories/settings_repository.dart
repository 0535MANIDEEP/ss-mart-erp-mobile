import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/settings_entity.dart';

/// Abstract repository contract for application settings and configuration management.
///
/// This interface defines the data access boundary for the settings feature.
/// Manages three categories of settings:
/// - **Key-value settings**: Generic app preferences (theme, notifications, etc.)
/// - **Business profile**: Store details for receipts and tax compliance
/// - **Sync settings**: Offline/online sync behavior configuration
///
/// All settings are persisted locally and synced to the server when available.
///
/// All methods return [Either<Failure, T>] to enable functional error handling
/// without exceptions, following the Clean Architecture data flow convention.
abstract class SettingsRepository {
  /// Retrieves a single setting value by its unique key.
  /// Returns null if the key does not exist.
  Future<Either<Failure, String?>> getSetting(String key);

  /// Persists a key-value setting.
  /// [description] is optional metadata explaining the setting's purpose.
  Future<Either<Failure, void>> setSetting(String key, String value, {String? description});

  /// Retrieves all persisted settings as a key-value map.
  Future<Either<Failure, Map<String, String>>> getAllSettings();

  /// Removes a setting by its key.
  Future<Either<Failure, void>> deleteSetting(String key);

  /// Retrieves the currently active business profile (store details).
  /// Returns null if no business profile has been configured.
  Future<Either<Failure, BusinessProfileEntity?>> getBusinessProfile();

  /// Persists the business profile (store name, GSTIN, address, etc.).
  Future<Either<Failure, void>> saveBusinessProfile(BusinessProfileEntity profile);

  /// Retrieves all saved business profiles (for multi-store support).
  Future<Either<Failure, List<BusinessProfileEntity>>> getAllBusinessProfiles();

  /// Retrieves the current sync configuration (interval, retry policy, etc.).
  Future<Either<Failure, SyncSettingsEntity>> getSyncSettings();

  /// Persists the sync configuration.
  Future<Either<Failure, void>> saveSyncSettings(SyncSettingsEntity settings);
}
