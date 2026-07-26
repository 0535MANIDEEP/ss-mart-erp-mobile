/// Settings Local Data Source — Local persistence layer for app settings, business
/// profiles, and sync configuration.
///
/// ## Architecture Role
/// Sits between [SettingsRepositoryImpl] and the Drift database. Abstracts all
/// details of how key-value settings, business profiles, and sync preferences are
/// stored, queried, and converted to/from domain entities. The repository never
/// touches raw SQL or DAO objects.
///
/// ## Responsibilities
/// - Generic key-value settings CRUD via the [AppSettings] table.
/// - Business profile CRUD via the [BusinessProfiles] table.
/// - Sync settings read/write (decomposed into individual key-value pairs).
/// - Bidirectional mapping between domain entities ([BusinessProfileEntity],
///   [SyncSettingsEntity]) and Drift row/companion objects.
///
/// ## Data Flow
/// ```
/// Repository → SettingsLocalDataSource → DatabaseDao (Drift) → SQLite
/// ```
///
/// ## Design Decisions
/// - Generic settings are stored as string key-value pairs in [AppSettings].
///   This is flexible and schema-free but type-unsafe. Callers must parse
///   values (e.g., `int.tryParse`) and provide defaults. An alternative would
///   be a typed settings model, but the current approach avoids migrations for
///   every new setting.
/// - Sync settings are decomposed into individual keys (`sync_auto`,
///   `sync_wifi_only`, `sync_frequency`, etc.) rather than a single JSON blob.
///   This allows individual settings to be read/written without deserializing
///   the entire sync config, which is important for the periodic sync scheduler
///   that only needs to check `sync_auto` and `sync_frequency`.
/// - The DAO is injected via constructor (not created from the database) to allow
///   the DI container to manage its lifecycle.
/// - `getBusinessProfile()` returns only the active profile. The app assumes a
///   single active business profile at a time (multi-profile switching is a
///   future feature).
library;

import '../../../../database/app_database.dart' as db;
import '../../../../database/database_dao.dart';
import '../../domain/entities/settings_entity.dart';

/// Abstract contract for local settings persistence.
///
/// The repository layer depends on this interface, not on the concrete
/// implementation, enabling unit testing with fakes/mocks.
abstract class SettingsLocalDataSource {
  /// Returns the value for [key], or `null` if no setting exists with that key.
  Future<String?> getSetting(String key);

  /// Inserts or updates a setting with the given [key] and [value].
  /// An optional [description] can be stored for audit/debugging purposes.
  Future<void> setSetting(String key, String value, {String? description});

  /// Returns all settings as a key-value map.
  Future<Map<String, String>> getAllSettings();

  /// Deletes a setting by its [key].
  Future<void> deleteSetting(String key);

  /// Returns the active business profile, or `null` if none is configured.
  Future<BusinessProfileEntity?> getBusinessProfile();

  /// Inserts or updates a business profile.
  Future<void> saveBusinessProfile(BusinessProfileEntity profile);

  /// Returns all business profiles (active and inactive).
  Future<List<BusinessProfileEntity>> getAllBusinessProfiles();

  /// Returns the current sync settings with defaults applied.
  Future<SyncSettingsEntity> getSyncSettings();

  /// Persists sync settings by decomposing them into individual key-value pairs.
  Future<void> saveSyncSettings(SyncSettingsEntity settings);
}

/// Concrete implementation backed by Drift's [DatabaseDao].
///
/// Handles the mapping between domain entities ([BusinessProfileEntity],
/// [SyncSettingsEntity]) and Drift row/companion objects. Generic settings
/// are transparent pass-throughs to the DAO.
class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  final DatabaseDao _dao;

  SettingsLocalDataSourceImpl({required DatabaseDao dao}) : _dao = dao;

  @override
  Future<String?> getSetting(String key) async {
    return await _dao.getSettingValue(key);
  }

  @override
  Future<void> setSetting(String key, String value, {String? description}) async {
    // Uses insertOrUpdate semantics — if the key exists, it's updated;
    // otherwise, a new row is inserted. The updatedAt timestamp is always
    // refreshed to track when settings were last modified.
    await _dao.insertOrUpdateSetting(
      db.AppSettingsCompanion.insert(
        key: key,
        value: value,
        description: db.Value(description),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Map<String, String>> getAllSettings() async {
    return await _dao.getSettingsAsMap();
  }

  @override
  Future<void> deleteSetting(String key) async {
    await _dao.deleteSetting(key);
  }

  @override
  Future<BusinessProfileEntity?> getBusinessProfile() async {
    final profile = await _dao.getActiveBusinessProfile();
    if (profile == null) return null;

    return BusinessProfileEntity(
      id: profile.id,
      companyName: profile.companyName,
      address: profile.address,
      city: profile.city,
      state: profile.state,
      pincode: profile.pincode,
      phone: profile.phone,
      email: profile.email,
      gstin: profile.gstin,
      pan: profile.pan,
      logoUrl: profile.logoUrl,
      isActive: profile.isActive,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
    );
  }

  @override
  Future<void> saveBusinessProfile(BusinessProfileEntity profile) async {
    await _dao.insertBusinessProfile(
      db.BusinessProfilesCompanion.insert(
        id: profile.id,
        companyName: profile.companyName,
        address: db.Value(profile.address),
        city: db.Value(profile.city),
        state: db.Value(profile.state),
        pincode: db.Value(profile.pincode),
        phone: db.Value(profile.phone),
        email: db.Value(profile.email),
        gstin: db.Value(profile.gstin),
        pan: db.Value(profile.pan),
        logoUrl: db.Value(profile.logoUrl),
        isActive: db.Value(profile.isActive),
        createdAt: profile.createdAt,
        // Always refresh the updatedAt timestamp on save.
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<BusinessProfileEntity>> getAllBusinessProfiles() async {
    final profiles = await _dao.getAllBusinessProfiles();
    return profiles.map((p) => BusinessProfileEntity(
      id: p.id,
      companyName: p.companyName,
      address: p.address,
      city: p.city,
      state: p.state,
      pincode: p.pincode,
      phone: p.phone,
      email: p.email,
      gstin: p.gstin,
      pan: p.pan,
      logoUrl: p.logoUrl,
      isActive: p.isActive,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    )).toList();
  }

  @override
  Future<SyncSettingsEntity> getSyncSettings() async {
    // Read each sync-related key individually with sensible defaults.
    // Defaults are chosen for a mobile-first, offline-first app:
    //   - autoSync: true (sync whenever possible)
    //   - syncOnWifiOnly: false (allow cellular data)
    //   - frequency: 15 minutes (balance between freshness and battery)
    //   - conflictResolution: 'server' (server wins — safest for POS data)
    final autoSync = await _dao.getSettingValue('sync_auto') ?? 'true';
    final syncOnWifi = await _dao.getSettingValue('sync_wifi_only') ?? 'false';
    final frequency = await _dao.getSettingValue('sync_frequency') ?? '15';
    final resolution = await _dao.getSettingValue('sync_conflict_resolution') ?? 'server';
    final lastSyncedStr = await _dao.getSettingValue('sync_last_synced');

    return SyncSettingsEntity(
      autoSync: autoSync == 'true',
      syncOnWifiOnly: syncOnWifi == 'true',
      syncFrequencyMinutes: int.tryParse(frequency) ?? 15,
      conflictResolution: resolution,
      lastSyncedAt: lastSyncedStr != null ? DateTime.tryParse(lastSyncedStr) : null,
    );
  }

  @override
  Future<void> saveSyncSettings(SyncSettingsEntity settings) async {
    final now = DateTime.now();
    // Each sync setting is stored as an independent key-value pair.
    // This allows the sync scheduler to read only the keys it needs
    // without deserializing the entire settings object.
    await _dao.insertOrUpdateSetting(
      db.AppSettingsCompanion.insert(
        key: 'sync_auto',
        value: settings.autoSync.toString(),
        updatedAt: now,
      ),
    );
    await _dao.insertOrUpdateSetting(
      db.AppSettingsCompanion.insert(
        key: 'sync_wifi_only',
        value: settings.syncOnWifiOnly.toString(),
        updatedAt: now,
      ),
    );
    await _dao.insertOrUpdateSetting(
      db.AppSettingsCompanion.insert(
        key: 'sync_frequency',
        value: settings.syncFrequencyMinutes.toString(),
        updatedAt: now,
      ),
    );
    await _dao.insertOrUpdateSetting(
      db.AppSettingsCompanion.insert(
        key: 'sync_conflict_resolution',
        value: settings.conflictResolution,
        updatedAt: now,
      ),
    );
    // Only persist lastSyncedAt if it has a value; otherwise leave the
    // existing value untouched (don't overwrite with null).
    if (settings.lastSyncedAt != null) {
      await _dao.insertOrUpdateSetting(
        db.AppSettingsCompanion.insert(
          key: 'sync_last_synced',
          value: settings.lastSyncedAt!.toIso8601String(),
          updatedAt: now,
        ),
      );
    }
  }
}
