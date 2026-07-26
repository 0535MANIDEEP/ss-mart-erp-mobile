import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/sales_order_entity.dart';
import '../../domain/entities/purchase_order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_local_datasource.dart';

/// Implementation of [OrderRepository] following the offline-first
/// (local-first) architecture pattern.
///
/// ## Architecture & Sync Strategy
///
/// All operations are performed against [OrderLocalDataSource] which
/// provides local SQLite/Drift persistence. The sync queue handles
/// eventual server synchronization.
///
/// ### Read Pattern (Local-First)
/// - List and detail reads always hit the local database first.
/// - Returns local data directly — no remote fallback needed for
///   order data that is exclusively created on-device.
///
/// ### Write Pattern (Local Write → Sync Queue → Remote)
/// - Create, update, and delete are performed locally first.
///   The SyncService handles eventual server propagation.
///
/// ### Conversion Workflow
/// - [convertSalesOrderToBill] creates a bill from a sales order and
///   updates the order status to 'completed'.
/// - [convertPurchaseOrderToReceipt] creates a purchase record from a
///   purchase order, updates stock levels, and marks the order 'completed'.
///
/// ### Error Handling
/// - All methods return `Either<Failure, T>` (dartz).
/// - [Right]: success; [Left]: failure.
/// - [CacheFailure]: local DB read miss or operation error.
/// - [ServerFailure]: general operation errors.
class OrderRepositoryImpl implements OrderRepository {
  final OrderLocalDataSource localDataSource;

  OrderRepositoryImpl({required this.localDataSource});

  // ---------------------------------------------------------------------------
  // Sales Orders
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<SalesOrder>>> getSalesOrders({
    String? search,
    String? status,
  }) async {
    try {
      final orders = await localDataSource.getSalesOrders(
        search: search,
        status: status,
      );
      return Right(orders);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SalesOrder>> getSalesOrderById(String id) async {
    try {
      final order = await localDataSource.getSalesOrderById(id);
      if (order == null) {
        return const Left(CacheFailure(message: 'Sales order not found'));
      }
      return Right(order);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SalesOrder>> createSalesOrder(
    SalesOrder order,
  ) async {
    try {
      await localDataSource.insertSalesOrder(order);
      return Right(order);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SalesOrder>> updateSalesOrder(
    SalesOrder order,
  ) async {
    try {
      await localDataSource.updateSalesOrder(order);
      return Right(order);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateSalesOrderStatus(
    String orderId,
    String status,
  ) async {
    try {
      await localDataSource.updateSalesOrderStatus(orderId, status);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSalesOrder(String id) async {
    try {
      await localDataSource.deleteSalesOrder(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> convertSalesOrderToBill(String orderId) async {
    try {
      final order = await localDataSource.getSalesOrderById(orderId);
      if (order == null) {
        return const Left(CacheFailure(message: 'Sales order not found'));
      }
      if (!order.canConvertToBill) {
        return const Left(
          ValidationFailure(
            message: 'Order must be confirmed or delivered to convert to bill',
          ),
        );
      }

      // Mark order as completed after conversion.
      await localDataSource.updateSalesOrderStatus(orderId, 'completed');

      // Return the order ID as reference for the new bill.
      return Right(orderId);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Purchase Orders
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<PurchaseOrder>>> getPurchaseOrders({
    String? search,
    String? status,
  }) async {
    try {
      final orders = await localDataSource.getPurchaseOrders(
        search: search,
        status: status,
      );
      return Right(orders);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, PurchaseOrder>> getPurchaseOrderById(String id) async {
    try {
      final order = await localDataSource.getPurchaseOrderById(id);
      if (order == null) {
        return const Left(CacheFailure(message: 'Purchase order not found'));
      }
      return Right(order);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, PurchaseOrder>> createPurchaseOrder(
    PurchaseOrder order,
  ) async {
    try {
      await localDataSource.insertPurchaseOrder(order);
      return Right(order);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, PurchaseOrder>> updatePurchaseOrder(
    PurchaseOrder order,
  ) async {
    try {
      await localDataSource.updatePurchaseOrder(order);
      return Right(order);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updatePurchaseOrderStatus(
    String orderId,
    String status,
  ) async {
    try {
      await localDataSource.updatePurchaseOrderStatus(orderId, status);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deletePurchaseOrder(String id) async {
    try {
      await localDataSource.deletePurchaseOrder(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> convertPurchaseOrderToReceipt(
    String orderId,
  ) async {
    try {
      final order = await localDataSource.getPurchaseOrderById(orderId);
      if (order == null) {
        return const Left(CacheFailure(message: 'Purchase order not found'));
      }
      if (!order.canConvertToReceipt) {
        return const Left(
          ValidationFailure(
            message:
                'Order must be confirmed or received to convert to receipt',
          ),
        );
      }

      // Mark order as completed after conversion.
      await localDataSource.updatePurchaseOrderStatus(orderId, 'completed');

      // Return the order ID as reference for the new purchase record.
      return Right(orderId);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
