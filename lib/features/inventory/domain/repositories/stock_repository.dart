import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/stock_entity.dart';

/// Abstract repository contract for inventory stock data operations.
///
/// This interface defines the data access boundary for the inventory feature.
/// Stock management tracks physical product quantities across warehouse
/// locations, supports batch/lot tracking, and handles adjustments,
/// transfers, and low-stock alerts.
///
/// All methods return [Either<Failure, T>] to enable functional error handling
/// without exceptions, following the Clean Architecture data flow convention.
abstract class StockRepository {
  /// Retrieves a paginated list of stock records with optional filtering.
  ///
  /// [locationId] filters to a specific warehouse location.
  /// [lowStockOnly] when true, returns only products at or below their reorder level.
  Future<Either<Failure, List<Stock>>> getStock({
    String? locationId,
    bool lowStockOnly = false,
    int page = 1,
    int perPage = 20,
  });

  /// Retrieves the stock record for a specific product.
  /// Throws [CacheFailure] if no stock record exists for the product.
  Future<Either<Failure, Stock>> getStockByProductId(String productId);

  /// Adjusts stock quantity for a product.
  ///
  /// [adjustmentType] categorizes the adjustment: 'purchase_received',
  /// 'sale_returned', 'damaged', 'expired', 'manual_correction', etc.
  /// [quantity] is the absolute adjustment amount (sign determined by type).
  /// [reason] provides audit trail context for manual adjustments.
  /// Enqueues a sync item for server upload.
  Future<Either<Failure, Stock>> adjustStock({
    required String productId,
    required String adjustmentType,
    required int quantity,
    String? reason,
    String? batchNumber,
  });

  /// Transfers stock between warehouse locations.
  ///
  /// Atomically decrements from [fromLocationId] and increments at [toLocationId].
  /// Enqueues sync items for both stock records.
  Future<Either<Failure, Stock>> transferStock({
    required String productId,
    required int quantity,
    required String fromLocationId,
    required String toLocationId,
    String? batchNumber,
  });

  /// Retrieves all products that are at or below their reorder threshold.
  /// Used by the dashboard low-stock alert widget.
  Future<Either<Failure, List<Stock>>> getLowStockProducts();
}
