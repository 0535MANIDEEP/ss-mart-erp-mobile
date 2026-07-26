/// Auth Local Data Source — Local persistence layer for authentication state.
///
/// ## Architecture Role
/// This datasource sits between the [AuthRepositoryImpl] and the database (Drift DAO).
/// It abstracts all local storage details for auth tokens and user profile data,
/// so the repository layer never interacts with the database directly.
///
/// ## Responsibilities
/// - Persists and retrieves JWT access/refresh tokens via the [AuthSessions] table.
/// - Persists and retrieves the currently authenticated user's profile via [UserProfiles].
/// - Enforces a single-active-session model: saving new tokens deactivates all prior sessions.
///
/// ## Data Flow
/// ```
/// Repository → AuthLocalDataSource → DatabaseDao (Drift) → SQLite
/// ```
///
/// ## Design Decisions
/// - Uses a hardcoded userId of `'current_user'` because this is an offline-first mobile app
///   that supports only a single logged-in user at a time (multi-user is handled server-side).
/// - Token expiry is set to 24 hours from creation; the actual validation is delegated to
///   the API layer — this is a local fallback for offline session management.
/// - User data is stored as a [Map<String, dynamic>] to remain decoupled from any particular
///   domain model, keeping this layer transport-agnostic.
library;

import 'package:uuid/uuid.dart';
import '../../../../database/app_database.dart' as db;
import '../../../../database/database_dao.dart';

/// Abstract contract for local auth persistence.
///
/// Provides a clean interface for token and user-profile CRUD operations.
/// The repository depends only on this abstraction, not on the concrete
/// [AuthLocalDataSourceImpl], enabling easy testing with a mock/stub.
abstract class AuthLocalDataSource {
  /// Stores a new token pair, deactivating any previously stored sessions.
  Future<void> saveTokens({required String accessToken, required String refreshToken});

  /// Returns the current active access token, or `null` if no session exists.
  Future<String?> getAccessToken();

  /// Returns the current active refresh token, or `null` if no session exists.
  Future<String?> getRefreshToken();

  /// Invalidates all stored sessions (effectively logs the user out locally).
  Future<void> clearTokens();

  /// Persists the authenticated user's profile data.
  ///
  /// The [user] map is expected to contain keys: `id`, `name`, `email`, `phone`,
  /// `role`, `avatarUrl`, `metadata`. Missing keys fall back to sensible defaults.
  Future<void> saveUser(Map<String, dynamic> user);

  /// Returns the stored user profile as a map, or `null` if no profile exists.
  Future<Map<String, dynamic>?> getUser();

  /// Removes all stored user profiles (used during logout).
  Future<void> clearUser();
}

/// Concrete implementation backed by Drift's [DatabaseDao].
///
/// Each method maps between the unstructured [Map] representation used by the
/// repository layer and the strongly-typed Drift companion objects used for DB writes.
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final DatabaseDao _dao;
  final _uuid = const Uuid();

  AuthLocalDataSourceImpl({required DatabaseDao dao}) : _dao = dao;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    // Step 1: Invalidate every existing session so only one is active at a time.
    // This is a deliberate design choice — the mobile app is single-user,
    // and stale sessions could cause token confusion.
    await _dao.deactivateAllSessions();

    // Step 2: Insert the fresh session with a 24-hour TTL.
    // The UUID is generated client-side to guarantee uniqueness without
    // relying on database auto-increment, which is safer for offline-first sync.
    final sessionId = _uuid.v4();
    await _dao.insertAuthSession(
      db.AuthSessionsCompanion.insert(
        id: sessionId,
        userId: 'current_user',
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<String?> getAccessToken() async {
    final session = await _dao.getActiveSession();
    return session?.accessToken;
  }

  @override
  Future<String?> getRefreshToken() async {
    final session = await _dao.getActiveSession();
    return session?.refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    // DeactivateAllSessions is sufficient — we don't hard-delete rows
    // because they serve as an audit trail of past sessions.
    await _dao.deactivateAllSessions();
  }

  @override
  Future<void> saveUser(Map<String, dynamic> user) async {
    // Fall back to 'current_user' if the server didn't provide an explicit ID.
    final userId = user['id'] as String? ?? 'current_user';
    await _dao.insertUserProfile(
      db.UserProfilesCompanion.insert(
        id: userId,
        name: user['name'] as String? ?? '',
        email: db.Value(user['email'] as String?),
        phone: db.Value(user['phone'] as String?),
        // Default role is 'cashier' — the least-privileged role — to fail safely.
        role: db.Value(user['role'] as String? ?? 'cashier'),
        avatarUrl: db.Value(user['avatarUrl'] as String?),
        // Free-form metadata blob for extensibility (e.g., preferences, permissions).
        jsonMetadata: db.Value(user['metadata'] as String? ?? '{}'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Map<String, dynamic>?> getUser() async {
    final profiles = await _dao.getAllUserProfiles();
    if (profiles.isEmpty) return null;

    // In a single-user app, the first profile is the current user.
    final profile = profiles.first;
    return {
      'id': profile.id,
      'name': profile.name,
      'email': profile.email,
      'phone': profile.phone,
      'role': profile.role,
      'avatarUrl': profile.avatarUrl,
      'metadata': profile.jsonMetadata,
    };
  }

  @override
  Future<void> clearUser() async {
    // Delete all profiles as a defensive measure — in a single-user app this
    // should only remove one row, but handling multiples avoids silent data leaks.
    final profiles = await _dao.getAllUserProfiles();
    for (final profile in profiles) {
      await _dao.deleteUserProfile(profile.id);
    }
  }
}
