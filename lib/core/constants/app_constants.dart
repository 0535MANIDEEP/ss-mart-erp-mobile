/// Centralized application constants for the SS MART ERP mobile app.
///
/// All magic numbers, configuration values, and storage keys are defined
/// here to avoid hardcoding scattered across the codebase. Constants are
/// organized by category for easy discovery and maintenance.
///
/// Note: API URLs and timeouts are configurable per environment (dev/staging/prod)
/// and should be overridden at build time for different deployments.
class AppConstants {
  /// Application display name shown in the splash screen and about dialog.
  static const String appName = 'SS MART';

  /// Current application version string (semver format).
  static const String appVersion = '1.0.0';

  // ─── API Configuration ──────────────────────────────────────────────────
  /// Base URL for the backend API server.
  /// Defaults to localhost for development; overridden for production builds.
  static const String baseUrl = 'http://localhost:5000/api';

  /// Maximum time to wait for a connection to be established (milliseconds).
  static const int connectTimeout = 30000;

  /// Maximum time to wait for a response after connection is established (milliseconds).
  static const int receiveTimeout = 30000;

  // ─── Secure Storage Keys ────────────────────────────────────────────────
  /// Key for the JWT access token used in API authentication headers.
  static const String accessTokenKey = 'access_token';

  /// Key for the refresh token used to obtain new access tokens.
  static const String refreshTokenKey = 'refresh_token';

  /// Key for the authenticated user's unique identifier.
  static const String userIdKey = 'user_id';

  /// Key for the authenticated user's display name.
  static const String userNameKey = 'user_name';

  /// Key for the authenticated user's role (admin/manager/cashier/inventory).
  static const String userRoleKey = 'user_role';

  /// Key for the store/business identifier this device is registered to.
  static const String storeIdKey = 'store_id';

  /// Key for the timestamp of the last successful server sync.
  static const String lastSyncKey = 'last_sync';

  // ─── Sync Configuration ─────────────────────────────────────────────────
  /// Interval in minutes between automatic background sync attempts.
  static const int syncIntervalMinutes = 5;

  /// Maximum number of retry attempts for a single sync item before marking as failed.
  static const int maxRetries = 3;

  /// Number of sync items to process in a single batch upload.
  static const int syncBatchSize = 50;

  // ─── Loyalty Program Configuration ──────────────────────────────────────
  /// Number of loyalty points awarded per rupee spent (1 point = 1 INR).
  static const int loyaltyPointsPerRupee = 1;

  /// Minimum number of points required for a single redemption transaction.
  static const int minRedemptionPoints = 10;

  /// Maximum percentage of bill total that can be paid with loyalty points.
  /// E.g., 50.0 means at most half the bill can be redeemed with points.
  static const double maxRedemptionPercent = 50.0;

  // ─── Pagination Defaults ────────────────────────────────────────────────
  /// Default number of items per page for list queries.
  static const int defaultPageSize = 20;

  /// Maximum allowed page size to prevent excessive data loading.
  static const int maxPageSize = 100;
}
