import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/sales_order_entity.dart';
import '../../domain/entities/purchase_order_entity.dart';
import '../bloc/orders_bloc.dart';
import 'sales_order_form_page.dart';
import 'purchase_order_form_page.dart';
import '../../../../injection/injection_container.dart';

/// Detail page showing complete information for either a sales or purchase order.
///
/// Displays:
/// - Order header (number, date, status, party name)
/// - All line items with quantities and totals
/// - Order financial summary (subtotal, tax, discount, total)
/// - Status action buttons (confirm, deliver, receive, cancel)
/// - Conversion actions (to bill, to stock receipt)
/// - Delete action
///
/// The [orderType] parameter determines whether this is a sales order ('sales')
/// or purchase order ('purchase') detail view.
class OrderDetailPage extends StatefulWidget {
  /// The unique identifier of the order to display.
  final String orderId;

  /// The type of order: 'sales' or 'purchase'.
  final String orderType;

  const OrderDetailPage({
    super.key,
    required this.orderId,
    required this.orderType,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  void _loadOrder() {
    final bloc = context.read<OrdersBloc>();
    if (widget.orderType == 'sales') {
      bloc.add(LoadSalesOrderById(orderId: widget.orderId));
    } else {
      bloc.add(LoadPurchaseOrderById(orderId: widget.orderId));
    }
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text('Are you sure you want to delete this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<OrdersBloc>().add(
                    DeleteOrder(
                      orderId: widget.orderId,
                      orderType: widget.orderType,
                    ),
                  );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrdersBloc>(),
      child: BlocConsumer<OrdersBloc, OrdersState>(
        listener: (context, state) {
          if (state is OrderOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          } else if (state is OrdersError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is OrdersLoading) {
            return Scaffold(
              appBar: AppBar(title: const Text('Order Detail')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (state is SalesOrderDetailLoaded && widget.orderType == 'sales') {
            return _buildSalesOrderDetail(context, state.order);
          }

          if (state is PurchaseOrderDetailLoaded &&
              widget.orderType == 'purchase') {
            return _buildPurchaseOrderDetail(context, state.order);
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Order Detail')),
            body: const Center(child: Text('Order not found')),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sales Order Detail
  // ---------------------------------------------------------------------------

  Widget _buildSalesOrderDetail(BuildContext context, SalesOrder order) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderNumber),
        actions: [
          if (order.canUpdateStatus)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute<dynamic>(
                    builder: (_) => SalesOrderFormPage(order: order),
                  ),
                );
                if (result == true && mounted) _loadOrder();
              },
            ),
          if (!order.isCancelled && !order.isCompleted)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and order info
            _buildHeaderCard(
              orderNumber: order.orderNumber,
              status: order.status,
              date: dateFormat.format(order.orderDate),
              deliveryDate: order.expectedDeliveryDate != null
                  ? dateFormat.format(order.expectedDeliveryDate!)
                  : null,
              partyName: order.customerName ?? 'Walk-in Customer',
              partyLabel: 'Customer',
            ),
            const SizedBox(height: 16),

            // Line items
            _buildSectionTitle('Order Items'),
            const SizedBox(height: 8),
            ...order.items.map(
              (item) => _buildItemTile(
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                totalAmount: item.totalAmount,
                deliveredQty: item.deliveredQuantity,
              ),
            ),
            const SizedBox(height: 16),

            // Financial summary
            _buildFinancialSummary(
              subtotal: order.subtotal,
              taxAmount: order.taxAmount,
              discountAmount: order.discountAmount,
              totalAmount: order.totalAmount,
            ),

            // Notes
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionTitle('Notes'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(order.notes!),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action buttons
            _buildSalesOrderActions(context, order),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesOrderActions(BuildContext context, SalesOrder order) {
    final actions = <Widget>[];

    if (order.isDraft) {
      actions.add(
        _buildActionButton(
          label: 'Confirm Order',
          color: Colors.blue,
          onPressed: () {
            context.read<OrdersBloc>().add(
                  UpdateOrderStatus(
                    orderId: order.id,
                    orderType: 'sales',
                    status: 'confirmed',
                  ),
                );
          },
        ),
      );
    }

    if (order.isConfirmed) {
      actions.add(
        _buildActionButton(
          label: 'Mark as Dispatched',
          color: Colors.purple,
          onPressed: () {
            context.read<OrdersBloc>().add(
                  UpdateOrderStatus(
                    orderId: order.id,
                    orderType: 'sales',
                    status: 'dispatched',
                  ),
                );
          },
        ),
      );
    }

    if (order.isConfirmed || order.status == 'dispatched') {
      actions.add(
        _buildActionButton(
          label: 'Mark as Delivered',
          color: Colors.teal,
          onPressed: () {
            context.read<OrdersBloc>().add(
                  UpdateOrderStatus(
                    orderId: order.id,
                    orderType: 'sales',
                    status: 'delivered',
                  ),
                );
          },
        ),
      );
    }

    if (order.canConvertToBill) {
      actions.add(
        _buildActionButton(
          label: 'Convert to Bill',
          color: const Color(0xFF1B5E20),
          onPressed: () {
            context.read<OrdersBloc>().add(
                  ConvertToBill(orderId: order.id),
                );
          },
        ),
      );
    }

    if (!order.isCancelled && !order.isCompleted) {
      actions.add(
        _buildActionButton(
          label: 'Cancel Order',
          color: Colors.red,
          onPressed: () {
            context.read<OrdersBloc>().add(
                  UpdateOrderStatus(
                    orderId: order.id,
                    orderType: 'sales',
                    status: 'cancelled',
                  ),
                );
          },
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(children: actions);
  }

  // ---------------------------------------------------------------------------
  // Purchase Order Detail
  // ---------------------------------------------------------------------------

  Widget _buildPurchaseOrderDetail(
    BuildContext context,
    PurchaseOrder order,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderNumber),
        actions: [
          if (order.canUpdateStatus)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute<dynamic>(
                    builder: (_) => PurchaseOrderFormPage(order: order),
                  ),
                );
                if (result == true && mounted) _loadOrder();
              },
            ),
          if (!order.isCancelled && !order.isCompleted)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(
              orderNumber: order.orderNumber,
              status: order.status,
              date: dateFormat.format(order.orderDate),
              deliveryDate: order.expectedDeliveryDate != null
                  ? dateFormat.format(order.expectedDeliveryDate!)
                  : null,
              partyName: order.supplierName ?? 'Unknown Supplier',
              partyLabel: 'Supplier',
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Order Items'),
            const SizedBox(height: 8),
            ...order.items.map(
              (item) => _buildItemTile(
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                totalAmount: item.totalAmount,
                receivedQty: item.receivedQuantity,
              ),
            ),
            const SizedBox(height: 16),

            _buildFinancialSummary(
              subtotal: order.subtotal,
              taxAmount: order.taxAmount,
              discountAmount: order.discountAmount,
              totalAmount: order.totalAmount,
            ),

            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionTitle('Notes'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(order.notes!),
                ),
              ),
            ],

            const SizedBox(height: 24),

            _buildPurchaseOrderActions(context, order),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseOrderActions(
    BuildContext context,
    PurchaseOrder order,
  ) {
    final actions = <Widget>[];

    if (order.isDraft) {
      actions.add(
        _buildActionButton(
          label: 'Confirm Order',
          color: Colors.blue,
          onPressed: () {
            context.read<OrdersBloc>().add(
                  UpdateOrderStatus(
                    orderId: order.id,
                    orderType: 'purchase',
                    status: 'confirmed',
                  ),
                );
          },
        ),
      );
    }

    if (order.isConfirmed) {
      actions.add(
        _buildActionButton(
          label: 'Mark as Received',
          color: Colors.purple,
          onPressed: () {
            context.read<OrdersBloc>().add(
                  UpdateOrderStatus(
                    orderId: order.id,
                    orderType: 'purchase',
                    status: 'received',
                  ),
                );
          },
        ),
      );
    }

    if (order.canConvertToReceipt) {
      actions.add(
        _buildActionButton(
          label: 'Convert to Stock Receipt',
          color: const Color(0xFF1B5E20),
          onPressed: () {
            context.read<OrdersBloc>().add(
                  ConvertToReceipt(orderId: order.id),
                );
          },
        ),
      );
    }

    if (!order.isCancelled && !order.isCompleted) {
      actions.add(
        _buildActionButton(
          label: 'Cancel Order',
          color: Colors.red,
          onPressed: () {
            context.read<OrdersBloc>().add(
                  UpdateOrderStatus(
                    orderId: order.id,
                    orderType: 'purchase',
                    status: 'cancelled',
                  ),
                );
          },
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(children: actions);
  }

  // ---------------------------------------------------------------------------
  // Shared Widgets
  // ---------------------------------------------------------------------------

  Widget _buildHeaderCard({
    required String orderNumber,
    required String status,
    required String date,
    String? deliveryDate,
    required String partyName,
    required String partyLabel,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderNumber,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const Divider(height: 24),
            _infoRow(Icons.calendar_today, 'Order Date', date),
            if (deliveryDate != null)
              _infoRow(Icons.local_shipping, 'Expected Delivery', deliveryDate),
            _infoRow(
              widget.orderType == 'sales'
                  ? Icons.person
                  : Icons.business,
              partyLabel,
              partyName,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1B5E20),
      ),
    );
  }

  Widget _buildItemTile({
    required String productName,
    required double quantity,
    required int unitPrice,
    required int totalAmount,
    double deliveredQty = 0,
    double receivedQty = 0,
  }) {
    final tracking = deliveredQty > 0 || receivedQty > 0;
    final trackedQty = deliveredQty > 0 ? deliveredQty : receivedQty;
    final trackingLabel =
        deliveredQty > 0 ? 'Delivered' : (receivedQty > 0 ? 'Received' : '');

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        title: Text(productName, style: const TextStyle(fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${quantity.toStringAsFixed(1)} × ₹${(unitPrice / 100).toStringAsFixed(2)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            if (tracking)
              Text(
                '$trackingLabel: ${trackedQty.toStringAsFixed(1)} / ${quantity.toStringAsFixed(1)}',
                style: TextStyle(
                  color: trackedQty >= quantity ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Text(
          '₹${(totalAmount / 100).toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildFinancialSummary({
    required int subtotal,
    required int taxAmount,
    required int discountAmount,
    required int totalAmount,
  }) {
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _summaryRow(
              'Subtotal',
              '₹${(subtotal / 100).toStringAsFixed(2)}',
            ),
            _summaryRow(
              'Tax',
              '₹${(taxAmount / 100).toStringAsFixed(2)}',
            ),
            _summaryRow(
              'Discount',
              '-₹${(discountAmount / 100).toStringAsFixed(2)}',
            ),
            const Divider(),
            _summaryRow(
              'Total',
              '₹${(totalAmount / 100).toStringAsFixed(2)}',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(label, style: const TextStyle(fontSize: 15)),
        ),
      ),
    );
  }
}

/// Status badge widget with color coding for the detail page.
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor(status)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: _statusColor(status),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'dispatched':
      case 'received':
        return Colors.purple;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
