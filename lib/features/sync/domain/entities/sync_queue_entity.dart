import 'package:equatable/equatable.dart';

/// Domain entity representing a single item in the offline-to-online sync queue.
///
/// SyncQueueItem tracks local changes that need to be uploaded to the server
/// when connectivity is available. Each local create, update, or delete
/// operation is enqueued as a separate item with a serialized [payload].
///
/// The sync processor polls pending items, attempts upload, and marks them
/// as 'completed' or 'failed'. Failed items are retried up to [maxRetries]
/// times with exponential backoff before being permanently failed.
///
/// The [payload] field contains the full JSON-serialized entity data,
/// enabling replay of the operation on the server regardless of the
/// current local state (idempotent sync design).
class SyncQueueItem extends Equatable {
  /// Unique identifier for this sync queue entry (UUID format).
  final String id;

  /// Type of entity being synced (e.g., 'product', 'bill', 'customer', 'stock').
  final String entityType;

  /// ID of the local entity this sync item represents.
  final String entityId;

  /// Operation type: 'create', 'update', or 'delete'.
  final String operation;

  /// JSON-serialized payload containing the full entity data to sync.
  final String payload;

  /// Current processing status: 'pending', 'in_progress', 'completed', or 'failed'.
  final String status;

  /// Number of sync attempts that have been made for this item.
  final int retryCount;

  /// Maximum number of retry attempts before marking as permanently failed.
  final int maxRetries;

  /// Timestamp when this item was first enqueued.
  final DateTime createdAt;

  /// Timestamp of the most recent sync attempt. Null if never attempted.
  final DateTime? lastAttemptAt;

  /// Timestamp when the sync completed successfully. Null if not yet synced.
  final DateTime? completedAt;

  /// Error message from the last failed sync attempt. Null if no error occurred.
  final String? error;

  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.status = 'pending',
    this.retryCount = 0,
    this.maxRetries = 3,
    required this.createdAt,
    this.lastAttemptAt,
    this.completedAt,
    this.error,
  });

  /// Returns true if this item is waiting to be processed.
  bool get isPending => status == 'pending';

  /// Returns true if this item is currently being uploaded to the server.
  bool get isInProgress => status == 'in_progress';

  /// Returns true if the sync operation completed successfully.
  bool get isCompleted => status == 'completed';

  /// Returns true if the sync failed and retries are exhausted.
  bool get isFailed => status == 'failed';

  /// Returns true if there are remaining retry attempts available.
  bool get canRetry => retryCount < maxRetries;

  @override
  List<Object?> get props => [
        id, entityType, entityId, operation, payload,
        status, retryCount, maxRetries, createdAt,
        lastAttemptAt, completedAt, error,
      ];

  SyncQueueItem copyWith({
    String? id,
    String? entityType,
    String? entityId,
    String? operation,
    String? payload,
    String? status,
    int? retryCount,
    int? maxRetries,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    DateTime? completedAt,
    String? error,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      completedAt: completedAt ?? this.completedAt,
      error: error ?? this.error,
    );
  }
}
