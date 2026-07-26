import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:ss_mart/database/app_database.dart' as db;
import 'package:ss_mart/database/database_dao.dart';
import 'package:ss_mart/features/auth/data/datasources/auth_local_datasource.dart';

class MockDatabaseDao extends Mock implements DatabaseDao {}

void main() {
  setUpAll(() {
    registerFallbackValue(db.AuthSessionsCompanion(
      id: Value(''), userId: Value(''), accessToken: Value(''),
      refreshToken: Value(''), expiresAt: Value(DateTime.now()),
      createdAt: Value(DateTime.now()),
    ));
    registerFallbackValue(db.UserProfilesCompanion(
      id: Value(''), name: Value(''),
      createdAt: Value(DateTime.now()), updatedAt: Value(DateTime.now()),
    ));
  });

  group('AuthLocalDataSourceImpl', () {
    late MockDatabaseDao mockDao;
    late AuthLocalDataSourceImpl dataSource;

    setUp(() {
      mockDao = MockDatabaseDao();
      dataSource = AuthLocalDataSourceImpl(dao: mockDao);
    });

    test('saveTokens calls deactivateAllSessions then insertAuthSession', () async {
      when(() => mockDao.deactivateAllSessions()).thenAnswer((_) async => 0);
      when(() => mockDao.insertAuthSession(any())).thenAnswer((_) async => 1);

      await dataSource.saveTokens(
        accessToken: 'at-123',
        refreshToken: 'rt-123',
      );

verify(() => mockDao.deactivateAllSessions()).called(1);
    verify(() => mockDao.insertAuthSession(any(that: isA<db.AuthSessionsCompanion>()))).called(1);
    });

    test('getAccessToken returns token from active session', () async {
      final session = db.AuthSession(
        id: 's1', userId: 'u1', accessToken: 'at-123', 
        refreshToken: 'rt-123', expiresAt: DateTime.now().add(const Duration(hours: 1)),
        deviceId: null, status: 'active', createdAt: DateTime.now(),
      );
      when(() => mockDao.getActiveSession()).thenAnswer((_) async => session);
      
      final token = await dataSource.getAccessToken();
      expect(token, 'at-123');
    });

    test('getAccessToken returns null when no active session', () async {
      when(() => mockDao.getActiveSession()).thenAnswer((_) async => null);
      
      final token = await dataSource.getAccessToken();
      expect(token, isNull);
    });

    test('getRefreshToken returns token from active session', () async {
      final session = db.AuthSession(
        id: 's1', userId: 'u1', accessToken: 'at-123', 
        refreshToken: 'rt-123', expiresAt: DateTime.now().add(const Duration(hours: 1)),
        deviceId: null, status: 'active', createdAt: DateTime.now(),
      );
      when(() => mockDao.getActiveSession()).thenAnswer((_) async => session);
      
      final token = await dataSource.getRefreshToken();
      expect(token, 'rt-123');
    });

    test('clearTokens calls deactivateAllSessions', () async {
      when(() => mockDao.deactivateAllSessions()).thenAnswer((_) async => 0);
      
      await dataSource.clearTokens();
      verify(() => mockDao.deactivateAllSessions()).called(1);
    });

    test('saveUser inserts user profile', () async {
      when(() => mockDao.insertUserProfile(any())).thenAnswer((_) async => 1);
      
      await dataSource.saveUser({
        'id': 'u1', 'name': 'Test User', 'email': 'test@example.com',
        'phone': '9876543210', 'role': 'cashier', 'avatarUrl': 'url', 'metadata': '{}',
      });
      
verify(() => mockDao.insertUserProfile(any(that: isA<db.UserProfilesCompanion>()))).called(1);
    });

    test('getUser returns first profile as map', () async {
      final profile = db.UserProfile(
        id: 'u1', name: 'Test User', email: 'test@example.com',
        phone: '9876543210', role: 'cashier', avatarUrl: 'url', 
        jsonMetadata: '{}', createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      when(() => mockDao.getAllUserProfiles()).thenAnswer((_) async => [profile]);
      
      final user = await dataSource.getUser();
      expect(user, isNotNull);
      expect(user!['id'], 'u1');
      expect(user['name'], 'Test User');
    });

    test('getUser returns null when no profiles', () async {
      when(() => mockDao.getAllUserProfiles()).thenAnswer((_) async => []);
      
      final user = await dataSource.getUser();
      expect(user, isNull);
    });

    test('clearUser deletes all profiles', () async {
      final profile = db.UserProfile(
        id: 'u1', name: 'Test', email: null, phone: null, 
        role: 'cashier', avatarUrl: null, jsonMetadata: '{}', 
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      when(() => mockDao.getAllUserProfiles()).thenAnswer((_) async => [profile]);
      when(() => mockDao.deleteUserProfile('u1')).thenAnswer((_) async => 1);
      
      await dataSource.clearUser();
      verify(() => mockDao.deleteUserProfile('u1')).called(1);
    });
  });
}