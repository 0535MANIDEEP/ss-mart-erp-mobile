import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/environment.dart';
import '../../../../core/error/failures.dart';
import '../../../../database/app_database.dart' as db;
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
  ///
  /// Uses [Environment.current.baseUrl] to resolve the correct API host
  /// for the active deployment environment (dev/staging/production).
  /// Attaches the JWT access token from the active auth session when available.
  Future<bool> _syncToServer(db.SyncQueueData row) async {
    final baseUrl = Environment.current.baseUrl;
    final endpoint = _getEndpoint(row.entityType);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Attach JWT access token from the active session if one exists.
    // Sync may run before login (e.g., queued offline items) — in that
    // case the header is simply omitted and the backend will accept it
    // if the endpoint has [AllowAnonymous].
    try {
      final session = await _dao.getActiveSession();
      if (session?.accessToken != null) {
        headers['Authorization'] = 'Bearer ${session!.accessToken}';
      }
    } catch (_) {
      // Token read failure should not block sync — proceed without auth header.
    }

    final uri = Uri.parse(
      row.operation == 'create'
          ? '$baseUrl/$endpoint'
          : '$baseUrl/$endpoint/${row.entityId}',
    );

    http.Response response;

    switch (row.operation) {
      case 'create':
        response = await http.post(uri, headers: headers, body: row.payload);
      case 'update':
        response = await http.put(uri, headers: headers, body: row.payload);
      case 'delete':
        response = await http.delete(uri, headers: headers);
      default:
        return false;
    }

    // 401 indicates the JWT is expired or invalid — the item should be
    // retried after re-login, so we treat it as a transient failure.
    if (response.statusCode == 401) return false;

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// Maps a sync queue entity type to its backend API route segment.
  ///
  /// Backend controllers use PascalCase pluralized names under `/api/`.
  /// This mapping normalizes both singular and plural forms received from
  /// the queue into the correct route path.
  String _getEndpoint(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'product':
      case 'products':
        return 'Products';
      case 'customer':
      case 'customers':
        return 'Customers';
      case 'bill':
      case 'bills':
        return 'Bills';
      case 'stock':
      case 'stocks':
        return 'Inventory';
      case 'employee':
      case 'employees':
        return 'Employees';
      case 'supplier':
      case 'suppliers':
        return 'Suppliers';
      case 'category':
      case 'categories':
        return 'Categories';
      case 'purchase':
      case 'purchases':
      case 'purchaseorder':
        return 'Purchases';
      case 'salesorder':
      case 'salesorders':
        return 'SalesOrders';
      case 'challan':
      case 'challans':
      case 'deliverychallan':
        return 'Challans';
      case 'ledger':
      case 'ledgerentry':
        return 'Accounting';
      default:
        return entityType;
    }
  }

  @override
  Future<Either<Failure, void>> resolveConflict(String itemId, {bool useLocal = true}) async {
    try {
      final existing = await _dao.getSyncItemById(itemId);
      if (existing == null) {
        return const Left(CacheFailure(message: 'Sync item not found'));
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
        await Future<void>.delayed(delay);

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

  /// Pulls server-side changes since [lastSyncTimestamp] and upserts them
  /// into the local Drift database.
  ///
  /// Calls `POST /api/Sync/download` with the given timestamp and entity types,
  /// then iterates through the returned items, deserializing each payload and
  /// inserting or updating the corresponding local table row.
  ///
  /// Backend monetary values are in **rupees** (decimal); the local DB stores
  /// **paise** (integer), so all monetary fields are multiplied by 100.
  @override
  Future<Either<Failure, int>> downloadFromServer({
    DateTime? lastSyncTimestamp,
    List<String>? entityTypes,
    int limit = 100,
  }) async {
    try {
      final baseUrl = Environment.current.baseUrl;
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // Attach JWT if available
      try {
        final session = await _dao.getActiveSession();
        if (session?.accessToken != null) {
          headers['Authorization'] = 'Bearer ${session!.accessToken}';
        }
      } catch (_) {}

      final since = lastSyncTimestamp ?? DateTime.utc(2000, 1, 1);
      final types = entityTypes ?? const [
        'product', 'customer', 'bill', 'supplier',
        'category', 'employee', 'stock',
      ];

      final body = jsonEncode({
        'lastSyncTimestamp': since.toIso8601String(),
        'entityTypes': types,
        'limit': limit,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/Sync/download'),
        headers: headers,
        body: body,
      );

      if (response.statusCode != 200) {
        return Left(ServerFailure(
          message: 'Download failed: ${response.statusCode}',
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final items = data['items'] as List<dynamic>? ?? [];
      var upsertedCount = 0;

      for (final item in items) {
        try {
          final entityType = item['entityType'] as String? ?? '';
          final payload = item['payload'];
          if (payload == null) continue;

          final didUpsert = await _upsertDownloadedEntity(entityType, payload);
          if (didUpsert) upsertedCount++;
        } catch (_) {
          // Individual entity failures should not abort the batch.
        }
      }

      return Right(upsertedCount);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Dispatches a single downloaded entity payload to the appropriate
  /// table upsert handler based on [entityType].
  ///
  /// Returns `true` if the entity was successfully upserted.
  Future<bool> _upsertDownloadedEntity(
    String entityType,
    dynamic payload,
  ) async {
    final map = payload as Map<String, dynamic>;
    switch (entityType.toLowerCase()) {
      case 'product':
        return _upsertProduct(map);
      case 'customer':
        return _upsertCustomer(map);
      case 'bill':
        return _upsertBill(map);
      case 'supplier':
        return _upsertSupplier(map);
      case 'category':
        return _upsertCategory(map);
      case 'employee':
        return _upsertEmployee(map);
      default:
        return false;
    }
  }

  /// Upserts a Product from server JSON into the local Drift [Products] table.
  ///
  /// Converts decimal rupee values (MRP, sellingPrice, purchasePrice) to
  /// integer paise by multiplying by 100 and rounding.
  Future<bool> _upsertProduct(Map<String, dynamic> map) async {
    final id = map['id'] as String? ?? '';
    if (id.isEmpty) return false;

    final existing = await _dao.getProductById(id);
    final mrp = _decimalToPaise(map['mrp']);
    final sellingPrice = _decimalToPaise(map['sellingPrice']);
    final purchasePrice = _decimalToPaise(map['purchasePrice']);
    final version = (map['version'] as num?)?.toInt() ?? 1;

    if (existing == null) {
      await _dao.insertProduct(db.ProductsCompanion.insert(
        id: id,
        name: map['name'] as String? ?? '',
        hsnCode: map['hsnCode'] as String? ?? '',
        mrp: mrp,
        sellingPrice: sellingPrice,
        createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
        updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
        sku: db.Value(map['sku'] as String?),
        barcode: db.Value(map['barcode'] as String?),
        unit: db.Value(map['unit'] as String? ?? 'PCS'),
        packSize: db.Value((map['packSize'] as num?)?.toDouble() ?? 1.0),
        purchasePrice: db.Value(purchasePrice),
        taxRate: db.Value((map['taxRate'] as num?)?.toDouble() ?? 0.0),
        taxType: db.Value(map['taxType'] as String? ?? 'GST'),
        categoryId: db.Value(map['categoryId'] as String?),
        supplierId: db.Value(map['supplierId'] as String?),
        reorderLevel: db.Value((map['reorderLevel'] as num?)?.toInt() ?? 10),
        currentStock: db.Value((map['currentStock'] as num?)?.toInt() ?? 0),
        isActive: db.Value(map['isActive'] as bool? ?? true),
        version: db.Value(version),
        syncStatus: const db.Value('synced'),
      ));
    } else if (version > existing.version) {
      await _dao.updateProduct(db.ProductsCompanion(
        id: db.Value(id),
        name: db.Value(map['name'] as String? ?? existing.name),
        sku: db.Value(map['sku'] as String? ?? existing.sku),
        barcode: db.Value(map['barcode'] as String? ?? existing.barcode),
        hsnCode: db.Value(map['hsnCode'] as String? ?? existing.hsnCode),
        unit: db.Value(map['unit'] as String? ?? existing.unit),
        packSize: db.Value((map['packSize'] as num?)?.toDouble() ?? existing.packSize),
        mrp: db.Value(mrp),
        sellingPrice: db.Value(sellingPrice),
        purchasePrice: db.Value(purchasePrice),
        taxRate: db.Value((map['taxRate'] as num?)?.toDouble() ?? existing.taxRate),
        taxType: db.Value(map['taxType'] as String? ?? existing.taxType),
        categoryId: db.Value(map['categoryId'] as String?),
        supplierId: db.Value(map['supplierId'] as String?),
        reorderLevel: db.Value((map['reorderLevel'] as num?)?.toInt() ?? existing.reorderLevel),
        currentStock: db.Value((map['currentStock'] as num?)?.toInt() ?? existing.currentStock),
        isActive: db.Value(map['isActive'] as bool? ?? existing.isActive),
        version: db.Value(version),
        syncStatus: const db.Value('synced'),
        updatedAt: db.Value(_parseDateTime(map['updatedAt']) ?? DateTime.now()),
      ));
    }
    return true;
  }

  /// Upserts a Customer from server JSON into the local Drift [Customers] table.
  Future<bool> _upsertCustomer(Map<String, dynamic> map) async {
    final id = map['id'] as String? ?? '';
    if (id.isEmpty) return false;

    final existing = await _dao.getCustomerById(id);
    final version = (map['version'] as num?)?.toInt() ?? 1;

    if (existing == null) {
      await _dao.insertCustomer(db.CustomersCompanion.insert(
        id: id,
        name: map['name'] as String? ?? '',
        createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
        updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
        phone: db.Value(map['phone'] as String?),
        email: db.Value(map['email'] as String?),
        address: db.Value(map['address'] as String?),
        city: db.Value(map['city'] as String?),
        state: db.Value(map['state'] as String?),
        pincode: db.Value(map['pincode'] as String?),
        gstin: db.Value(map['gstin'] as String?),
        type: db.Value(map['type'] as String? ?? 'B2C'),
        creditLimit: db.Value(_decimalToPaise(map['creditLimit'])),
        currentBalance: db.Value(_decimalToPaise(map['currentBalance'])),
        loyaltyPoints: db.Value((map['loyaltyPoints'] as num?)?.toInt() ?? 0),
        loyaltyCardNumber: db.Value(map['loyaltyCardNumber'] as String?),
        isActive: db.Value(map['isActive'] as bool? ?? true),
        version: db.Value(version),
        syncStatus: const db.Value('synced'),
      ));
    } else if (version > existing.version) {
      await _dao.updateCustomer(db.CustomersCompanion(
        id: db.Value(id),
        name: db.Value(map['name'] as String? ?? existing.name),
        phone: db.Value(map['phone'] as String? ?? existing.phone),
        email: db.Value(map['email'] as String? ?? existing.email),
        address: db.Value(map['address'] as String? ?? existing.address),
        city: db.Value(map['city'] as String? ?? existing.city),
        state: db.Value(map['state'] as String? ?? existing.state),
        pincode: db.Value(map['pincode'] as String? ?? existing.pincode),
        gstin: db.Value(map['gstin'] as String? ?? existing.gstin),
        type: db.Value(map['type'] as String? ?? existing.type),
        creditLimit: db.Value(_decimalToPaise(map['creditLimit'])),
        currentBalance: db.Value(_decimalToPaise(map['currentBalance'])),
        loyaltyPoints: db.Value((map['loyaltyPoints'] as num?)?.toInt() ?? existing.loyaltyPoints),
        loyaltyCardNumber: db.Value(map['loyaltyCardNumber'] as String? ?? existing.loyaltyCardNumber),
        isActive: db.Value(map['isActive'] as bool? ?? existing.isActive),
        version: db.Value(version),
        syncStatus: const db.Value('synced'),
        updatedAt: db.Value(_parseDateTime(map['updatedAt']) ?? DateTime.now()),
      ));
    }
    return true;
  }

  /// Upserts a Bill from server JSON into the local Drift [Bills] table.
  ///
  /// Bills are append-only — if the bill already exists locally, it is skipped
  /// to preserve the integrity of the local audit trail.
  Future<bool> _upsertBill(Map<String, dynamic> map) async {
    final id = map['id'] as String? ?? '';
    if (id.isEmpty) return false;

    final existing = await _dao.getBillById(id);
    if (existing != null) return false; // Bills are immutable once synced

    await _dao.insertBill(db.BillsCompanion.insert(
      id: id,
      billNumber: map['billNumber'] as String? ?? '',
      billDate: _parseDateTime(map['billDate']) ?? DateTime.now(),
      subtotal: _decimalToPaise(map['subtotal']),
      totalAmount: _decimalToPaise(map['totalAmount']),
      createdBy: map['createdBy'] as String? ?? 'system',
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
      invoiceNumber: db.Value(map['invoiceNumber'] as String?),
      customerId: db.Value(map['customerId'] as String?),
      taxAmount: db.Value(_decimalToPaise(map['taxAmount'])),
      cgstAmount: db.Value(_decimalToPaise(map['cgstAmount'])),
      sgstAmount: db.Value(_decimalToPaise(map['sgstAmount'])),
      igstAmount: db.Value(_decimalToPaise(map['igstAmount'])),
      taxRuleVersion: db.Value(map['taxRuleVersion'] as String? ?? 'v1'),
      discountAmount: db.Value(_decimalToPaise(map['discountAmount'])),
      roundOff: db.Value(_decimalToPaise(map['roundOff'])),
      paidAmount: db.Value(_decimalToPaise(map['paidAmount'])),
      dueAmount: db.Value(_decimalToPaise(map['dueAmount'])),
      paymentMode: db.Value(map['paymentMode'] as String? ?? 'CASH'),
      status: db.Value(map['status'] as String? ?? 'completed'),
      isReturn: db.Value(map['isReturn'] as bool? ?? false),
      referenceBillId: db.Value(map['referenceBillId'] as String?),
      version: db.Value((map['version'] as num?)?.toInt() ?? 1),
      syncStatus: const db.Value('synced'),
    ));
    return true;
  }

  /// Upserts a Supplier from server JSON into the local Drift [Suppliers] table.
  Future<bool> _upsertSupplier(Map<String, dynamic> map) async {
    final id = map['id'] as String? ?? '';
    if (id.isEmpty) return false;

    final existing = await _dao.getSupplierById(id);
    final version = (map['version'] as num?)?.toInt() ?? 1;

    if (existing == null) {
      await _dao.insertSupplier(db.SuppliersCompanion.insert(
        id: id,
        name: map['name'] as String? ?? '',
        createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
        updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
        phone: db.Value(map['phone'] as String?),
        email: db.Value(map['email'] as String?),
        address: db.Value(map['address'] as String?),
        city: db.Value(map['city'] as String?),
        state: db.Value(map['state'] as String?),
        gstin: db.Value(map['gstin'] as String?),
        pan: db.Value(map['pan'] as String?),
        outstandingBalance: db.Value(_decimalToPaise(map['currentBalance'])),
        isActive: db.Value(map['isActive'] as bool? ?? true),
        version: db.Value(version),
        syncStatus: const db.Value('synced'),
      ));
    } else if (version > existing.version) {
      await _dao.updateSupplier(db.SuppliersCompanion(
        id: db.Value(id),
        name: db.Value(map['name'] as String? ?? existing.name),
        phone: db.Value(map['phone'] as String? ?? existing.phone),
        email: db.Value(map['email'] as String? ?? existing.email),
        address: db.Value(map['address'] as String? ?? existing.address),
        city: db.Value(map['city'] as String? ?? existing.city),
        state: db.Value(map['state'] as String? ?? existing.state),
        gstin: db.Value(map['gstin'] as String? ?? existing.gstin),
        pan: db.Value(map['pan'] as String? ?? existing.pan),
        outstandingBalance: db.Value(_decimalToPaise(map['currentBalance'])),
        isActive: db.Value(map['isActive'] as bool? ?? existing.isActive),
        version: db.Value(version),
        syncStatus: const db.Value('synced'),
        updatedAt: db.Value(_parseDateTime(map['updatedAt']) ?? DateTime.now()),
      ));
    }
    return true;
  }

  /// Upserts a Category from server JSON into the local Drift [Categories] table.
  Future<bool> _upsertCategory(Map<String, dynamic> map) async {
    final id = map['id'] as String? ?? '';
    if (id.isEmpty) return false;

    final existing = await _dao.getCategoryById(id);
    final version = (map['version'] as num?)?.toInt() ?? 1;

    if (existing == null) {
      await _dao.insertCategory(db.CategoriesCompanion.insert(
        id: id,
        name: map['name'] as String? ?? '',
        createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
        updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
        description: db.Value(map['description'] as String?),
        colorCode: db.Value(map['color'] as String? ?? '#4CAF50'),
        iconName: db.Value(map['icon'] as String? ?? 'category'),
        sortOrder: db.Value((map['sortOrder'] as num?)?.toInt() ?? 0),
        version: db.Value(version),
        syncStatus: const db.Value('synced'),
      ));
    } else if (version > existing.version) {
      await _dao.updateCategory(db.CategoriesCompanion(
        id: db.Value(id),
        name: db.Value(map['name'] as String? ?? existing.name),
        description: db.Value(map['description'] as String? ?? existing.description),
        colorCode: db.Value(map['color'] as String? ?? existing.colorCode),
        iconName: db.Value(map['icon'] as String? ?? existing.iconName),
        sortOrder: db.Value((map['sortOrder'] as num?)?.toInt() ?? existing.sortOrder),
        version: db.Value(version),
        syncStatus: const db.Value('synced'),
        updatedAt: db.Value(_parseDateTime(map['updatedAt']) ?? DateTime.now()),
      ));
    }
    return true;
  }

  /// Upserts an Employee from server JSON into the local Drift [Employees] table.
  Future<bool> _upsertEmployee(Map<String, dynamic> map) async {
    final id = map['id'] as String? ?? '';
    if (id.isEmpty) return false;

    final existing = await _dao.getEmployeeById(id);
    final version = (map['version'] as num?)?.toInt() ?? 1;

    if (existing == null) {
      await _dao.insertEmployee(db.EmployeesCompanion.insert(
        id: id,
        name: map['fullName'] as String? ?? map['name'] as String? ?? '',
        createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
        updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
        phone: db.Value(map['phone'] as String?),
        email: db.Value(map['email'] as String?),
        role: db.Value(map['role'] as String? ?? 'cashier'),
        pin: db.Value(map['pin'] as String?),
        isActive: db.Value(map['isActive'] as bool? ?? true),
        version: db.Value(version),
        syncStatus: const db.Value('synced'),
      ));
    } else if (version > existing.version) {
      await _dao.updateEmployee(db.EmployeesCompanion(
        id: db.Value(id),
        name: db.Value(map['fullName'] as String? ?? map['name'] as String? ?? existing.name),
        phone: db.Value(map['phone'] as String? ?? existing.phone),
        email: db.Value(map['email'] as String? ?? existing.email),
        role: db.Value(map['role'] as String? ?? existing.role),
        pin: db.Value(map['pin'] as String? ?? existing.pin),
        isActive: db.Value(map['isActive'] as bool? ?? existing.isActive),
        version: db.Value(version),
        syncStatus: const db.Value('synced'),
        updatedAt: db.Value(_parseDateTime(map['updatedAt']) ?? DateTime.now()),
      ));
    }
    return true;
  }

  /// Converts a decimal/num value from rupees to integer paise.
  ///
  /// Backend stores monetary values as `decimal` in rupees (e.g., 190.50).
  /// The local Drift schema stores them as `integer` in paise (e.g., 19050).
  /// Returns 0 if the input is null or not a valid number.
  int _decimalToPaise(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value * 100;
    if (value is double) return (value * 100).round();
    if (value is num) return (value.toDouble() * 100).round();
    return 0;
  }

  /// Safely parses an ISO-8601 date string into a [DateTime], returning
  /// `null` if the input is null or unparseable.
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
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
