/// Environment configuration for the SS MART ERP application.
///
/// Supports multiple deployment environments (dev, staging, production)
/// with different API base URLs and feature flags.
///
/// Usage:
/// ```dart
/// final env = Environment.dev;
/// print(env.baseUrl); // http://localhost:5000/api
/// ```
class Environment {
  /// The environment name for logging/debugging.
  final String name;

  /// The base URL for API requests in this environment.
  final String baseUrl;

  /// Whether HTTP request/response logging is enabled.
  final bool enableLogging;

  /// Whether offline sync is enabled in this environment.
  final bool enableSync;

  const Environment({
    required this.name,
    required this.baseUrl,
    this.enableLogging = true,
    this.enableSync = true,
  });

  /// Development environment with local server.
  static const dev = Environment(
    name: 'development',
    baseUrl: 'http://localhost:5000/api',
    enableLogging: true,
    enableSync: true,
  );

  /// Staging environment for pre-production testing.
  static const staging = Environment(
    name: 'staging',
    baseUrl: 'https://staging-api.ssmart.com/api',
    enableLogging: true,
    enableSync: true,
  );

  /// Production environment.
  static const production = Environment(
    name: 'production',
    baseUrl: 'https://api.ssmart.com/api',
    enableLogging: false,
    enableSync: true,
  );

  static Environment _current = dev;

  /// Returns the currently active environment.
  static Environment get current => _current;

  /// Sets the active environment at app startup.
  ///
  /// Should be called once before [runApp] to configure the environment.
  static void setEnvironment(Environment env) {
    _current = env;
  }
}
