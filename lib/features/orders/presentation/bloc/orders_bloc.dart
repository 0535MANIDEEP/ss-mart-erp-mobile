import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/sales_order_entity.dart';
import '../../domain/entities/purchase_order_entity.dart';
import '../../domain/usecases/get_sales_orders_usecase.dart';
import '../../domain/usecases/get_purchase_orders_usecase.dart';
import '../../domain/usecases/create_sales_order_usecase.dart';
import '../../domain/usecases/create_purchase_order_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';
import '../../domain/usecases/delete_order_usecase.dart';
import '../../domain/usecases/get_sales_order_by_id_usecase.dart';
import '../../domain/usecases/get_purchase_order_by_id_usecase.dart';
import '../../domain/usecases/convert_sales_order_to_bill_usecase.dart';
import '../../domain/usecases/convert_purchase_order_to_receipt_usecase.dart';

part 'orders_event.dart';
part 'orders_state.dart';

/// BLoC (Business Logic Component) for managing sales and purchase orders.
///
/// Centralizes all order-related state management for the orders feature,
/// including listing, creating, updating status, deleting, and converting
/// orders to downstream documents (bills, stock receipts).
///
/// ## State Management Pattern
///
/// Follows the established BLoC pattern used across the application:
/// - Events are immutable classes extending [OrdersEvent].
/// - State is an immutable class hierarchy extending [OrdersState].
/// - Each event has a dedicated handler method registered in the constructor.
///
/// ## Usage
///
/// ```dart
/// BlocProvider(
///   create: (_) => sl<OrdersBloc>()..add(const LoadSalesOrders()),
///   child: OrdersPage(),
/// )
/// ```
class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  final GetSalesOrdersUseCase getSalesOrdersUseCase;
  final GetPurchaseOrdersUseCase getPurchaseOrdersUseCase;
  final GetSalesOrderByIdUseCase getSalesOrderByIdUseCase;
  final GetPurchaseOrderByIdUseCase getPurchaseOrderByIdUseCase;
  final CreateSalesOrderUseCase createSalesOrderUseCase;
  final CreatePurchaseOrderUseCase createPurchaseOrderUseCase;
  final UpdateOrderStatusUseCase updateOrderStatusUseCase;
  final DeleteOrderUseCase deleteOrderUseCase;
  final ConvertSalesOrderToBillUseCase convertSalesOrderToBillUseCase;
  final ConvertPurchaseOrderToReceiptUseCase
      convertPurchaseOrderToReceiptUseCase;

  OrdersBloc({
    required this.getSalesOrdersUseCase,
    required this.getPurchaseOrdersUseCase,
    required this.getSalesOrderByIdUseCase,
    required this.getPurchaseOrderByIdUseCase,
    required this.createSalesOrderUseCase,
    required this.createPurchaseOrderUseCase,
    required this.updateOrderStatusUseCase,
    required this.deleteOrderUseCase,
    required this.convertSalesOrderToBillUseCase,
    required this.convertPurchaseOrderToReceiptUseCase,
  }) : super(const OrdersInitial()) {
    on<LoadSalesOrders>(_onLoadSalesOrders);
    on<LoadPurchaseOrders>(_onLoadPurchaseOrders);
    on<SearchSalesOrders>(_onSearchSalesOrders);
    on<SearchPurchaseOrders>(_onSearchPurchaseOrders);
    on<LoadSalesOrderById>(_onLoadSalesOrderById);
    on<LoadPurchaseOrderById>(_onLoadPurchaseOrderById);
    on<CreateSalesOrder>(_onCreateSalesOrder);
    on<CreatePurchaseOrder>(_onCreatePurchaseOrder);
    on<UpdateOrderStatus>(_onUpdateOrderStatus);
    on<DeleteOrder>(_onDeleteOrder);
    on<ConvertToBill>(_onConvertToBill);
    on<ConvertToReceipt>(_onConvertToReceipt);
  }

  // ---------------------------------------------------------------------------
  // Sales Orders Handlers
  // ---------------------------------------------------------------------------

  Future<void> _onLoadSalesOrders(
    LoadSalesOrders event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    final result = await getSalesOrdersUseCase(
      const GetSalesOrdersParams(),
    );
    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (orders) => emit(SalesOrdersLoaded(orders: orders)),
    );
  }

  Future<void> _onSearchSalesOrders(
    SearchSalesOrders event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    final result = await getSalesOrdersUseCase(
      GetSalesOrdersParams(search: event.query, status: event.status),
    );
    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (orders) => emit(SalesOrdersLoaded(orders: orders)),
    );
  }

  Future<void> _onLoadSalesOrderById(
    LoadSalesOrderById event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    final result = await getSalesOrderByIdUseCase(event.orderId);
    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (order) => emit(SalesOrderDetailLoaded(order: order)),
    );
  }

  Future<void> _onCreateSalesOrder(
    CreateSalesOrder event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    final result = await createSalesOrderUseCase(
      CreateSalesOrderParams(order: event.order),
    );
    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (_) => emit(
        const OrderOperationSuccess(message: 'Sales order created successfully'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Purchase Orders Handlers
  // ---------------------------------------------------------------------------

  Future<void> _onLoadPurchaseOrders(
    LoadPurchaseOrders event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    final result = await getPurchaseOrdersUseCase(
      const GetPurchaseOrdersParams(),
    );
    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (orders) => emit(PurchaseOrdersLoaded(orders: orders)),
    );
  }

  Future<void> _onSearchPurchaseOrders(
    SearchPurchaseOrders event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    final result = await getPurchaseOrdersUseCase(
      GetPurchaseOrdersParams(search: event.query, status: event.status),
    );
    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (orders) => emit(PurchaseOrdersLoaded(orders: orders)),
    );
  }

  Future<void> _onLoadPurchaseOrderById(
    LoadPurchaseOrderById event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    final result = await getPurchaseOrderByIdUseCase(event.orderId);
    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (order) => emit(PurchaseOrderDetailLoaded(order: order)),
    );
  }

  Future<void> _onCreatePurchaseOrder(
    CreatePurchaseOrder event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    final result = await createPurchaseOrderUseCase(
      CreatePurchaseOrderParams(order: event.order),
    );
    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (_) => emit(
        const OrderOperationSuccess(
          message: 'Purchase order created successfully',
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status & Conversion Handlers
  // ---------------------------------------------------------------------------

  Future<void> _onUpdateOrderStatus(
    UpdateOrderStatus event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    final result = await updateOrderStatusUseCase(
      UpdateOrderStatusParams(
        orderId: event.orderId,
        orderType: event.orderType,
        status: event.status,
      ),
    );
    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (_) => emit(
        OrderOperationSuccess(
          message: 'Order status updated to ${event.status}',
        ),
      ),
    );
  }

  Future<void> _onDeleteOrder(
    DeleteOrder event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    final result = await deleteOrderUseCase(
      DeleteOrderParams(orderId: event.orderId, orderType: event.orderType),
    );
    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (_) => emit(
        const OrderOperationSuccess(message: 'Order deleted successfully'),
      ),
    );
  }

  Future<void> _onConvertToBill(
    ConvertToBill event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    final result = await convertSalesOrderToBillUseCase(event.orderId);
    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (billId) => emit(
        OrderOperationSuccess(
          message: 'Sales order converted to bill successfully',
        ),
      ),
    );
  }

  Future<void> _onConvertToReceipt(
    ConvertToReceipt event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    final result = await convertPurchaseOrderToReceiptUseCase(event.orderId);
    result.fold(
      (failure) => emit(OrdersError(message: failure.message)),
      (receiptId) => emit(
        const OrderOperationSuccess(
          message: 'Purchase order converted to stock receipt successfully',
        ),
      ),
    );
  }
}
