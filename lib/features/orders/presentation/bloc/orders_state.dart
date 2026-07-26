part of 'orders_bloc.dart';

/// Base class for all orders-related BLoC states.
///
/// States represent the current UI state of the orders feature. The BLoC
/// emits exactly one state at a time, and the presentation layer rebuilds
/// accordingly using [BlocBuilder] or [BlocListener].
abstract class OrdersState extends Equatable {
  const OrdersState();

  @override
  List<Object> get props => [];
}

/// Initial state before any events have been dispatched.
class OrdersInitial extends OrdersState {
  const OrdersInitial();
}

/// Emitted while any asynchronous operation is in progress.
///
/// The UI should display a loading indicator when this state is active.
class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

/// Emitted when a list of sales orders has been loaded successfully.
class SalesOrdersLoaded extends OrdersState {
  final List<SalesOrder> orders;

  const SalesOrdersLoaded({required this.orders});

  @override
  List<Object> get props => [orders];
}

/// Emitted when a list of purchase orders has been loaded successfully.
class PurchaseOrdersLoaded extends OrdersState {
  final List<PurchaseOrder> orders;

  const PurchaseOrdersLoaded({required this.orders});

  @override
  List<Object> get props => [orders];
}

/// Emitted when a single sales order detail has been loaded successfully.
class SalesOrderDetailLoaded extends OrdersState {
  final SalesOrder order;

  const SalesOrderDetailLoaded({required this.order});

  @override
  List<Object> get props => [order];
}

/// Emitted when a single purchase order detail has been loaded successfully.
class PurchaseOrderDetailLoaded extends OrdersState {
  final PurchaseOrder order;

  const PurchaseOrderDetailLoaded({required this.order});

  @override
  List<Object> get props => [order];
}

/// Emitted after a successful create, update, delete, or conversion operation.
///
/// Contains a user-friendly [message] suitable for display in a SnackBar.
class OrderOperationSuccess extends OrdersState {
  final String message;

  const OrderOperationSuccess({required this.message});

  @override
  List<Object> get props => [message];
}

/// Emitted when an operation fails.
///
/// Contains a user-friendly [message] describing the error. The UI should
/// display this in an error banner or SnackBar.
class OrdersError extends OrdersState {
  final String message;

  const OrdersError({required this.message});

  @override
  List<Object> get props => [message];
}
