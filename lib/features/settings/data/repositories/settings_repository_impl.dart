import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';

/// Implementation of [SettingsRepository] for managing app configuration,
/// business profiles, and sync settings.
///
/// ## Architecture
///
/// This repository is **purely local** — all settings are stored and read
/// from [SettingsLocalDataSource] (local SharedPreferences/Drift DB).
/// There is no remote data source interaction, as settings are device-local
/// configuration that does not need server synchronization.
///
/// ### Settings Storage
/// - **Key-Value Settings**: Generic key-value pairs for arbitrary app
///   configuration (e.g., theme, language, receipt printer settings).
///   Stored as strings with optional descriptions.
/// - **Business Profile**: Structured entity containing business name,
///   address, GSTIN, logo, and other merchant details used for invoice
///   generation and branding.
/// - **Sync Settings**: Configuration for the sync behavior (sync interval,
///   auto-sync toggle, Wi-Fi-only mode, etc.).
///
/// ### Error Handling
/// - All methods return `Either<Failure, T>`.
/// - [CacheFailure] is used for all errors (since this is a local-only
///   repository, all failures are local/cache-related).
///
/// ### Relationship to Other Components
/// - Settings are consumed by the billing module (business profile for
///   invoice headers), sync module (sync settings for scheduling), and
///   UI layer (theme, language preferences).
/// - Settings are NOT synced to the remote server — they are device-local.
class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource _localDataSource;

  SettingsRepositoryImpl({required SettingsLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  /// Retrieves a setting value by its key. Returns null if the key does not exist.
  @override
  Future<Either<Failure, String?>> getSetting(String key) async {
    try {
      final value = await _localDataSource.getSetting(key);
      return Right(value);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Saves or updates a key-value setting. Optionally includes a description
  /// for documentation purposes (stored alongside the value).
  @override
  Future<Either<Failure, void>> setSetting(String key, String value, {String? description}) async {
    try {
      await _localDataSource.setSetting(key, value, description: description);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Returns all stored settings as a key-value map.
  @override
  Future<Either<Failure, Map<String, String>>> getAllSettings() async {
    try {
      final settings = await _localDataSource.getAllSettings();
      return Right(settings);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Deletes a setting by its key.
  @override
  Future<Either<Failure, void>> deleteSetting(String key) async {
    try {
      await _localDataSource.deleteSetting(key);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Returns the primary business profile, or null if none is configured.
  ///
  /// The business profile is used for invoice headers, receipt branding,
  /// and GST compliance information.
  @override
  Future<Either<Failure, BusinessProfileEntity?>> getBusinessProfile() async {
    try {
      final profile = await _localDataSource.getBusinessProfile();
      return Right(profile);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Saves or updates the business profile.
  @override
  Future<Either<Failure, void>> saveBusinessProfile(BusinessProfileEntity profile) async {
    try {
      await _localDataSource.saveBusinessProfile(profile);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Returns all stored business profiles (supports multi-business scenarios).
  @override
  Future<Either<Failure, List<BusinessProfileEntity>>> getAllBusinessProfiles() async {
    try {
      final profiles = await _localDataSource.getAllBusinessProfiles();
      return Right(profiles);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Returns the current sync configuration (interval, auto-sync, Wi-Fi-only, etc.).
  @override
  Future<Either<Failure, SyncSettingsEntity>> getSyncSettings() async {
    try {
      final settings = await _localDataSource.getSyncSettings();
      return Right(settings);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Saves or updates the sync configuration.
  @override
  Future<Either<Failure, void>> saveSyncSettings(SyncSettingsEntity settings) async {
    try {
      await _localDataSource.saveSyncSettings(settings);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }
}
