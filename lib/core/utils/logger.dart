import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Structured logging service for the SS MART ERP application.
///
/// Wraps Dart's built-in [developer.log] with leveled logging, tag-based
/// filtering, and conditional output (debug-only in release builds).
///
/// ## Usage
///
/// ```dart
/// final _log = Logger(tag: 'AuthService');
///
/// void login() {
///   _log.info('Attempting login for user: admin');
///   try {
///     // ...
///     _log.debug('JWT token received');
///   } catch (e) {
///     _log.error('Login failed', error: e);
///   }
/// }
/// ```
///
/// ## Log Levels
///
/// - [debug] — Verbose diagnostic information (stripped in release builds)
/// - [info] — Significant business events (login, bill created, sync done)
/// - [warn] — Recoverable issues (retrying, fallback used)
/// - [error] — Failures requiring attention (exceptions, data corruption)
class Logger {
  /// Tag prepended to all log messages from this instance.
  ///
  /// Typically the class or feature name (e.g., 'BillingBloc', 'SyncService').
  final String tag;

  /// Minimum log level for output. Messages below this level are discarded.
  final LogLevel minLevel;

  const Logger({
    required this.tag,
    this.minLevel = kDebugMode ? LogLevel.debug : LogLevel.info,
  });

  /// Logs a debug-level message. Stripped in release builds.
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, error: error, stackTrace: stackTrace);
  }

  /// Logs an informational message for significant business events.
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, error: error, stackTrace: stackTrace);
  }

  /// Logs a warning for recoverable issues.
  void warn(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warn, message, error: error, stackTrace: stackTrace);
  }

  /// Logs an error for failures requiring attention.
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;

    final prefix = '[${level.name.toUpperCase()}][$tag]';
    final buffer = StringBuffer('$prefix $message');

    if (error != null) {
      buffer.write(' | error: $error');
    }

    // ignore: avoid_print
    if (kDebugMode) {
      developer.log(
        buffer.toString(),
        name: tag,
        level: level.value,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Log severity levels ordered from least to most severe.
enum LogLevel {
  /// Verbose diagnostic info (debug builds only).
  debug(0),

  /// Significant business events.
  info(500),

  /// Recoverable issues.
  warn(800),

  /// Failures requiring attention.
  error(1000);

  final int value;
  const LogLevel(this.value);
}
