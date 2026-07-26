import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart' as drift;
import 'package:matcher/matcher.dart' as matcher;
import 'package:ss_mart/database/app_database.dart' as db;
import 'package:ss_mart/database/database_dao.dart';
import 'package:ss_mart/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:ss_mart/features/settings/domain/entities/settings_entity.dart';

class MockDatabaseDao extends Mock implements DatabaseDao {}

void main() {
setUpAll(() {
    registerFallbackValue(db.AppSettingsCompanion(
      key: drift.Value(''), value: drift.Value(''), updatedAt: drift.Value(DateTime.now()),
    ));
    registerFallbackValue(db.BusinessProfilesCompanion(
      id: drift.Value(''), companyName: drift.Value(''), isActive: drift.Value(true),
      createdAt: drift.Value(DateTime.now()), updatedAt: drift.Value(DateTime.now()),
    ));
  });

  group('SettingsLocalDataSourceImpl', () {
    late MockDatabaseDao mockDao;
    late SettingsLocalDataSourceImpl dataSource;

    setUp(() {
      mockDao = MockDatabaseDao();
      dataSource = SettingsLocalDataSourceImpl(dao: mockDao);
    });

    test('getSetting returns value from dao', () async {
      when(() => mockDao.getSettingValue('key1')).thenAnswer((_) async => 'value1');
      expect(await dataSource.getSetting('key1'), 'value1');
    });

    test('getSetting returns null when dao returns null', () async {
      when(() => mockDao.getSettingValue('missing')).thenAnswer((_) async => null);
      expect(await dataSource.getSetting('missing'), matcher.isNull);
    });

    test('setSetting calls insertOrUpdateSetting', () async {
      when(() => mockDao.insertOrUpdateSetting(any())).thenAnswer((_) async => 1);
      
      await dataSource.setSetting('key1', 'value1', description: 'desc');
      
verify(() => mockDao.insertOrUpdateSetting(any(that: isA<db.AppSettingsCompanion>()))).called(1);
    });

    test('getAllSettings returns map from dao', () async {
      when(() => mockDao.getSettingsAsMap()).thenAnswer((_) async => {'k1': 'v1', 'k2': 'v2'});
      
      final settings = await dataSource.getAllSettings();
      expect(settings, {'k1': 'v1', 'k2': 'v2'});
    });

    test('deleteSetting calls dao', () async {
      when(() => mockDao.deleteSetting('key1')).thenAnswer((_) async => 1);
      
      await dataSource.deleteSetting('key1');
      verify(() => mockDao.deleteSetting('key1')).called(1);
    });

    test('getBusinessProfile returns entity when profile exists', () async {
      final now = DateTime.now();
      when(() => mockDao.getActiveBusinessProfile()).thenAnswer((_) async => 
        db.BusinessProfile(
          id: 'bp1', companyName: 'Test Co', address: '123 St', city: 'City',
          state: 'State', pincode: '12345', phone: '555-1234', email: 'test@co.com',
          gstin: 'GST123', pan: 'PAN123', logoUrl: 'logo.png', isActive: true,
          createdAt: now, updatedAt: now,
        ));
      
      final profile = await dataSource.getBusinessProfile();
      expect(profile, matcher.isNotNull);
      expect(profile!.companyName, 'Test Co');
      expect(profile.id, 'bp1');
    });

    test('getBusinessProfile returns null when no active profile', () async {
      when(() => mockDao.getActiveBusinessProfile()).thenAnswer((_) async => null);
      expect(await dataSource.getBusinessProfile(), matcher.isNull);
    });

    test('saveBusinessProfile calls insertBusinessProfile', () async {
      when(() => mockDao.insertBusinessProfile(any())).thenAnswer((_) async => 1);
      final profile = BusinessProfileEntity(
        id: 'bp1', companyName: 'New Co', createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      
      await dataSource.saveBusinessProfile(profile);
verify(() => mockDao.insertBusinessProfile(any(that: isA<db.BusinessProfilesCompanion>()))).called(1);
    });

    test('getAllBusinessProfiles maps all profiles', () async {
      final now = DateTime.now();
      when(() => mockDao.getAllBusinessProfiles()).thenAnswer((_) async => [
        db.BusinessProfile(
          id: 'bp1', companyName: 'Co1', address: null, city: null, state: null,
          pincode: null, phone: null, email: null, gstin: null, pan: null, 
          logoUrl: null, isActive: true, createdAt: now, updatedAt: now,
        ),
      ]);
      
      final profiles = await dataSource.getAllBusinessProfiles();
      expect(profiles.length, 1);
      expect(profiles[0].companyName, 'Co1');
    });

    test('getSyncSettings returns defaults when no settings stored', () async {
      when(() => mockDao.getSettingValue(any())).thenAnswer((_) async => null);
      
      final settings = await dataSource.getSyncSettings();
      expect(settings.autoSync, true);
      expect(settings.syncOnWifiOnly, false);
      expect(settings.syncFrequencyMinutes, 15);
      expect(settings.conflictResolution, 'server');
      expect(settings.lastSyncedAt, matcher.isNull);
    });

    test('getSyncSettings returns stored values', () async {
      when(() => mockDao.getSettingValue('sync_auto')).thenAnswer((_) async => 'false');
      when(() => mockDao.getSettingValue('sync_wifi_only')).thenAnswer((_) async => 'true');
      when(() => mockDao.getSettingValue('sync_frequency')).thenAnswer((_) async => '30');
      when(() => mockDao.getSettingValue('sync_conflict_resolution')).thenAnswer((_) async => 'local');
      when(() => mockDao.getSettingValue('sync_last_synced')).thenAnswer((_) async => '2024-01-15T10:00:00.000Z');
      
      final settings = await dataSource.getSyncSettings();
      expect(settings.autoSync, false);
      expect(settings.syncOnWifiOnly, true);
      expect(settings.syncFrequencyMinutes, 30);
      expect(settings.conflictResolution, 'local');
      expect(settings.lastSyncedAt, DateTime.parse('2024-01-15T10:00:00.000Z'));
    });

    test('saveSyncSettings calls insertOrUpdateSetting for each key', () async {
      when(() => mockDao.insertOrUpdateSetting(any())).thenAnswer((_) async => 1);
      final settings = SyncSettingsEntity(
        autoSync: false, syncOnWifiOnly: true, syncFrequencyMinutes: 30,
        conflictResolution: 'local', lastSyncedAt: DateTime.parse('2024-01-15T10:00:00.000Z'),
      );
      
      await dataSource.saveSyncSettings(settings);
      verify(() => mockDao.insertOrUpdateSetting(any())).called(5);
    });
  });
}