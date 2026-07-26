part of 'orders_bloc.dart';

/// Base class for all orders-related BLoC events.
///
/// Events represent user actions or system triggers that cause state
/// transitions in the orders BLoC. Each concrete event carries the
/// data needed for its corresponding handler.
abstract class OrdersEvent extends Equatable {
  const OrdersEvent();

  @override
  List<Object> get props => [];
}

/// Triggers loading all sales orders from the local database.
class LoadSalesOrders extends OrdersEvent {
  const LoadSalesOrders();
}

/// Triggers loading all purchase orders from the local database.
class LoadPurchaseOrders extends OrdersEvent {
  const LoadPurchaseOrders();
}

/// Triggers a filtered search of sales orders.
///
/// [query] matches against order number and customer name.
/// [status] optionally filters by order status.
class SearchSalesOrders extends OrdersEvent {
  final String? query;
  final String? status;

  const SearchSalesOrders({this.query, this.status});

  @override
  List<Object> get props => [query ?? '', status ?? ''];
}

/// Triggers a filtered search of purchase orders.
///
/// [query] matches against order number and supplier name.
/// [status] optionally filters by order status.
class SearchPurchaseOrders extends OrdersEvent {
  final String? query;
  final String? status;

  const SearchPurchaseOrders({this.query, this.status});

  @override
  List<Object> get props => [query ?? '', status ?? ''];
}

/// Loads a single sales order by its unique identifier.
///
/// Used by the detail page and edit form to display complete order data.
class LoadSalesOrderById extends OrdersEvent {
  final String orderId;

  const LoadSalesOrderById({required this.orderId});

  @override
  List<Object> get props => [orderId];
}

/// Loads a single purchase order by its unique identifier.
///
/// Used by the detail page and edit form to display complete order data.
class LoadPurchaseOrderById extends OrdersEvent {
  final String orderId;

  const LoadPurchaseOrderById({required this.orderId});

  @override
  List<Object> get props => [orderId];
}

/// Requests creation of a new sales order.
///
/// The [order] should have its line items pre-populated and an order number
/// assigned before dispatching this event.
class CreateSalesOrder extends OrdersEvent {
  final SalesOrder order;

  const CreateSalesOrder({required this.order});

  @override
  List<Object> get props => [order];
}

/// Requests creation of a new purchase order.
///
/// The [order] should have its line items pre-populated and an order number
/// assigned before dispatching this event.
class CreatePurchaseOrder extends OrdersEvent {
  final PurchaseOrder order;

  const CreatePurchaseOrder({required this.order});

  @override
  List<Object> get props => [order];
}

/// Updates the status of an order (sales or purchase).
///
/// [orderId] is the order to update.
/// [orderType] is either 'sales' or 'purchase'.
/// [status] is the new status to apply.
class UpdateOrderStatus extends OrdersEvent {
  final String orderId;
  final String orderType;
  final String status;

  const UpdateOrderStatus({
    required this.orderId,
    required this.orderType,
    required this.status,
  });

  @override
  List<Object> get props => [orderId, orderType, status];
}

/// Deletes an order (sales or purchase) by its identifier.
///
/// [orderId] is the order to delete.
/// [orderType] is either 'sales' or 'purchase'.
class DeleteOrder extends OrdersEvent {
  final String orderId;
  final String orderType;

  const DeleteOrder({required this.orderId, required this.orderType});

  @override
  List<Object> get props => [orderId, orderType];
}

/// Converts a confirmed/delivered sales order into a sales bill.
///
/// The order must be in 'confirmed' or 'delivered' status.
class ConvertToBill extends OrdersEvent {
  final String orderId;

  const ConvertToBill({required this.orderId});

  @override
  List<Object> get props => [orderId];
}

/// Converts a confirmed/received purchase order into a stock receipt.
///
/// The order must be in 'confirmed' or 'received' status.
class ConvertToReceipt extends OrdersEvent {
  final String orderId;

  const ConvertToReceipt({required this.orderId});

  @override
  List<Object> get props => [orderId];
}
