import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/sales_order_entity.dart';
import '../entities/purchase_order_entity.dart';

/// Abstract repository contract for sales and purchase order operations.
///
/// Defines the data access boundary for the orders feature. Supports full
/// CRUD lifecycle for both sales orders (customer-facing) and purchase
/// orders (supplier-facing), including status transitions and conversion
/// to downstream documents (bills, stock receipts).
///
/// All methods return [Either<Failure, T>] for functional error handling
/// without exceptions, following the Clean Architecture data flow convention.
abstract class OrderRepository {
  // ---------------------------------------------------------------------------
  // Sales Orders
  // ---------------------------------------------------------------------------

  /// Retrieves all sales orders, optionally filtered by [search] query
  /// (matches order number or customer name) and [status].
  Future<Either<Failure, List<SalesOrder>>> getSalesOrders({
    String? search,
    String? status,
  });

  /// Retrieves a single sales order by its unique identifier.
  /// Returns the order with all line items populated.
  Future<Either<Failure, SalesOrder>> getSalesOrderById(String id);

  /// Creates a new sales order with its line items.
  /// Enqueues a sync item for server upload.
  Future<Either<Failure, SalesOrder>> createSalesOrder(SalesOrder order);

  /// Updates an existing sales order header and replaces all line items.
  /// Enqueues a sync item for server upload.
  Future<Either<Failure, SalesOrder>> updateSalesOrder(SalesOrder order);

  /// Updates only the status of a sales order (e.g., draft → confirmed).
  /// Enqueues a sync item for server upload.
  Future<Either<Failure, void>> updateSalesOrderStatus(
    String orderId,
    String status,
  );

  /// Hard-deletes a sales order and all associated line items.
  /// Enqueues a sync item for server propagation.
  Future<Either<Failure, void>> deleteSalesOrder(String id);

  /// Converts a confirmed/delivered sales order into a sales bill.
  /// Creates a new [Bills] record with the order's line items and financials.
  Future<Either<Failure, String>> convertSalesOrderToBill(String orderId);

  // ---------------------------------------------------------------------------
  // Purchase Orders
  // ---------------------------------------------------------------------------

  /// Retrieves all purchase orders, optionally filtered by [search] query
  /// (matches order number or supplier name) and [status].
  Future<Either<Failure, List<PurchaseOrder>>> getPurchaseOrders({
    String? search,
    String? status,
  });

  /// Retrieves a single purchase order by its unique identifier.
  /// Returns the order with all line items populated.
  Future<Either<Failure, PurchaseOrder>> getPurchaseOrderById(String id);

  /// Creates a new purchase order with its line items.
  /// Enqueues a sync item for server upload.
  Future<Either<Failure, PurchaseOrder>> createPurchaseOrder(
    PurchaseOrder order,
  );

  /// Updates an existing purchase order header and replaces all line items.
  /// Enqueues a sync item for server upload.
  Future<Either<Failure, PurchaseOrder>> updatePurchaseOrder(
    PurchaseOrder order,
  );

  /// Updates only the status of a purchase order (e.g., draft → confirmed).
  /// Enqueues a sync item for server upload.
  Future<Either<Failure, void>> updatePurchaseOrderStatus(
    String orderId,
    String status,
  );

  /// Hard-deletes a purchase order and all associated line items.
  /// Enqueues a sync item for server propagation.
  Future<Either<Failure, void>> deletePurchaseOrder(String id);

  /// Converts a confirmed/received purchase order into a stock receipt.
  /// Creates a new [Purchases] record and updates inventory stock levels.
  Future<Either<Failure, String>> convertPurchaseOrderToReceipt(String orderId);
}
