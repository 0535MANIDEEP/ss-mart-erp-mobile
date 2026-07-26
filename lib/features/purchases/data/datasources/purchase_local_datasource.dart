/// Purchase Local Data Source — Local persistence layer for purchase order data.
///
/// ## Architecture Role
/// Sits between [PurchaseRepositoryImpl] and the Drift database. Abstracts all
/// details of how purchase orders and their line items are stored, queried, and
/// converted to/from domain entities. The repository never touches raw SQL or DAO objects.
///
/// ## Responsibilities
/// - CRUD operations on the [Purchases] and [PurchaseItems] tables.
/// - Loading purchase orders with their associated line items (composite entity).
/// - Filtering by supplier ID and/or date range.
/// - Bidirectional mapping between domain entities ([Purchase], [PurchaseItem])
///   and Drift row/companion objects.
///
/// ## Data Flow
/// ```
/// Repository → PurchaseLocalDataSource → DatabaseDao (Drift) → SQLite
/// ```
///
/// ## Design Decisions
/// - Uses Drift's query builder (`_dao.select(...)`) for supplier-filtered queries
///   instead of a dedicated DAO method. This is because the filter is specific to
///   this datasource's needs and doesn't warrant a general-purpose DAO method.
/// - Purchase items are deleted and re-inserted on every save (delete-and-replace
///   strategy). This is simpler than diffing old/new items and works well because
///   purchase orders are relatively immutable once saved. The trade-off is slightly
///   higher write cost, but correctness is guaranteed.
/// - The DAO is injected via constructor (not created from the database) to allow
///   the DI container to manage its lifecycle. This differs from other datasources
///   that create the DAO internally — the inconsistency is historical.
library;

import 'package:drift/drift.dart';
import '../../../../database/app_database.dart' as db;
import '../../domain/entities/purchase_entity.dart';

/// Abstract contract for local purchase order persistence.
///
/// The repository layer depends on this interface, not on the concrete
/// implementation, enabling unit testing with fakes/mocks.
abstract class PurchaseLocalDataSource {
  /// Returns a list of purchase orders, optionally filtered by [supplierId]
  /// and/or a date range ([startDate] to [endDate]).
  Future<List<Purchase>> getPurchases({String? supplierId, String? startDate, String? endDate});

  /// Returns a single purchase order with its line items, or `null` if not found.
  Future<Purchase?> getPurchaseById(String id);

  /// Upserts a purchase order including all its line items.
  ///
  /// Existing line items for this purchase are deleted and replaced to ensure
  /// consistency with the provided list.
  Future<void> savePurchase(Purchase purchase);

  /// Deletes a purchase order and all its associated line items.
  Future<void> deletePurchase(String id);
}

/// Concrete implementation backed by Drift's [AppDatabase].
///
/// Handles the mapping between domain entities ([Purchase], [PurchaseItem]) and
/// their respective Drift row/companion objects. Purchase orders are composite
/// entities: the header maps to [db.Purchase] and line items map to [db.PurchaseItem].
class PurchaseLocalDataSourceImpl implements PurchaseLocalDataSource {
  final db.DatabaseDao _dao;

  PurchaseLocalDataSourceImpl({required db.DatabaseDao dao}) : _dao = dao;

  @override
  Future<List<Purchase>> getPurchases({
    String? supplierId,
    String? startDate,
    String? endDate,
  }) async {
    List<db.Purchase> rows;

    if (supplierId != null) {
      // Use Drift's query builder for supplier-specific queries.
      // Results are ordered by creation date descending (newest first).
      rows = await (_dao.select(_dao.purchases)
            ..where((t) => t.supplierId.equals(supplierId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
    } else {
      rows = await _dao.getAllPurchases();
    }

    // Load line items for each purchase order (N+1 pattern).
    // This is acceptable because purchase lists are typically small (< 100 items)
    // and the alternative (a single JOIN query) would require complex result
    // parsing in Drift. For large datasets, consider a batch-load approach.
    final purchases = <Purchase>[];
    for (final row in rows) {
      final items = await _dao.getPurchaseItemsByPurchaseId(row.id);
      purchases.add(_rowToEntity(row, items));
    }
    return purchases;
  }

  @override
  Future<Purchase?> getPurchaseById(String id) async {
    final row = await _dao.getPurchaseById(id);
    if (row == null) return null;
    final items = await _dao.getPurchaseItemsByPurchaseId(id);
    return _rowToEntity(row, items);
  }

  @override
  Future<void> savePurchase(Purchase purchase) async {
    // Step 1: Upsert the purchase header.
    final companion = db.PurchasesCompanion(
      id: db.Value(purchase.id),
      purchaseNumber: db.Value(purchase.purchaseNumber),
      supplierId: db.Value(purchase.supplierId),
      supplierName: db.Value(purchase.supplierName),
      purchaseDate: db.Value(purchase.purchaseDate),
      subtotal: db.Value(purchase.subtotal),
      taxAmount: db.Value(purchase.taxAmount),
      totalAmount: db.Value(purchase.totalAmount),
      status: db.Value(purchase.status),
      createdAt: db.Value(purchase.createdAt),
      updatedAt: db.Value(purchase.updatedAt),
      version: db.Value(purchase.version),
    );
    await _dao.insertPurchase(companion);

    // Step 2: Delete-and-replace all line items.
    // This ensures the DB state exactly matches the domain model,
    // avoiding complex diff logic for added/removed/updated items.
    await _dao.deletePurchaseItemsByPurchaseId(purchase.id);
    for (final item in purchase.items) {
      await _dao.insertPurchaseItem(_itemToCompanion(item, purchase.id));
    }
  }

  @override
  Future<void> deletePurchase(String id) async {
    // Delete line items first to respect foreign key constraints.
    await _dao.deletePurchaseItemsByPurchaseId(id);
    await (_dao.delete(_dao.purchases)..where((t) => t.id.equals(id))).go();
  }

  /// Converts a Drift [db.Purchase] row and its associated [db.PurchaseItem] rows
  /// into a domain [Purchase] entity.
  Purchase _rowToEntity(db.Purchase row, List<db.PurchaseItem> itemRows) {
    return Purchase(
      id: row.id,
      purchaseNumber: row.purchaseNumber,
      supplierId: row.supplierId,
      supplierName: row.supplierName,
      purchaseDate: row.purchaseDate,
      subtotal: row.subtotal,
      taxAmount: row.taxAmount,
      totalAmount: row.totalAmount,
      status: row.status,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      version: row.version,
      items: itemRows.map(_itemRowToEntity).toList(),
    );
  }

  /// Converts a Drift [db.PurchaseItem] row into a domain [PurchaseItem] entity.
  PurchaseItem _itemRowToEntity(db.PurchaseItem row) {
    return PurchaseItem(
      id: row.id,
      productId: row.productId,
      productName: row.productName,
      quantity: row.quantity,
      unitPrice: row.unitPrice,
      taxRate: row.taxRate,
      taxAmount: row.taxAmount,
      totalAmount: row.totalAmount,
      batchNumber: row.batchNumber,
    );
  }

  /// Converts a domain [PurchaseItem] entity into a Drift companion for writes.
  ///
  /// The [purchaseId] is passed explicitly because the domain entity doesn't
  /// store the parent ID (it's implied by the containing [Purchase] object).
  db.PurchaseItemsCompanion _itemToCompanion(PurchaseItem item, String purchaseId) {
    return db.PurchaseItemsCompanion(
      id: db.Value(item.id),
      purchaseId: db.Value(purchaseId),
      productId: db.Value(item.productId),
      productName: db.Value(item.productName),
      quantity: db.Value(item.quantity),
      unitPrice: db.Value(item.unitPrice),
      taxRate: db.Value(item.taxRate),
      taxAmount: db.Value(item.taxAmount),
      totalAmount: db.Value(item.totalAmount),
      batchNumber: db.Value(item.batchNumber),
    );
  }
}
