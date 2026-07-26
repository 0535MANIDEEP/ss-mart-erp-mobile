import 'package:connectivity_plus/connectivity_plus.dart';

/// Abstract interface for checking network connectivity status.
///
/// This abstraction decouples the business logic from the specific connectivity
/// implementation, enabling testability (mock in unit tests) and flexibility
/// (swap implementations without changing dependent code).
///
/// Used by repository implementations to decide between local-only reads
/// and remote-synced operations.
abstract class NetworkInfo {
  /// Returns true if the device currently has an active network connection.
  Future<bool> get isConnected;

  /// Stream that emits connectivity change events (WiFi ↔ Mobile ↔ None).
  /// Used by the sync service to trigger automatic sync on reconnect.
  Stream<ConnectivityResult> get onConnectivityChanged;
}

/// Concrete implementation of [NetworkInfo] using the `connectivity_plus` package.
///
/// Checks device-level connectivity (WiFi, mobile data, ethernet).
/// Note: this does not guarantee internet reachability — a device connected
/// to WiFi without internet access will still report [isConnected] = true.
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;

  NetworkInfoImpl({required this.connectivity});

  @override
  Future<bool> get isConnected async {
    final result = await connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  @override
  Stream<ConnectivityResult> get onConnectivityChanged =>
      connectivity.onConnectivityChanged;
}
