import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/purchase_entity.dart';

/// Abstract repository contract for purchase order (procurement) data operations.
///
/// This interface defines the data access boundary for the purchases feature.
/// Purchase orders track inbound inventory from suppliers. The [receivePurchase]
/// operation triggers stock level updates in the inventory module.
///
/// All methods return [Either<Failure, T>] to enable functional error handling
/// without exceptions, following the Clean Architecture data flow convention.
abstract class PurchaseRepository {
  /// Retrieves a paginated list of purchase orders with optional filtering.
  ///
  /// [supplierId] filters orders for a specific supplier.
  /// [startDate] / [endDate] filter orders within a date range (ISO 8601 strings).
  Future<Either<Failure, List<Purchase>>> getPurchases({
    String? supplierId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 20,
  });

  /// Retrieves a single purchase order by its unique identifier.
  Future<Either<Failure, Purchase>> getPurchaseById(String id);

  /// Creates a new purchase order with all line items.
  /// Enqueues a sync item for server upload.
  Future<Either<Failure, Purchase>> createPurchase(Purchase purchase);

  /// Updates an existing purchase order (only while in 'pending' status).
  /// Enqueues a sync item for server upload.
  Future<Either<Failure, Purchase>> updatePurchase(Purchase purchase);

  /// Marks a purchase order as received and updates inventory stock levels.
  ///
  /// [receivedItems] specifies the actual quantities received per line item
  /// (which may differ from ordered quantities). This operation atomically:
  /// - Updates the purchase status to 'received'
  /// - Adjusts stock levels for each received item
  /// - Enqueues sync items for both purchase and stock changes
  Future<Either<Failure, Purchase>> receivePurchase({
    required String purchaseId,
    required List<PurchaseItem> receivedItems,
  });
}
