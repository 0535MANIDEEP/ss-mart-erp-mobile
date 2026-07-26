/// Stock Local Data Source — Local persistence layer for inventory/stock data.
///
/// ## Architecture Role
/// Sits between [StockRepositoryImpl] and the Drift database. Abstracts all
/// details of how stock rows are stored, queried, and converted to/from domain
/// entities. The repository layer never touches raw SQL or DAO objects.
///
/// ## Responsibilities
/// - CRUD operations on the [StockData] table.
/// - Querying stock by location (warehouse/store) or by product ID.
/// - Filtering for low-stock items (where `currentStock <= reorderLevel`).
/// - Bidirectional mapping between [db.StockData] (database row) and [Stock]
///   (domain entity).
///
/// ## Data Flow
/// ```
/// Repository → StockLocalDataSource → DatabaseDao (Drift) → SQLite
/// ```
///
/// ## Design Decisions
/// - `lowStockOnly` filtering happens in memory after fetching all rows. This is
///   intentional: the `isLowStock` flag is a computed property on the [Stock] entity
///   (comparing `quantity` against `reorderLevel`), so it can't be pushed to SQL
///   without duplicating business logic in the query layer.
/// - The DAO is created once in the constructor and cached, following the same
///   pattern as [CustomerLocalDataSourceImpl].
/// - Stock data includes `batchNumber` and `expiryDate` to support batch-tracked
///   inventory (common in retail/pharma ERP systems).
library;

import '../../../../database/app_database.dart' as db;
import '../../domain/entities/stock_entity.dart';

/// Abstract contract for local stock/inventory persistence.
///
/// The repository layer depends on this interface, not on the concrete
/// implementation, enabling unit testing with fakes/mocks.
abstract class StockLocalDataSource {
  /// Returns a list of stock records, optionally filtered by [locationId]
  /// and/or [lowStockOnly]. When [lowStockOnly] is true, only items whose
  /// current quantity is at or below the reorder level are returned.
  Future<List<Stock>> getStock({String? locationId, bool lowStockOnly = false});

  /// Returns the stock record for a given [productId], or `null` if no
  /// stock entry exists for that product.
  Future<Stock?> getStockByProductId(String productId);

  /// Upserts a stock record — inserts if new, updates if the ID already exists.
  Future<void> saveStock(Stock stock);

  /// Deletes a stock record by its [id].
  Future<void> deleteStock(String id);
}

/// Concrete implementation backed by Drift's [AppDatabase].
///
/// Handles the mapping between the domain [Stock] entity and the Drift-generated
/// [db.StockData] row object. The companion ([db.StockCompanion]) is used for
/// writes, while the row object is used for reads.
class StockLocalDataSourceImpl implements StockLocalDataSource {
  final db.DatabaseDao _dao;

  StockLocalDataSourceImpl({required db.AppDatabase database})
      : _dao = db.DatabaseDao(database);

  @override
  Future<List<Stock>> getStock({
    String? locationId,
    bool lowStockOnly = false,
  }) async {
    List<db.StockData> rows;

    // Fetch by location if specified, otherwise fetch all stock.
    if (locationId != null) {
      rows = await _dao.getStockByLocation(locationId);
    } else {
      rows = await _dao.getAllStock();
    }

    var stocks = rows.map(_toEntity).toList();

    // Apply low-stock filter in memory. The `isLowStock` property on the
    // domain entity encapsulates the reorder-level comparison logic,
    // keeping business rules out of the data layer.
    if (lowStockOnly) {
      stocks = stocks.where((s) => s.isLowStock).toList();
    }

    return stocks;
  }

  @override
  Future<Stock?> getStockByProductId(String productId) async {
    final row = await _dao.getStockByProductId(productId);
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<void> saveStock(Stock stock) async {
    await _dao.insertStock(_toCompanion(stock));
  }

  @override
  Future<void> deleteStock(String id) async {
    await _dao.deleteStock(id);
  }

  /// Converts a Drift [db.StockData] row into a domain [Stock] entity.
  ///
  /// Fields like `batchNumber` and `expiryDate` are nullable because not all
  /// products are batch-tracked — only those configured with batch management
  /// in the product master will have these values populated.
  Stock _toEntity(db.StockData row) {
    return Stock(
      id: row.id,
      productId: row.productId,
      productName: row.productName,
      locationId: row.locationId,
      quantity: row.quantity,
      reservedQuantity: row.reservedQuantity,
      batchNumber: row.batchNumber,
      expiryDate: row.expiryDate,
      lastUpdated: row.lastUpdated,
    );
  }

  /// Converts a domain [Stock] entity into a Drift [StockCompanion] for writes.
  ///
  /// Uses `StockCompanion.insert()` (not the regular constructor) because all
  /// fields are required at insert time. Nullable fields use `db.Value()` to
  /// explicitly set them to NULL when absent.
  db.StockCompanion _toCompanion(Stock stock) {
    return db.StockCompanion.insert(
      id: stock.id,
      productId: stock.productId,
      quantity: stock.quantity,
      lastUpdated: stock.lastUpdated,
      productName: db.Value(stock.productName),
      locationId: db.Value(stock.locationId),
      reservedQuantity: db.Value(stock.reservedQuantity),
      batchNumber: db.Value(stock.batchNumber),
      expiryDate: db.Value(stock.expiryDate),
    );
  }
}
