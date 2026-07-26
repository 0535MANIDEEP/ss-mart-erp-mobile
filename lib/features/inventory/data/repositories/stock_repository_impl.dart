import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/repositories/stock_repository.dart';
import '../datasources/stock_local_datasource.dart';
import '../datasources/stock_remote_datasource.dart';

/// Implementation of [StockRepository] for local inventory/stock management
/// in the SS MART ERP Mobile App.
///
/// ## Architecture & Sync Strategy
///
/// This repository is **purely local-first** — all stock operations are
/// performed against the local database. There is no remote data source
/// interaction in the current implementation (the remote datasource is
/// injected but unused). This reflects the reality that stock is a
/// **local concern**: physical inventory exists at the store, and stock
/// levels should always reflect the local reality first.
///
/// ### Stock Adjustment (Core Operation)
/// The [adjustStock] method is the fundamental building block for all
/// inventory changes. It supports the following adjustment types:
///
/// **Stock Decreasing** (quantity -= adjustment):
/// - `'sale'`: Bill creation deducts stock for sold items.
/// - `'adjustment_down'`: Manual downward correction.
/// - `'transfer_out'`: Stock moved out to another location.
///
/// **Stock Increasing** (quantity += adjustment):
/// - `'purchase'`: Goods received from supplier.
/// - `'return'`: Customer returns (reverse of sale).
/// - `'adjustment_up'`: Manual upward correction.
/// - `'transfer_in'`: Stock received from another location.
///
/// ### Stock Transfer
/// The [transferStock] method composes two [adjustStock] calls:
/// 1. `transfer_out` at the source location.
/// 2. `transfer_in` at the destination location.
///
/// Note: In the current single-location implementation, this is a no-op
/// (stock stays in the same pool). A multi-location implementation would
/// use separate stock records per location.
///
/// ### Error Handling
/// - Returns `Either<Failure, Stock>`.
/// - [ServerFailure]: general exceptions (misnomer — these are local errors).
/// - [CacheFailure]: stock not found for a product.
/// - Stock quantities are clamped to zero minimum (no negative stock).
///
/// ### Relationship to Billing
/// - [BillRepositoryImpl.createBill] calls [adjustStock] with type 'sale'
///   for each line item.
/// - [BillRepositoryImpl.processReturn] calls [adjustStock] with type
///   'return' for each returned item.
///
/// ### New Product Stock Initialization
/// When adjusting stock for a product that has no existing stock record,
/// a new [Stock] entity is created. For sale/transfer_out operations, the
/// initial quantity is 0 (preventing overselling of unknown products).
class StockRepositoryImpl implements StockRepository {
  final StockRemoteDataSource remoteDataSource;
  final StockLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final _uuid = const Uuid();

  StockRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Returns a paginated list of stock records from the local database.
  ///
  /// Supports optional filtering by location and low-stock-only flag.
  /// Pagination is applied in-memory after fetching all matching records.
  @override
  Future<Either<Failure, List<Stock>>> getStock({
    String? locationId,
    bool lowStockOnly = false,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final localStock = await localDataSource.getStock(
        locationId: locationId,
        lowStockOnly: lowStockOnly,
      );

      final start = (page - 1) * perPage;
      if (start >= localStock.length) return const Right([]);
      final end = start + perPage;
      return Right(localStock.sublist(start, end > localStock.length ? localStock.length : end));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Returns the stock record for a specific product, or [CacheFailure] if
  /// no stock record exists for that product.
  @override
  Future<Either<Failure, Stock>> getStockByProductId(String productId) async {
    try {
      final stock = await localDataSource.getStockByProductId(productId);
      if (stock != null) {
        return Right(stock);
      }
      return Left(CacheFailure(message: 'Stock not found for product'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Adjusts stock quantity for a product based on the adjustment type.
  ///
  /// This is the core inventory operation. The logic:
  /// 1. Look up the existing stock record for the product.
  /// 2. If found, apply the adjustment:
  ///    - **Decrease** (sale, adjustment_down, transfer_out): quantity -= adjustment
  ///    - **Increase** (purchase, return, adjustment_up, transfer_in): quantity += adjustment
  /// 3. Clamp the result to a minimum of 0 (prevent negative stock).
  /// 4. Update the lastUpdated timestamp and persist.
  ///
  /// If no stock record exists, creates a new one:
  /// - For increase operations: stock = adjustment quantity.
  /// - For decrease operations: stock = 0 (cannot sell what isn't tracked).
  ///
  /// The [batchNumber] parameter allows batch/lot tracking. If provided,
  /// it updates the batch number on the existing stock record.
  @override
  Future<Either<Failure, Stock>> adjustStock({
    required String productId,
    required String adjustmentType,
    required int quantity,
    String? reason,
    String? batchNumber,
  }) async {
    try {
      final now = DateTime.now();
      var existingStock = await localDataSource.getStockByProductId(productId);

      int newQuantity;
      if (existingStock != null) {
        switch (adjustmentType) {
          case 'sale':
          case 'adjustment_down':
          case 'transfer_out':
            newQuantity = existingStock.quantity - quantity;
            break;
          case 'purchase':
          case 'return':
          case 'adjustment_up':
          case 'transfer_in':
            newQuantity = existingStock.quantity + quantity;
            break;
          default:
            newQuantity = existingStock.quantity;
        }

        final updatedStock = existingStock.copyWith(
          quantity: newQuantity < 0 ? 0 : newQuantity,
          batchNumber: batchNumber ?? existingStock.batchNumber,
          lastUpdated: now,
        );

        await localDataSource.saveStock(updatedStock);
        return Right(updatedStock);
      } else {
        final newStock = Stock(
          id: _uuid.v4(),
          productId: productId,
          productName: '',
          quantity: adjustmentType == 'sale' || adjustmentType == 'transfer_out'
              ? 0
              : quantity,
          batchNumber: batchNumber,
          lastUpdated: now,
        );
        await localDataSource.saveStock(newStock);
        return Right(newStock);
      }
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Transfers stock between locations by composing two [adjustStock] calls.
  ///
  /// 1. Decrements stock at the source ('transfer_out').
  /// 2. Increments stock at the destination ('transfer_in').
  ///
  /// Note: In the current single-location implementation, both calls operate
  /// on the same stock record, resulting in a net-zero change. A proper
  /// multi-location implementation would use location-specific stock records.
  @override
  Future<Either<Failure, Stock>> transferStock({
    required String productId,
    required int quantity,
    required String fromLocationId,
    required String toLocationId,
    String? batchNumber,
  }) async {
    try {
      await adjustStock(
        productId: productId,
        adjustmentType: 'transfer_out',
        quantity: quantity,
        batchNumber: batchNumber,
      );

      final result = await adjustStock(
        productId: productId,
        adjustmentType: 'transfer_in',
        quantity: quantity,
        batchNumber: batchNumber,
      );

      return result;
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Returns all products with stock levels at or below their reorder level.
  ///
  /// Used by the dashboard to display low-stock alerts. Delegates to the
  /// local datasource's lowStockOnly filter.
  @override
  Future<Either<Failure, List<Stock>>> getLowStockProducts() async {
    try {
      final lowStock = await localDataSource.getStock(lowStockOnly: true);
      return Right(lowStock);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
