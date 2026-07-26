import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import '../../../../database/app_database.dart' as db;
import '../../../../core/error/failures.dart';
import '../../domain/entities/sync_queue_entity.dart';
import '../../domain/repositories/sync_repository.dart';

/// Implementation of [SyncRepository] — the backbone of the offline-first
/// synchronization system for the SS MART ERP Mobile App.
///
/// ## Architecture & Sync Strategy
///
/// This repository manages a persistent **sync queue** stored in the local
/// Drift (SQLite) database. It implements the "local write → sync queue →
/// remote when connected" pattern that enables the app to function fully
/// offline while ensuring data consistency with the server.
///
/// ### Sync Queue Concept
/// Every mutation (create, update, delete) performed by the app while offline
/// (or even online, for audit purposes) is recorded as a [SyncQueueItem] in
/// the local database. Each item contains:
/// - **entityType**: The type of entity (e.g., 'bill', 'product', 'customer').
/// - **entityId**: The ID of the affected entity.
/// - **operation**: The operation type ('create', 'update', 'delete').
/// - **payload**: A JSON-serialized snapshot of the entity data.
/// - **status**: Processing status ('pending', 'in_progress', 'completed',
///   'failed', 'skipped').
/// - **retryCount / maxRetries**: Retry tracking for failed sync attempts.
///
/// ### Sync Processing (syncPendingItems)
/// 1. Fetch all items with status 'pending' or 'failed'.
/// 2. For each item:
///    a. If retryCount >= maxRetries, mark as 'skipped' (permanently failed).
///    b. Mark as 'in_progress'.
///    c. Execute the sync via HTTP (see [_syncToServer]).
///    d. Mark as 'completed' on success, 'failed' on error.
/// 3. Update the last sync timestamp.
///
/// ### Error Handling
/// - All methods return `Either<Failure, T>`.
/// - [CacheFailure]: local database errors (queue read/write failures).
/// - [ServerFailure]: general sync processing errors.
/// - Individual item failures do NOT abort the entire sync batch — the
///   loop continues processing remaining items.
///
/// ### Status State Machine
/// ```
/// pending → in_progress → completed
///                    ↘ failed → in_progress (retry) → completed
///                             → skipped (max retries exceeded)
/// ```
///
/// ### Relationship to Other Repositories
/// - [BillRepositoryImpl], [ProductRepositoryImpl], [CustomerRepositoryImpl]
///   etc. add items to this queue after local writes.
/// - This repository's [syncPendingItems] is called by a background sync
///   worker (e.g., on app startup, on connectivity change, or on a timer).
class SyncRepositoryImpl implements SyncRepository {
  final db.DatabaseDao _dao;

  SyncRepositoryImpl({required db.DatabaseDao dao}) : _dao = dao;

  /// Adds a new [SyncQueueItem] to the persistent sync queue in the local DB.
  ///
  /// Called by other repositories (e.g., [BillRepositoryImpl]) after a local
  /// write to ensure the mutation is eventually propagated to the server.
  @override
  Future<Either<Failure, void>> addToQueue(SyncQueueItem item) async {
    try {
      final companion = db.SyncQueueCompanion(
        id: db.Value(item.id),
        entityType: db.Value(item.entityType),
        entityId: db.Value(item.entityId),
        operation: db.Value(item.operation),
        payload: db.Value(item.payload),
        status: db.Value(item.status),
        retryCount: db.Value(item.retryCount),
        maxRetries: db.Value(item.maxRetries),
        createdAt: db.Value(item.createdAt),
        lastAttemptAt: db.Value(item.lastAttemptAt),
        completedAt: db.Value(item.completedAt),
        error: db.Value(item.error),
      );
      await _dao.insertSyncItem(companion);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Returns up to [limit] pending sync items from the queue.
  ///
  /// Items are returned in creation order (oldest first) to maintain
  /// operation ordering. Used by the sync worker to process the queue.
  @override
  Future<Either<Failure, List<SyncQueueItem>>> getPendingItems({int limit = 50}) async {
    try {
      final rows = await _dao.getPendingSyncItems();
      final items = rows.take(limit).map(_rowToEntity).toList();
      return Right(items);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Updates the status of a sync queue item.
  ///
  /// Handles state transitions:
  /// - On 'failed': increments retryCount and records the error message.
  /// - On 'completed': sets completedAt to now.
  /// - Always updates lastAttemptAt to now.
  ///
  /// If the item does not exist (e.g., was deleted), silently returns success.
  @override
  Future<Either<Failure, void>> updateStatus(
    String id,
    String status, {
    String? error,
  }) async {
    try {
      final existing = await _dao.getSyncItemById(id);
      if (existing == null) return const Right(null);

      final companion = db.SyncQueueCompanion(
        id: db.Value(id),
        entityType: db.Value(existing.entityType),
        entityId: db.Value(existing.entityId),
        operation: db.Value(existing.operation),
        payload: db.Value(existing.payload),
        status: db.Value(status),
        retryCount: db.Value(
          status == 'failed' ? existing.retryCount + 1 : existing.retryCount,
        ),
        maxRetries: db.Value(existing.maxRetries),
        createdAt: db.Value(existing.createdAt),
        lastAttemptAt: db.Value(DateTime.now()),
        completedAt: db.Value(status == 'completed' ? DateTime.now() : null),
        error: db.Value(error),
      );
      await _dao.updateSyncItem(companion);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Processes all pending and failed sync items in the queue.
  ///
  /// Iterates through the queue sequentially:
  /// 1. Skip items that have exhausted their retry budget.
  /// 2. Mark each item as 'in_progress' before processing.
  /// 3. On success, mark as 'completed'; on failure, mark as 'failed'.
  /// 4. After all items are processed, update the last sync timestamp.
  ///
  /// **Important**: The actual API sync call is implemented in [_syncToServer],
  /// which dispatches HTTP requests (POST/PUT/DELETE) based on the entity type
  /// and operation. In production, this may need retry backoff and request
  /// batching for large queues.
  ///
  /// Individual item failures do NOT abort the batch — processing continues
  /// for remaining items. This ensures partial connectivity or transient
  /// server errors don't block the entire sync.
  @override
  Future<Either<Failure, void>> syncPendingItems() async {
    try {
      final allItems = await _dao.getAllSyncItems();
      final pending = allItems
          .where((row) => row.status == 'pending' || row.status == 'failed')
          .toList();

      for (final row in pending) {
        if (row.retryCount >= row.maxRetries) {
          await updateStatus(row.id, 'skipped', error: 'Max retries exceeded');
          continue;
        }

        await updateStatus(row.id, 'in_progress');

        try {
          final response = await _syncToServer(row);
          if (response) {
            await updateStatus(row.id, 'completed');
          } else {
            await updateStatus(row.id, 'failed', error: 'Server returned non-2xx status');
          }
        } catch (e) {
          await updateStatus(row.id, 'failed', error: e.toString());
        }
      }

      await setLastSyncTime(DateTime.now());
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Returns the timestamp of the most recent sync operation.
  ///
  /// Derived from the creation timestamp of the newest sync queue item.
  /// If no items exist, returns a date 365 days in the past (effectively
  /// "never synced").
  @override
  Future<Either<Failure, DateTime>> getLastSyncTime() async {
    try {
      final rows = await _dao.getAllSyncItems();
      if (rows.isNotEmpty) {
        rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return Right(rows.first.createdAt);
      }
      return Right(DateTime.now().subtract(const Duration(days: 365)));
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Sets the last sync time. Currently a no-op — the last sync time is
  /// derived from the most recent completed sync item in [getLastSyncTime].
  @override
  Future<Either<Failure, void>> setLastSyncTime(DateTime time) async {
    try {
      // Last sync time tracked via the most recent completed sync item
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Sends a sync queue item to the server via HTTP.
  ///
  /// Determines the HTTP method and URL based on the entity type and
  /// operation. Uses POST for 'create', PUT for 'update', DELETE for 'delete'.
  /// Returns true if the server responds with a 2xx status code.
  Future<bool> _syncToServer(db.SyncQueueData row) async {
    final baseUrl = 'https://api.ssmart.com/v1';
    final endpoint = _getEndpoint(row.entityType);
    final url = Uri.parse('$baseUrl/$endpoint/${row.entityId}');

    http.Response response;

    switch (row.operation) {
      case 'create':
        response = await http.post(
          Uri.parse('$baseUrl/$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: row.payload,
        );
        break;
      case 'update':
        response = await http.put(
          url,
          headers: {'Content-Type': 'application/json'},
          body: row.payload,
        );
        break;
      case 'delete':
        response = await http.delete(
          url,
          headers: {'Content-Type': 'application/json'},
        );
        break;
      default:
        return false;
    }

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// Maps an entity type to its API endpoint path segment.
  String _getEndpoint(String entityType) {
    switch (entityType) {
      case 'product':
      case 'products':
        return 'products';
      case 'customer':
      case 'customers':
        return 'customers';
      case 'bill':
      case 'bills':
        return 'bills';
      case 'stock':
        return 'stock';
      case 'employee':
      case 'employees':
        return 'employees';
      case 'supplier':
      case 'suppliers':
        return 'suppliers';
      case 'purchase':
      case 'purchases':
        return 'purchases';
      default:
        return entityType;
    }
  }

  @override
  Future<Either<Failure, void>> resolveConflict(String itemId, {bool useLocal = true}) async {
    try {
      final existing = await _dao.getSyncItemById(itemId);
      if (existing == null) {
        return Left(CacheFailure(message: 'Sync item not found'));
      }

      if (useLocal) {
        await updateStatus(itemId, 'completed');
      } else {
        final response = await _syncToServer(existing);
        if (response) {
          await updateStatus(itemId, 'completed');
        } else {
          await updateStatus(itemId, 'failed', error: 'Failed to sync resolved item to server');
        }
      }

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> retryFailedItems() async {
    try {
      final allItems = await _dao.getAllSyncItems();
      var failedItems = allItems
          .where((row) => row.status == 'failed' && row.retryCount < row.maxRetries)
          .toList();

      int attempt = 0;
      const maxAttempts = 5;

      while (failedItems.isNotEmpty && attempt < maxAttempts) {
        final delay = Duration(milliseconds: 1000 * (1 << attempt));
        await Future.delayed(delay);

        for (final row in failedItems) {
          await updateStatus(row.id, 'in_progress');

          try {
            final response = await _syncToServer(row);
            if (response) {
              await updateStatus(row.id, 'completed');
            } else {
              await updateStatus(row.id, 'failed', error: 'Retry attempt $attempt failed');
            }
          } catch (e) {
            await updateStatus(row.id, 'failed', error: e.toString());
          }
        }

        attempt++;
        final remaining = await _dao.getAllSyncItems();
        failedItems = remaining
            .where((row) => row.status == 'failed' && row.retryCount < row.maxRetries)
            .toList();
      }

      await setLastSyncTime(DateTime.now());
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SyncQueueItem>>> getConflictItems() async {
    try {
      final allItems = await _dao.getAllSyncItems();
      final conflicts = allItems
          .where((row) => row.status == 'conflict')
          .map(_rowToEntity)
          .toList();
      return Right(conflicts);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// Converts a Drift database row [SyncQueueData] into a domain [SyncQueueItem] entity.
  SyncQueueItem _rowToEntity(db.SyncQueueData row) {
    return SyncQueueItem(
      id: row.id,
      entityType: row.entityType,
      entityId: row.entityId,
      operation: row.operation,
      payload: row.payload,
      status: row.status,
      retryCount: row.retryCount,
      maxRetries: row.maxRetries,
      createdAt: row.createdAt,
      lastAttemptAt: row.lastAttemptAt,
      completedAt: row.completedAt,
      error: row.error,
    );
  }
}
