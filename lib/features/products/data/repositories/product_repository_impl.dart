import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_local_datasource.dart';
import '../datasources/product_remote_datasource.dart';

/// Implementation of [ProductRepository] that follows the offline-first
/// (local-first) architecture pattern for the SS MART ERP Mobile App.
///
/// ## Architecture & Sync Strategy
///
/// This repository coordinates between a [ProductLocalDataSource] (local
/// SQLite/Drift database) and a [ProductRemoteDataSource] (REST API). The
/// core principle is **local-first**: the app always reads from the local
/// database, ensuring instant UI response regardless of network state.
///
/// ### Read Pattern (Cache-First with Background Refresh)
/// 1. If the device is online, fetch fresh data from the remote API and
///    upsert it into the local database (silently, errors are swallowed).
/// 2. Always return data from the local database as the single source of
///    truth for the UI layer.
/// 3. For single-entity lookups (by ID or barcode), the local DB is
///    checked first; only on a miss does it attempt a remote fetch and
///    cache the result locally for future offline use.
///
/// ### Write Pattern (Local Write → Sync Queue → Remote)
/// - Create, update, and delete operations are performed **locally first**
///   via [ProductLocalDataSource]. This ensures the UI updates immediately
///   and the app remains functional offline.
/// - Downstream sync to the server is handled by the [SyncRepository]
///   (not this class). A separate sync worker picks up pending items and
///    pushes them to the remote API when connectivity is restored.
///
/// ### Error Handling
/// - All public methods return `Either<Failure, T>` using the `dartz`
///   functional error handling pattern.
/// - [Right(value)] represents a successful result.
/// - [Left(Failure)] represents an error. Two primary failure types are used:
///   - [ServerFailure]: network/server errors or general exceptions.
///   - [CacheFailure]: local database lookup failures (entity not found).
///
/// ### Relationship Between Local and Remote
/// - The remote data source is treated as the **authoritative source** for
///   product master data that originates from the server (e.g., admin-created
///   products). Remote data is synced down and cached locally.
/// - The local data source is the **write-through cache** and the primary
///   read source. All mutations happen locally first.
///
/// ### Map Conversion
/// - [_mapToProduct] converts raw API JSON maps into [Product] domain
///   entities. It defensively handles null/missing fields and type
///   coercion (e.g., String dates → DateTime).
class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;
  final ProductLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  ProductRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Fetches a paginated list of products, optionally filtered by search
  /// query and category.
  ///
  /// **Strategy**: Background refresh when online, always read locally.
  /// - When online: silently fetches from remote, upserts each product into
  ///   the local DB. Remote fetch errors are silently caught (the app
  ///   degrades gracefully to stale local data).
  /// - Always returns the local DB snapshot, ensuring consistent reads.
  /// - [categoryId] filter is applied locally only (remote API may not
  ///   support this filter, or the local view is preferred for consistency).
  @override
  Future<Either<Failure, List<Product>>> getProducts({
    String? search,
    String? categoryId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      if (await networkInfo.isConnected) {
        try {
          final remoteProducts = await remoteDataSource.getProducts(
            search: search,
            page: page,
            perPage: perPage,
          );
          for (final map in remoteProducts) {
            await localDataSource.saveProduct(_mapToProduct(map));
          }
        } catch (_) {}
      }
      final localProducts = await localDataSource.getProducts(
        search: search,
        categoryId: categoryId,
        page: page,
        perPage: perPage,
      );
      return Right(localProducts);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Retrieves a single product by its unique identifier.
  ///
  /// **Strategy**: Local-first with remote fallback.
  /// 1. Check the local database first — if found, return immediately (fast path).
  /// 2. If not found locally and the device is online, fetch from remote,
  ///    cache the result locally, and return it. This populates the local
  ///    cache for subsequent offline lookups.
  /// 3. If not found locally and offline, return [CacheFailure].
  /// 4. If the remote fetch fails, return [ServerFailure].
  @override
  Future<Either<Failure, Product>> getProductById(String id) async {
    try {
      final product = await localDataSource.getProductById(id);
      if (product != null) return Right(product);

      if (await networkInfo.isConnected) {
        try {
          final map = await remoteDataSource.getProductById(id);
          final p = _mapToProduct(map);
          await localDataSource.saveProduct(p);
          return Right(p);
        } catch (_) {
          return Left(ServerFailure(message: 'Product not found'));
        }
      }
      return Left(CacheFailure(message: 'Product not found'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Retrieves a product by its barcode (UPC/EAN/QR code).
  ///
  /// Follows the same local-first lookup pattern as [getProductById].
  /// Critical for POS barcode scanner workflows — the local-first approach
  /// ensures barcode scans work instantly even without internet connectivity.
  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    try {
      final product = await localDataSource.getProductByBarcode(barcode);
      if (product != null) return Right(product);

      if (await networkInfo.isConnected) {
        try {
          final map = await remoteDataSource.getProductByBarcode(barcode);
          final p = _mapToProduct(map);
          await localDataSource.saveProduct(p);
          return Right(p);
        } catch (_) {
          return Left(ServerFailure(message: 'Product not found'));
        }
      }
      return Left(CacheFailure(message: 'Product not found'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Creates a new product locally.
  ///
  /// **Strategy**: Local write only — the product is persisted to the local
  /// database immediately. Remote sync is handled asynchronously by the
  /// [SyncRepository] sync worker, which will pick up the new entity and
  /// push it to the server when connected.
  @override
  Future<Either<Failure, Product>> createProduct(Product product) async {
    try {
      await localDataSource.saveProduct(product);
      return Right(product);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Updates an existing product locally.
  ///
  /// Uses the same write-through local pattern as [createProduct]. The
  /// `saveProduct` call performs an upsert (insert or replace).
  @override
  Future<Either<Failure, Product>> updateProduct(Product product) async {
    try {
      await localDataSource.saveProduct(product);
      return Right(product);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Soft-deletes a product by marking it as inactive in the local database.
  ///
  /// Note: This performs a local delete. The sync worker will propagate
  /// the deletion to the remote server.
  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    try {
      await localDataSource.deleteProduct(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Converts a raw JSON map (from the remote API) into a [Product] domain entity.
  ///
  /// Handles defensive null-checking and type coercion for all fields.
  /// Date fields accept both [DateTime] objects (from local DB) and ISO 8601
  /// strings (from remote API), falling back to [DateTime.now()] if parsing fails.
  Product _mapToProduct(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      sku: map['sku'],
      barcode: map['barcode'],
      hsnCode: map['hsnCode'] ?? '',
      unit: map['unit'] ?? 'PCS',
      packSize: (map['packSize'] ?? 1.0).toDouble(),
      mrp: map['mrp'] ?? 0,
      sellingPrice: map['sellingPrice'] ?? 0,
      purchasePrice: map['purchasePrice'],
      taxRate: (map['taxRate'] ?? 0.0).toDouble(),
      taxType: map['taxType'] ?? 'GST',
      categoryId: map['categoryId'],
      supplierId: map['supplierId'],
      reorderLevel: map['reorderLevel'] ?? 10,
      currentStock: map['currentStock'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt']
          : DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: map['updatedAt'] is DateTime
          ? map['updatedAt']
          : DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      version: map['version'] ?? 1,
    );
  }
}
