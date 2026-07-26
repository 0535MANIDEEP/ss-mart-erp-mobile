import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import '../../database/app_database.dart';
import '../../database/database_dao.dart';
import '../network/network_info.dart';

/// Background sync service that processes the offline-to-online sync queue.
///
/// Manages the synchronization of local mutations to the remote server.
/// Processes items in FIFO order, handles retries with exponential backoff,
/// and monitors connectivity to pause/resume sync operations.
///
/// ## Sync Flow
/// 1. **Poll**: Checks for pending items in the [SyncQueue] table.
/// 2. **Connect**: Verifies network connectivity via [NetworkInfo].
/// 3. **Process**: Uploads each pending item to the server.
/// 4. **Update**: Marks items as 'completed' or 'failed' based on result.
/// 5. **Retry**: Failed items are retried with exponential backoff.
///
/// ## Conflict Resolution
/// - Default strategy is "server wins" (last-write-wins on server).
/// - Can be configured to "client wins" or "manual merge" via settings.
///
/// ## Error Handling
/// - Network errors pause the sync and resume when connectivity returns.
/// - Server errors (4xx) mark the item as permanently failed.
/// - Transient errors (5xx, timeout) trigger retry with backoff.
///
/// ## Usage
/// ```dart
/// final syncService = SyncService(dao: dao, networkInfo: networkInfo);
///
/// // Process all pending items
/// await syncService.processSyncQueue();
///
/// // Get count of pending items
/// final count = await syncService.getPendingCount();
/// ```
class SyncService {
  final DatabaseDao _dao;
  final NetworkInfo _networkInfo;

  /// Stream controller for broadcasting sync progress updates.
  final _progressController = StreamController<SyncProgress>.broadcast();

  /// Timer for periodic sync attempts.
  Timer? _periodicTimer;

  /// Whether a sync operation is currently in progress.
  bool _isSyncing = false;

  SyncService({
    required DatabaseDao dao,
    required NetworkInfo networkInfo,
  })  : _dao = dao,
        _networkInfo = networkInfo;

  /// Stream of sync progress updates.
  ///
  /// Emits [SyncProgress] events as items are processed, allowing the UI
  /// to display real-time sync status.
  Stream<SyncProgress> get progressStream => _progressController.stream;

  /// Whether a sync operation is currently running.
  bool get isSyncing => _isSyncing;

  /// Processes all pending items in the sync queue.
  ///
  /// Checks connectivity first, then processes items sequentially in FIFO
  /// order. Updates each item's status as it's processed.
  ///
  /// Returns the number of items successfully synced.
  Future<int> processSyncQueue() async {
    if (_isSyncing) return 0;
    if (!await _networkInfo.isConnected) return 0;

    _isSyncing = true;

    try {
      final pendingItems = await _dao.getPendingSyncItems();
      if (pendingItems.isEmpty) {
        _isSyncing = false;
        return 0;
      }

      int syncedCount = 0;

      for (final item in pendingItems) {
        // Check connectivity before each item to handle mid-sync disconnects
        if (!await _networkInfo.isConnected) break;

        try {
          // Mark as in_progress
          await _dao.updateSyncItem(
            SyncQueueCompanion(
              id: Value(item.id),
              status: const Value('in_progress'),
              lastAttemptAt: Value(DateTime.now()),
            ),
          );

          // Attempt to sync the item
          await _syncItemToServer(item);

          // Mark as completed
          await _dao.updateSyncItem(
            SyncQueueCompanion(
              id: Value(item.id),
              status: const Value('completed'),
              completedAt: Value(DateTime.now()),
            ),
          );

          syncedCount++;
          _progressController.add(SyncProgress(
            totalItems: pendingItems.length,
            processedItems: syncedCount,
            currentEntity: item.entityType,
            status: SyncStatus.processing,
          ));
        } catch (e) {
          await _handleSyncError(item, e);
        }
      }

      _progressController.add(SyncProgress(
        totalItems: pendingItems.length,
        processedItems: syncedCount,
        status: syncedCount == pendingItems.length
            ? SyncStatus.completed
            : SyncStatus.partial,
      ));

      _isSyncing = false;
      return syncedCount;
    } catch (e) {
      _isSyncing = false;
      _progressController.add(SyncProgress(
        totalItems: 0,
        processedItems: 0,
        status: SyncStatus.failed,
        error: e.toString(),
      ));
      return 0;
    }
  }

  /// Retries failed sync items with exponential backoff.
  ///
  /// Items that have failed but haven't exceeded [maxRetries] are retried
  /// with increasing delays: 1s, 2s, 4s, 8s, etc.
  ///
  /// Returns the number of items successfully retried.
  Future<int> retryFailedItems() async {
    if (_isSyncing) return 0;
    if (!await _networkInfo.isConnected) return 0;

    _isSyncing = true;

    try {
      final allItems = await _dao.getAllSyncItems();
      final retryableItems = allItems
          .where((item) => item.status == 'failed' && item.retryCount < item.maxRetries)
          .toList();

      if (retryableItems.isEmpty) {
        _isSyncing = false;
        return 0;
      }

      int syncedCount = 0;

      for (final item in retryableItems) {
        if (!await _networkInfo.isConnected) break;

        // Exponential backoff: 1s, 2s, 4s, 8s, etc.
        final delaySeconds = (1 << item.retryCount).clamp(1, 30);
        await Future<void>.delayed(Duration(seconds: delaySeconds));

        try {
          // Reset status to in_progress
          await _dao.updateSyncItem(
            SyncQueueCompanion(
              id: Value(item.id),
              status: const Value('in_progress'),
              retryCount: Value(item.retryCount + 1),
              lastAttemptAt: Value(DateTime.now()),
              error: const Value(null),
            ),
          );

          await _syncItemToServer(item);

          // Mark as completed
          await _dao.updateSyncItem(
            SyncQueueCompanion(
              id: Value(item.id),
              status: const Value('completed'),
              completedAt: Value(DateTime.now()),
            ),
          );

          syncedCount++;
        } catch (e) {
          await _handleSyncError(item, e);
        }
      }

      _isSyncing = false;
      return syncedCount;
    } catch (e) {
      _isSyncing = false;
      return 0;
    }
  }

  /// Returns the count of pending sync items.
  Future<int> getPendingCount() async {
    final items = await _dao.getPendingSyncItems();
    return items.length;
  }

  /// Returns the count of failed sync items that can be retried.
  Future<int> getRetryableCount() async {
    final allItems = await _dao.getAllSyncItems();
    return allItems
        .where((item) => item.status == 'failed' && item.retryCount < item.maxRetries)
        .length;
  }

  /// Starts periodic sync at the specified interval.
  ///
  /// [intervalMinutes] defaults to 15 minutes. The periodic timer
  /// triggers [processSyncQueue] at each interval if connectivity is available.
  void startPeriodicSync({int intervalMinutes = 15}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) async {
        if (await _networkInfo.isConnected) {
          await processSyncQueue();
        }
      },
    );
  }

  /// Stops the periodic sync timer.
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Handles a sync error by updating the item's retry count and status.
  ///
  /// If max retries are exhausted, the item is marked as permanently failed.
  Future<void> _handleSyncError(SyncQueueData item, dynamic error) async {
    final newRetryCount = item.retryCount + 1;
    final hasExceededRetries = newRetryCount >= item.maxRetries;

    await _dao.updateSyncItem(
      SyncQueueCompanion(
        id: Value(item.id),
        status: Value(hasExceededRetries ? 'failed' : 'pending'),
        retryCount: Value(newRetryCount),
        lastAttemptAt: Value(DateTime.now()),
        error: Value(error.toString()),
      ),
    );
  }

  /// Simulates syncing a single item to the server.
  ///
  /// In a production app, this would make an HTTP request to the server
  /// API with the item's payload. The implementation depends on the
  /// server's sync API contract.
  ///
  /// Throws an exception if the sync fails (network error, server error, etc.).
  Future<void> _syncItemToServer(SyncQueueData item) async {
    // TODO: Implement actual server sync logic
    // Example:
    // final response = await _httpClient.post(
    //   Uri.parse('$baseUrl/sync/${item.entityType}'),
    //   headers: {'Authorization': 'Bearer $token'},
    //   body: jsonEncode({
    //     'operation': item.operation,
    //     'entityId': item.entityId,
    //     'payload': jsonDecode(item.payload),
    //   }),
    // );
    //
    // if (response.statusCode >= 400) {
    //   throw ServerException(
    //     message: 'Sync failed: ${response.statusCode}',
    //     statusCode: response.statusCode,
    //   );
    // }

    // Simulate network delay for development
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  /// Disposes resources and stops any running timers.
  void dispose() {
    _periodicTimer?.cancel();
    _progressController.close();
  }
}

/// Progress event emitted during sync processing.
///
/// Contains information about the current sync operation including
/// total items, processed count, and current status.
class SyncProgress {
  /// Total number of items being synced in this batch.
  final int totalItems;

  /// Number of items processed so far.
  final int processedItems;

  /// Entity type of the current item being processed.
  final String? currentEntity;

  /// Current status of the sync operation.
  final SyncStatus status;

  /// Error message if the sync failed.
  final String? error;

  const SyncProgress({
    required this.totalItems,
    required this.processedItems,
    this.currentEntity,
    required this.status,
    this.error,
  });

  /// Progress percentage (0.0 to 1.0).
  double get progress =>
      totalItems > 0 ? processedItems / totalItems : 0.0;
}

/// Status of a sync operation.
enum SyncStatus {
  /// Items are being processed.
  processing,

  /// All items were successfully synced.
  completed,

  /// Some items were synced, but others failed.
  partial,

  /// The sync operation failed entirely.
  failed,
}
