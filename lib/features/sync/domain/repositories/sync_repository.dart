import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/sync_queue_entity.dart';

/// Abstract repository contract for offline-to-online data synchronization.
///
/// This interface defines the data access boundary for the sync feature.
/// The sync system implements an offline-first architecture: all local
/// mutations are enqueued as [SyncQueueItem] entries, then uploaded to
/// the server when connectivity is available.
///
/// The sync processor polls pending items, uploads them in FIFO order,
/// and manages retry logic with exponential backoff for failed uploads.
///
/// All methods return [Either<Failure, T>] to enable functional error handling
/// without exceptions, following the Clean Architecture data flow convention.
abstract class SyncRepository {
  /// Enqueues a new sync item for pending upload to the server.
  /// The item will be processed in FIFO order by the background sync worker.
  Future<Either<Failure, void>> addToQueue(SyncQueueItem item);

  /// Retrieves pending sync items for processing, ordered by creation time.
  /// [limit] caps the number of items returned per batch (default: 50).
  Future<Either<Failure, List<SyncQueueItem>>> getPendingItems({int limit = 50});

  /// Updates the processing status of a sync item.
  /// [status] should be 'in_progress', 'completed', or 'failed'.
  /// [error] captures the error message on failure for debugging.
  Future<Either<Failure, void>> updateStatus(String id, String status, {String? error});

  /// Triggers a full sync of all pending items to the server.
  /// Processes items sequentially with retry logic for transient failures.
  Future<Either<Failure, void>> syncPendingItems();

  /// Retrieves the timestamp of the last successful sync operation.
  /// Used by the dashboard to display "last synced X minutes ago".
  Future<Either<Failure, DateTime>> getLastSyncTime();

  /// Persists the timestamp of a successful sync operation.
  Future<Either<Failure, void>> setLastSyncTime(DateTime time);

  /// Resolves a sync conflict for [itemId] using Last Write Wins (LWW) strategy.
  /// If [useLocal] is true, the local version wins; otherwise the remote version wins.
  Future<Either<Failure, void>> resolveConflict(String itemId, {bool useLocal = true});

  /// Retries all failed sync items with exponential backoff.
  /// Processes items in batches with increasing delays between attempts.
  Future<Either<Failure, void>> retryFailedItems();

  /// Returns sync items that are in 'conflict' status and need manual resolution.
  Future<Either<Failure, List<SyncQueueItem>>> getConflictItems();
}
