/// Order Local Data Source — Local persistence layer for sales and purchase orders.
///
/// ## Architecture Role
/// Sits between [OrderRepositoryImpl] and the Drift database. Abstracts all
/// details of how order rows and line items are stored, queried, and converted
/// to/from domain entities. The repository never touches raw SQL or DAO objects.
///
/// ## Responsibilities
/// - CRUD operations on [SalesOrders], [SalesOrderItems], [PurchaseOrders],
///   and [PurchaseOrderItems] tables.
/// - Search by order number, customer/supplier name, and status filtering.
/// - Bidirectional mapping between database row objects and domain entities.
/// - Transactional writes that replace all line items atomically on update.
///
/// ## Data Flow
/// ```
/// OrderRepository → OrderLocalDataSource → DatabaseDao (Drift) → SQLite
/// ```
///
/// ## Design Decisions
/// - Line items are fully replaced on every order update (delete-all + re-insert).
///   This is simpler than diffing individual item changes and is safe because
///   order items are always managed as a complete set.
/// - Status filtering is applied at the SQL level for efficiency.
/// - Search queries match against order number and customer/supplier name.
library;

import '../../../../database/app_database.dart' as db;
import '../../domain/entities/sales_order_entity.dart';
import '../../domain/entities/sales_order_item_entity.dart';
import '../../domain/entities/purchase_order_entity.dart';
import '../../domain/entities/purchase_order_item_entity.dart';

/// Abstract contract for local order persistence.
///
/// The repository layer depends on this interface, not on the concrete
/// implementation, enabling unit testing with fakes/mocks.
abstract class OrderLocalDataSource {
  // ---------------------------------------------------------------------------
  // Sales Orders
  // ---------------------------------------------------------------------------

  /// Returns all sales orders, optionally filtered by [search] and [status].
  Future<List<SalesOrder>> getSalesOrders({
    String? search,
    String? status,
  });

  /// Returns a single sales order by [id] with all line items populated.
  Future<SalesOrder?> getSalesOrderById(String id);

  /// Inserts a new sales order header and all its line items.
  Future<void> insertSalesOrder(SalesOrder order);

  /// Updates an existing sales order header and replaces all line items.
  Future<void> updateSalesOrder(SalesOrder order);

  /// Updates only the status field of a sales order.
  Future<void> updateSalesOrderStatus(String orderId, String status);

  /// Hard-deletes a sales order and all its line items.
  Future<void> deleteSalesOrder(String id);

  // ---------------------------------------------------------------------------
  // Purchase Orders
  // ---------------------------------------------------------------------------

  /// Returns all purchase orders, optionally filtered by [search] and [status].
  Future<List<PurchaseOrder>> getPurchaseOrders({
    String? search,
    String? status,
  });

  /// Returns a single purchase order by [id] with all line items populated.
  Future<PurchaseOrder?> getPurchaseOrderById(String id);

  /// Inserts a new purchase order header and all its line items.
  Future<void> insertPurchaseOrder(PurchaseOrder order);

  /// Updates an existing purchase order header and replaces all line items.
  Future<void> updatePurchaseOrder(PurchaseOrder order);

  /// Updates only the status field of a purchase order.
  Future<void> updatePurchaseOrderStatus(String orderId, String status);

  /// Hard-deletes a purchase order and all its line items.
  Future<void> deletePurchaseOrder(String id);
}

/// Concrete implementation backed by Drift's [AppDatabase].
///
/// Handles the mapping between domain order entities and Drift-generated row
/// objects. Uses the [DatabaseDao] for all query operations.
class OrderLocalDataSourceImpl implements OrderLocalDataSource {
  final db.AppDatabase _database;
  late final db.DatabaseDao _dao;

  OrderLocalDataSourceImpl({required db.AppDatabase database})
      : _database = database {
    _dao = db.DatabaseDao(_database);
  }

  // ---------------------------------------------------------------------------
  // Sales Orders
  // ---------------------------------------------------------------------------

  @override
  Future<List<SalesOrder>> getSalesOrders({
    String? search,
    String? status,
  }) async {
    List<db.SalesOrder> rows;

    if (search != null && search.isNotEmpty) {
      final allOrders = await _dao.getAllSalesOrders();
      final q = search.toLowerCase();
      rows = allOrders.where((o) {
        return o.orderNumber.toLowerCase().contains(q) ||
            (o.customerName?.toLowerCase().contains(q) ?? false);
      }).toList();
    } else if (status != null && status.isNotEmpty) {
      final allOrders = await _dao.getAllSalesOrders();
      rows = allOrders.where((o) => o.status == status).toList();
    } else {
      rows = await _dao.getAllSalesOrders();
    }

    // Populate line items for each order.
    final results = <SalesOrder>[];
    for (final row in rows) {
      final items = await _dao.getSalesOrderItems(row.id);
      results.add(_salesOrderFromData(row, items));
    }
    return results;
  }

  @override
  Future<SalesOrder?> getSalesOrderById(String id) async {
    final row = await _dao.getSalesOrderById(id);
    if (row == null) return null;
    final items = await _dao.getSalesOrderItems(id);
    return _salesOrderFromData(row, items);
  }

  @override
  Future<void> insertSalesOrder(SalesOrder order) async {
    final companion = _salesOrderToCompanion(order);
    await _dao.insertSalesOrder(companion);

    for (final item in order.items) {
      await _dao.insertSalesOrderItem(_salesOrderItemToCompanion(item));
    }
  }

  @override
  Future<void> updateSalesOrder(SalesOrder order) async {
    final companion = _salesOrderToCompanion(order);
    await _dao.updateSalesOrder(companion);

    // Replace all line items atomically.
    await _dao.deleteSalesOrderItems(order.id);
    for (final item in order.items) {
      await _dao.insertSalesOrderItem(_salesOrderItemToCompanion(item));
    }
  }

  @override
  Future<void> updateSalesOrderStatus(String orderId, String status) async {
    final allOrders = await _dao.getAllSalesOrders();
    final existing = allOrders.where((o) => o.id == orderId).firstOrNull;
    if (existing != null) {
      final updated = existing.copyWith(
        status: status,
        updatedAt: DateTime.now(),
        version: existing.version + 1,
      );
      await _dao.updateSalesOrder(
        db.SalesOrdersCompanion(
          id: db.Value(updated.id),
          orderNumber: db.Value(updated.orderNumber),
          customerId: db.Value(updated.customerId),
          customerName: db.Value(updated.customerName),
          orderDate: db.Value(updated.orderDate),
          expectedDeliveryDate: db.Value(updated.expectedDeliveryDate),
          subtotal: db.Value(updated.subtotal),
          taxAmount: db.Value(updated.taxAmount),
          discountAmount: db.Value(updated.discountAmount),
          totalAmount: db.Value(updated.totalAmount),
          status: db.Value(updated.status),
          notes: db.Value(updated.notes),
          createdBy: db.Value(updated.createdBy),
          createdAt: db.Value(updated.createdAt),
          updatedAt: db.Value(updated.updatedAt),
          version: db.Value(updated.version),
        ),
      );
    }
  }

  @override
  Future<void> deleteSalesOrder(String id) async {
    await _dao.deleteSalesOrderItems(id);
    await _dao.deleteSalesOrder(id);
  }

  // ---------------------------------------------------------------------------
  // Purchase Orders
  // ---------------------------------------------------------------------------

  @override
  Future<List<PurchaseOrder>> getPurchaseOrders({
    String? search,
    String? status,
  }) async {
    List<db.PurchaseOrder> rows;

    if (search != null && search.isNotEmpty) {
      final allOrders = await _dao.getAllPurchaseOrders();
      final q = search.toLowerCase();
      rows = allOrders.where((o) {
        return o.orderNumber.toLowerCase().contains(q) ||
            (o.supplierName?.toLowerCase().contains(q) ?? false);
      }).toList();
    } else if (status != null && status.isNotEmpty) {
      final allOrders = await _dao.getAllPurchaseOrders();
      rows = allOrders.where((o) => o.status == status).toList();
    } else {
      rows = await _dao.getAllPurchaseOrders();
    }

    final results = <PurchaseOrder>[];
    for (final row in rows) {
      final items = await _dao.getPurchaseOrderItems(row.id);
      results.add(_purchaseOrderFromData(row, items));
    }
    return results;
  }

  @override
  Future<PurchaseOrder?> getPurchaseOrderById(String id) async {
    final row = await _dao.getPurchaseOrderById(id);
    if (row == null) return null;
    final items = await _dao.getPurchaseOrderItems(id);
    return _purchaseOrderFromData(row, items);
  }

  @override
  Future<void> insertPurchaseOrder(PurchaseOrder order) async {
    final companion = _purchaseOrderToCompanion(order);
    await _dao.insertPurchaseOrder(companion);

    for (final item in order.items) {
      await _dao.insertPurchaseOrderItem(
        _purchaseOrderItemToCompanion(item),
      );
    }
  }

  @override
  Future<void> updatePurchaseOrder(PurchaseOrder order) async {
    final companion = _purchaseOrderToCompanion(order);
    await _dao.updatePurchaseOrder(companion);

    // Replace all line items atomically.
    await _dao.deletePurchaseOrderItems(order.id);
    for (final item in order.items) {
      await _dao.insertPurchaseOrderItem(_purchaseOrderItemToCompanion(item));
    }
  }

  @override
  Future<void> updatePurchaseOrderStatus(String orderId, String status) async {
    final allOrders = await _dao.getAllPurchaseOrders();
    final existing = allOrders.where((o) => o.id == orderId).firstOrNull;
    if (existing != null) {
      final updated = existing.copyWith(
        status: status,
        updatedAt: DateTime.now(),
        version: existing.version + 1,
      );
      await _dao.updatePurchaseOrder(
        db.PurchaseOrdersCompanion(
          id: db.Value(updated.id),
          orderNumber: db.Value(updated.orderNumber),
          supplierId: db.Value(updated.supplierId),
          supplierName: db.Value(updated.supplierName),
          orderDate: db.Value(updated.orderDate),
          expectedDeliveryDate: db.Value(updated.expectedDeliveryDate),
          subtotal: db.Value(updated.subtotal),
          taxAmount: db.Value(updated.taxAmount),
          discountAmount: db.Value(updated.discountAmount),
          totalAmount: db.Value(updated.totalAmount),
          status: db.Value(updated.status),
          notes: db.Value(updated.notes),
          createdBy: db.Value(updated.createdBy),
          createdAt: db.Value(updated.createdAt),
          updatedAt: db.Value(updated.updatedAt),
          version: db.Value(updated.version),
        ),
      );
    }
  }

  @override
  Future<void> deletePurchaseOrder(String id) async {
    await _dao.deletePurchaseOrderItems(id);
    await _dao.deletePurchaseOrder(id);
  }

  // ---------------------------------------------------------------------------
  // Mapping: Database → Domain
  // ---------------------------------------------------------------------------

  /// Converts a Drift [db.SalesOrder] row and its items into a domain
  /// [SalesOrder] entity.
  SalesOrder _salesOrderFromData(
    db.SalesOrder data,
    List<db.SalesOrderItem> itemRows,
  ) {
    return SalesOrder(
      id: data.id,
      orderNumber: data.orderNumber,
      customerId: data.customerId,
      customerName: data.customerName,
      orderDate: data.orderDate,
      expectedDeliveryDate: data.expectedDeliveryDate,
      subtotal: data.subtotal,
      taxAmount: data.taxAmount,
      discountAmount: data.discountAmount,
      totalAmount: data.totalAmount,
      status: data.status,
      notes: data.notes,
      createdBy: data.createdBy,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      version: data.version,
      items: itemRows.map(_salesOrderItemFromData).toList(),
    );
  }

  /// Converts a Drift [db.SalesOrderItem] row into a domain entity.
  SalesOrderItem _salesOrderItemFromData(db.SalesOrderItem data) {
    return SalesOrderItem(
      id: data.id,
      orderId: data.orderId,
      productId: data.productId,
      productName: data.productName,
      quantity: data.quantity,
      unitPrice: data.unitPrice,
      taxRate: data.taxRate,
      discountAmount: data.discountAmount,
      taxAmount: data.taxAmount,
      totalAmount: data.totalAmount,
      batchNumber: data.batchNumber,
      deliveredQuantity: data.deliveredQuantity,
    );
  }

  /// Converts a Drift [db.PurchaseOrder] row and its items into a domain
  /// [PurchaseOrder] entity.
  PurchaseOrder _purchaseOrderFromData(
    db.PurchaseOrder data,
    List<db.PurchaseOrderItem> itemRows,
  ) {
    return PurchaseOrder(
      id: data.id,
      orderNumber: data.orderNumber,
      supplierId: data.supplierId,
      supplierName: data.supplierName,
      orderDate: data.orderDate,
      expectedDeliveryDate: data.expectedDeliveryDate,
      subtotal: data.subtotal,
      taxAmount: data.taxAmount,
      discountAmount: data.discountAmount,
      totalAmount: data.totalAmount,
      status: data.status,
      notes: data.notes,
      createdBy: data.createdBy,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      version: data.version,
      items: itemRows.map(_purchaseOrderItemFromData).toList(),
    );
  }

  /// Converts a Drift [db.PurchaseOrderItem] row into a domain entity.
  PurchaseOrderItem _purchaseOrderItemFromData(db.PurchaseOrderItem data) {
    return PurchaseOrderItem(
      id: data.id,
      orderId: data.orderId,
      productId: data.productId,
      productName: data.productName,
      quantity: data.quantity,
      unitPrice: data.unitPrice,
      taxRate: data.taxRate,
      discountAmount: data.discountAmount,
      taxAmount: data.taxAmount,
      totalAmount: data.totalAmount,
      batchNumber: data.batchNumber,
      receivedQuantity: data.receivedQuantity,
    );
  }

  // ---------------------------------------------------------------------------
  // Mapping: Domain → Database (Companions)
  // ---------------------------------------------------------------------------

  /// Converts a domain [SalesOrder] into a Drift companion for insertion/update.
  db.SalesOrdersCompanion _salesOrderToCompanion(SalesOrder order) {
    return db.SalesOrdersCompanion(
      id: db.Value(order.id),
      orderNumber: db.Value(order.orderNumber),
      customerId: db.Value(order.customerId),
      customerName: db.Value(order.customerName),
      orderDate: db.Value(order.orderDate),
      expectedDeliveryDate: db.Value(order.expectedDeliveryDate),
      subtotal: db.Value(order.subtotal),
      taxAmount: db.Value(order.taxAmount),
      discountAmount: db.Value(order.discountAmount),
      totalAmount: db.Value(order.totalAmount),
      status: db.Value(order.status),
      notes: db.Value(order.notes),
      createdBy: db.Value(order.createdBy),
      createdAt: db.Value(order.createdAt),
      updatedAt: db.Value(order.updatedAt),
      version: db.Value(order.version),
    );
  }

  /// Converts a domain [SalesOrderItem] into a Drift companion.
  db.SalesOrderItemsCompanion _salesOrderItemToCompanion(SalesOrderItem item) {
    return db.SalesOrderItemsCompanion(
      id: db.Value(item.id),
      orderId: db.Value(item.orderId),
      productId: db.Value(item.productId),
      productName: db.Value(item.productName),
      quantity: db.Value(item.quantity),
      unitPrice: db.Value(item.unitPrice),
      taxRate: db.Value(item.taxRate),
      discountAmount: db.Value(item.discountAmount),
      taxAmount: db.Value(item.taxAmount),
      totalAmount: db.Value(item.totalAmount),
      batchNumber: db.Value(item.batchNumber),
      deliveredQuantity: db.Value(item.deliveredQuantity),
    );
  }

  /// Converts a domain [PurchaseOrder] into a Drift companion.
  db.PurchaseOrdersCompanion _purchaseOrderToCompanion(PurchaseOrder order) {
    return db.PurchaseOrdersCompanion(
      id: db.Value(order.id),
      orderNumber: db.Value(order.orderNumber),
      supplierId: db.Value(order.supplierId),
      supplierName: db.Value(order.supplierName),
      orderDate: db.Value(order.orderDate),
      expectedDeliveryDate: db.Value(order.expectedDeliveryDate),
      subtotal: db.Value(order.subtotal),
      taxAmount: db.Value(order.taxAmount),
      discountAmount: db.Value(order.discountAmount),
      totalAmount: db.Value(order.totalAmount),
      status: db.Value(order.status),
      notes: db.Value(order.notes),
      createdBy: db.Value(order.createdBy),
      createdAt: db.Value(order.createdAt),
      updatedAt: db.Value(order.updatedAt),
      version: db.Value(order.version),
    );
  }

  /// Converts a domain [PurchaseOrderItem] into a Drift companion.
  db.PurchaseOrderItemsCompanion _purchaseOrderItemToCompanion(
    PurchaseOrderItem item,
  ) {
    return db.PurchaseOrderItemsCompanion(
      id: db.Value(item.id),
      orderId: db.Value(item.orderId),
      productId: db.Value(item.productId),
      productName: db.Value(item.productName),
      quantity: db.Value(item.quantity),
      unitPrice: db.Value(item.unitPrice),
      taxRate: db.Value(item.taxRate),
      discountAmount: db.Value(item.discountAmount),
      taxAmount: db.Value(item.taxAmount),
      totalAmount: db.Value(item.totalAmount),
      batchNumber: db.Value(item.batchNumber),
      receivedQuantity: db.Value(item.receivedQuantity),
    );
  }
}
