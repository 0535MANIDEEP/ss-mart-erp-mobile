import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/sales_order_entity.dart';
import '../../domain/entities/sales_order_item_entity.dart';
import '../bloc/orders_bloc.dart';
import '../../../../database/app_database.dart' as db;
import '../../../../injection/injection_container.dart';

/// Form page for creating or editing a sales order.
///
/// Provides a complete order entry form with:
/// - Customer selector (searchable dropdown loaded from database)
/// - Dynamic product line items with quantity and price
/// - Auto-calculated subtotal, tax, and total
/// - Save as draft or confirm actions
///
/// When [order] is provided, the form is pre-filled for edit mode.
/// Otherwise, a blank form is shown for creating a new sales order.
class SalesOrderFormPage extends StatefulWidget {
  /// Optional existing order for edit mode. Null for new order creation.
  final SalesOrder? order;

  const SalesOrderFormPage({super.key, this.order});

  @override
  State<SalesOrderFormPage> createState() => _SalesOrderFormPageState();
}

class _SalesOrderFormPageState extends State<SalesOrderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchCustomerController =
      TextEditingController();

  String? _selectedCustomerId;
  String? _selectedCustomerName;
  DateTime _orderDate = DateTime.now();
  DateTime? _expectedDeliveryDate;
  List<_OrderItemRow> _items = [];
  bool _isSaving = false;

  bool get _isEditMode => widget.order != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final o = widget.order!;
      _selectedCustomerId = o.customerId;
      _selectedCustomerName = o.customerName;
      _orderDate = o.orderDate;
      _expectedDeliveryDate = o.expectedDeliveryDate;
      _notesController.text = o.notes ?? '';
      _items = o.items
          .map(
            (item) => _OrderItemRow(
              productId: item.productId,
              productName: item.productName,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              taxRate: item.taxRate,
              discountAmount: item.discountAmount,
            ),
          )
          .toList();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchCustomerController.dispose();
    super.dispose();
  }

  int get _subtotal =>
      _items.fold(0, (sum, item) => sum + item.lineTotal);

  int get _taxAmount =>
      _items.fold(0, (sum, item) => sum + item.taxAmount);

  int get _discountAmount =>
      _items.fold(0, (sum, item) => sum + item.discountAmount);

  int get _totalAmount => _subtotal + _taxAmount - _discountAmount;

  void _addItem() {
    setState(() {
      _items.add(_OrderItemRow(
        productId: '',
        productName: '',
        quantity: 1,
        unitPrice: 0,
        taxRate: 0,
        discountAmount: 0,
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  String _generateOrderNumber() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'SO-$dateStr-$timeStr';
  }

  Future<void> _submitOrder(String status) async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_items.any((item) => item.productId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product for all items'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final order = SalesOrder(
      id: widget.order?.id ?? const Uuid().v4(),
      orderNumber: widget.order?.orderNumber ?? _generateOrderNumber(),
      customerId: _selectedCustomerId,
      customerName: _selectedCustomerName,
      orderDate: _orderDate,
      expectedDeliveryDate: _expectedDeliveryDate,
      subtotal: _subtotal,
      taxAmount: _taxAmount,
      discountAmount: _discountAmount,
      totalAmount: _totalAmount,
      status: status,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdBy: '',
      createdAt: widget.order?.createdAt ?? now,
      updatedAt: now,
      version: widget.order?.version ?? 1,
      items: _items
          .map(
            (row) => SalesOrderItem(
              id: const Uuid().v4(),
              orderId: widget.order?.id ?? '',
              productId: row.productId,
              productName: row.productName,
              quantity: row.quantity,
              unitPrice: row.unitPrice,
              taxRate: row.taxRate,
              discountAmount: row.discountAmount,
              taxAmount: row.taxAmount,
              totalAmount: row.lineTotal + row.taxAmount - row.discountAmount,
            ),
          )
          .toList(),
    );

    if (_isEditMode) {
      context.read<OrdersBloc>().add(CreateSalesOrder(order: order));
    } else {
      context.read<OrdersBloc>().add(CreateSalesOrder(order: order));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrdersBloc>(),
      child: BlocListener<OrdersBloc, OrdersState>(
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
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _isEditMode ? 'Edit Sales Order' : 'New Sales Order',
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Customer selector
                _buildCustomerSelector(),
                const SizedBox(height: 16),

                // Order date
                _buildDatePicker(
                  label: 'Order Date',
                  date: _orderDate,
                  onPicked: (date) => setState(() => _orderDate = date),
                ),
                const SizedBox(height: 16),

                // Expected delivery date
                _buildDatePicker(
                  label: 'Expected Delivery Date',
                  date: _expectedDeliveryDate,
                  onPicked: (date) =>
                      setState(() => _expectedDeliveryDate = date),
                  allowClear: true,
                ),
                const SizedBox(height: 24),

                // Line items header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Order Items',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Line items
                if (_items.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.shopping_basket_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No items added yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _addItem,
                              child: const Text('Add first item'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                ...List.generate(_items.length, (index) {
                  return _buildItemCard(index);
                }),

                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),

                // Order summary
                _buildOrderSummary(),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => _submitOrder('draft'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save as Draft'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _isSaving ? null : () => _submitOrder('confirmed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Confirm Order'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showCustomerPicker(context),
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: 'Select customer (optional for walk-in)',
              border: const OutlineInputBorder(),
              suffixIcon: _selectedCustomerId != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _selectedCustomerId = null;
                          _selectedCustomerName = null;
                        });
                      },
                    )
                  : const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              _selectedCustomerName ?? 'Walk-in Customer',
              style: TextStyle(
                color: _selectedCustomerName != null
                    ? Colors.black
                    : Colors.grey[600],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCustomerPicker(BuildContext context) async {
    final database = sl<db.AppDatabase>();
    final dao = db.DatabaseDao(database);
    final customers = await dao.getActiveCustomers();

    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = searchQuery.isEmpty
                ? customers
                : customers
                    .where((c) =>
                        c.name.toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Select Customer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search customers...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setModalState(() => searchQuery = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, index) {
                          final c = filtered[index];
                          return ListTile(
                            title: Text(c.name),
                            subtitle: Text(c.phone ?? 'No phone'),
                            onTap: () => Navigator.pop(ctx, c.id),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      final customer = await dao.getCustomerById(selected);
      if (customer != null && mounted) {
        setState(() {
          _selectedCustomerId = customer.id;
          _selectedCustomerName = customer.name;
        });
      }
    }
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime> onPicked,
    bool allowClear = false,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (allowClear && date != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => setState(() => _expectedDeliveryDate = null),
                ),
              const Icon(Icons.calendar_today, size: 20),
            ],
          ),
        ),
        child: Text(
          date != null
              ? '${date.day}/${date.month}/${date.year}'
              : 'Select date',
          style: TextStyle(
            color: date != null ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName.isEmpty
                        ? 'Item ${index + 1}'
                        : item.productName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  tooltip: 'Select Product',
                  onPressed: () => _showProductPicker(context, index),
                ),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _removeItem(index),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final qty = double.tryParse(v) ?? 0;
                      setState(() => _items[index] = item.copyWith(quantity: qty));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: (item.unitPrice / 100).toStringAsFixed(2),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price (₹)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final price =
                          ((double.tryParse(v) ?? 0) * 100).round();
                      setState(() => _items[index] = item.copyWith(unitPrice: price));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    '₹${(item.lineTotal / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProductPicker(BuildContext context, int index) async {
    final database = sl<db.AppDatabase>();
    final dao = db.DatabaseDao(database);
    final products = await dao.getActiveProducts();

    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = searchQuery.isEmpty
                ? products
                : products
                    .where((p) =>
                        p.name.toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Select Product',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search products...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setModalState(() => searchQuery = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final p = filtered[i];
                          return ListTile(
                            title: Text(p.name),
                            subtitle: Text(
                              '₹${(p.sellingPrice / 100).toStringAsFixed(2)}',
                            ),
                            onTap: () => Navigator.pop(ctx, p.id),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      final product = await dao.getProductById(selected);
      if (product != null && mounted) {
        final currentItem = _items[index];
        setState(() {
          _items[index] = currentItem.copyWith(
            productId: product.id,
            productName: product.name,
            unitPrice: product.sellingPrice,
            taxRate: product.taxRate,
          );
        });
      }
    }
  }

  Widget _buildOrderSummary() {
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _summaryRow('Subtotal', '₹${(_subtotal / 100).toStringAsFixed(2)}'),
            _summaryRow('Tax', '₹${(_taxAmount / 100).toStringAsFixed(2)}'),
            _summaryRow(
              'Discount',
              '-₹${(_discountAmount / 100).toStringAsFixed(2)}',
            ),
            const Divider(),
            _summaryRow(
              'Total',
              '₹${(_totalAmount / 100).toStringAsFixed(2)}',
              isBold: true,
            ),
            const SizedBox(height: 4),
            Text(
              '${_items.length} item(s)',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
}

/// Internal state class for managing order line item form rows.
class _OrderItemRow {
  final String productId;
  final String productName;
  final double quantity;
  final int unitPrice;
  final double taxRate;
  final int discountAmount;

  const _OrderItemRow({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
    required this.discountAmount,
  });

  /// Line total before tax: quantity × unitPrice.
  int get lineTotal => (quantity * unitPrice).round();

  /// Tax amount calculated from lineTotal × taxRate / 100.
  int get taxAmount => (lineTotal * taxRate / 100).round();

  _OrderItemRow copyWith({
    String? productId,
    String? productName,
    double? quantity,
    int? unitPrice,
    double? taxRate,
    int? discountAmount,
  }) {
    return _OrderItemRow(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate ?? this.taxRate,
      discountAmount: discountAmount ?? this.discountAmount,
    );
  }
}
