import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Network connectivity monitoring service.
///
/// Tracks the device's online/offline state using the `connectivity_plus`
/// package. Provides real-time connectivity change notifications and
/// manual connection checks.
///
/// ## Connectivity Types
/// - [ConnectivityResult.wifi] — Connected to WiFi network
/// - [ConnectivityResult.mobile] — Connected to mobile data
/// - [ConnectivityResult.ethernet] — Connected via Ethernet
/// - [ConnectivityResult.bluetooth] — Connected via Bluetooth
/// - [ConnectivityResult.vpn] — Connected via VPN
/// - [ConnectivityResult.other] — Connected via other means
/// - [ConnectivityResult.none] — No network connection
///
/// ## Limitations
/// This service checks device-level connectivity, not internet reachability.
/// A device connected to WiFi without internet access will report as connected.
/// For true internet reachability, an additional HTTP ping check is needed.
///
/// ## Usage
/// ```dart
/// final monitor = NetworkMonitor();
///
/// // Check current status
/// if (await monitor.isConnected) {
///   // Online
/// }
///
/// // Listen for changes
/// monitor.connectivityStream.listen((result) {
///   if (result == ConnectivityResult.none) {
///     showOfflineBanner();
///   } else {
///     hideOfflineBanner();
///   }
/// });
/// ```
class NetworkMonitor {
  final Connectivity _connectivity;

  /// StreamSubscription for connectivity change events.
  StreamSubscription<ConnectivityResult>? _subscription;

  /// Current connectivity state cache.
  ConnectivityResult _currentResult = ConnectivityResult.none;

  /// Stream controller for broadcasting connectivity changes.
  final _controller = StreamController<ConnectivityResult>.broadcast();

  /// Whether the monitor is currently listening for changes.
  bool _isListening = false;

  NetworkMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// Returns the current connectivity result.
  ConnectivityResult get currentResult => _currentResult;

  /// Returns true if the device has any active network connection.
  ///
  /// This is a convenience getter that wraps [checkConnection].
  Future<bool> get isConnected async => await checkConnection();

  /// Stream that emits connectivity change events.
  ///
  /// Listeners receive [ConnectivityResult] values whenever the device's
  /// network connectivity changes (e.g., WiFi ↔ Mobile ↔ None).
  ///
  /// The stream is broadcast, so multiple listeners can subscribe.
  Stream<ConnectivityResult> get connectivityStream => _controller.stream;

  /// Checks the current network connectivity status.
  ///
  /// Returns true if the device has any active network connection.
  /// This performs an actual connectivity check rather than reading cached state.
  Future<bool> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _currentResult = result;
      return result != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Starts listening for connectivity changes.
  ///
  /// Must be called before using [connectivityStream]. The initial
  /// connectivity state is also captured and broadcast.
  ///
  /// If already listening, this method is a no-op.
  void startListening() {
    if (_isListening) return;

    _isListening = true;

    // Capture initial state
    checkConnection().then((_) {
      _controller.add(_currentResult);
    });

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      (result) {
        _currentResult = result;
        _controller.add(result);
      },
      onError: (error) {
        // Connectivity stream error — usually means the plugin was disposed
        _isListening = false;
      },
    );
  }

  /// Stops listening for connectivity changes.
  ///
  /// Resources are released and the stream will no longer emit events.
  /// Call [startListening] to resume monitoring.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
  }

  /// Returns a human-readable string for the connectivity result.
  ///
  /// Useful for displaying the current connection status in the UI.
  String getConnectivityLabel(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Connected';
      case ConnectivityResult.none:
        return 'No Connection';
    }
  }

  /// Returns the appropriate icon for the connectivity result.
  ///
  /// Useful for displaying a status icon in the UI.
  String getConnectivityIcon(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return '📶';
      case ConnectivityResult.mobile:
        return '📱';
      case ConnectivityResult.ethernet:
        return '🔌';
      case ConnectivityResult.bluetooth:
        return '🔵';
      case ConnectivityResult.vpn:
        return '🔒';
      case ConnectivityResult.other:
        return '🌐';
      case ConnectivityResult.none:
        return '📵';
    }
  }

  /// Checks if the current connection is WiFi.
  bool get isWifi => _currentResult == ConnectivityResult.wifi;

  /// Checks if the current connection is mobile data.
  bool get isMobile => _currentResult == ConnectivityResult.mobile;

  /// Checks if the device is offline (no connection).
  bool get isOffline => _currentResult == ConnectivityResult.none;

  /// Disposes resources and stops listening.
  ///
  /// After calling this method, the monitor cannot be reused.
  /// Create a new instance if monitoring is needed again.
  void dispose() {
    stopListening();
    _controller.close();
  }
}
