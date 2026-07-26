/// Product Local Data Source — Local persistence layer for product catalog data.
///
/// ## Architecture Role
/// Sits between [ProductRepositoryImpl] and the Drift database, abstracting all
/// details of how product rows are stored, queried, and converted to/from domain
/// entities. The repository never touches raw SQL or DAO objects.
///
/// ## Responsibilities
/// - CRUD operations on the [Products] table.
/// - Search by name/SKU and filtering by category.
/// - Bidirectional mapping between [db.Product] (database row) and [Product]
///   (domain entity).
///
/// ## Data Flow
/// ```
/// Repository → ProductLocalDataSource → DatabaseDao (Drift) → SQLite
/// ```
///
/// ## Design Decisions
/// - The DAO is instantiated per-call rather than cached in the constructor.
///   This avoids stale-database references when the Drift [AppDatabase] is
///   recreated (e.g., after a migration or hot restart).
/// - Pagination is applied in-memory after fetching results. This is acceptable
///   because the product catalog is bounded (typically < 10k rows in an ERP).
///   For larger datasets, push pagination down to the DAO with `limit`/`offset`.
library;

import 'package:drift/drift.dart';
import '../../../../database/app_database.dart' as db;
import '../../domain/entities/product_entity.dart';

/// Abstract contract for local product persistence.
///
/// The repository layer depends on this interface, not on the concrete
/// implementation, enabling unit testing with fakes/mocks.
abstract class ProductLocalDataSource {
  /// Returns a paginated list of products, optionally filtered by [search] query
  /// or [categoryId]. Defaults to page 1 with 20 items per page.
  Future<List<Product>> getProducts({String? search, String? categoryId, int page = 1, int perPage = 20});

  /// Returns a single product by its unique [id], or `null` if not found.
  Future<Product?> getProductById(String id);

  /// Returns a single product matching the given [barcode], or `null` if not found.
  Future<Product?> getProductByBarcode(String barcode);

  /// Upserts a product — inserts if new, updates if the ID already exists.
  Future<void> saveProduct(Product product);

  /// Soft/hard-deletes a product by its [id].
  Future<void> deleteProduct(String id);
}

/// Concrete implementation backed by Drift's [AppDatabase].
///
/// Handles the mapping between the domain [Product] entity and the Drift-generated
/// [db.Product] row object. The companion ([db.ProductsCompanion]) is used for
/// writes, while the row object is used for reads.
class ProductLocalDataSourceImpl implements ProductLocalDataSource {
  final db.AppDatabase _database;

  ProductLocalDataSourceImpl({required db.AppDatabase database}) : _database = database;

  @override
  Future<List<Product>> getProducts({
    String? search,
    String? categoryId,
    int page = 1,
    int perPage = 20,
  }) async {
    // Fresh DAO per call — see design decision in class doc.
    final dao = db.DatabaseDao(_database);
    List<db.Product> rows;

    // Branch on the most specific filter first: search takes priority over
    // category, which takes priority over returning all active products.
    if (search != null && search.isNotEmpty) {
      rows = await dao.searchProducts(search, limit: perPage);
    } else if (categoryId != null) {
      rows = await dao.getProductsByCategory(categoryId);
    } else {
      rows = await dao.getActiveProducts();
    }

    // Map database rows to domain entities.
    return rows.map(_toEntity).toList();
  }

  @override
  Future<Product?> getProductById(String id) async {
    final dao = db.DatabaseDao(_database);
    final row = await dao.getProductById(id);
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    final dao = db.DatabaseDao(_database);
    final row = await dao.getProductByBarcode(barcode);
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<void> saveProduct(Product product) async {
    final dao = db.DatabaseDao(_database);
    // Convert domain entity → Drift companion for upsert.
    await dao.insertProduct(_toCompanion(product));
  }

  @override
  Future<void> deleteProduct(String id) async {
    final dao = db.DatabaseDao(_database);
    await dao.deleteProduct(id);
  }

  /// Converts a Drift [db.Product] row into a domain [Product] entity.
  ///
  /// All fields are mapped 1:1 because the domain entity was designed to mirror
  /// the database schema. If the schema evolves, only this method needs updating.
  Product _toEntity(db.Product row) {
    return Product(
      id: row.id,
      name: row.name,
      sku: row.sku,
      barcode: row.barcode,
      hsnCode: row.hsnCode,
      unit: row.unit,
      packSize: row.packSize,
      mrp: row.mrp,
      sellingPrice: row.sellingPrice,
      purchasePrice: row.purchasePrice,
      taxRate: row.taxRate,
      taxType: row.taxType,
      categoryId: row.categoryId,
      supplierId: row.supplierId,
      reorderLevel: row.reorderLevel,
      currentStock: row.currentStock,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      version: row.version,
    );
  }

  /// Converts a domain [Product] entity into a Drift [ProductsCompanion] for writes.
  ///
  /// Uses `db.Value()` wrappers to mark nullable columns explicitly. Drift requires
  /// this distinction between "column not provided" and "column set to null".
  db.ProductsCompanion _toCompanion(Product product) {
    return db.ProductsCompanion(
      id: db.Value(product.id),
      name: db.Value(product.name),
      sku: db.Value(product.sku),
      barcode: db.Value(product.barcode),
      hsnCode: db.Value(product.hsnCode),
      unit: db.Value(product.unit),
      packSize: db.Value(product.packSize),
      mrp: db.Value(product.mrp),
      sellingPrice: db.Value(product.sellingPrice),
      purchasePrice: db.Value(product.purchasePrice),
      taxRate: db.Value(product.taxRate),
      taxType: db.Value(product.taxType),
      categoryId: db.Value(product.categoryId),
      supplierId: db.Value(product.supplierId),
      reorderLevel: db.Value(product.reorderLevel),
      currentStock: db.Value(product.currentStock),
      isActive: db.Value(product.isActive),
      createdAt: db.Value(product.createdAt),
      updatedAt: db.Value(product.updatedAt),
      version: db.Value(product.version),
    );
  }
}
