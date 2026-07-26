import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../bloc/purchases_bloc.dart';
import '../../domain/entities/purchase_entity.dart';
import '../../../../injection/injection_container.dart';

/// Form page for creating a purchase order.
///
/// Supports dynamic line items where each item has a product ID, name,
/// quantity, unit price, and tax rate. Subtotal, tax, and total are
/// auto-calculated. Dispatches [CreatePurchaseRequested] via [PurchasesBloc].
///
/// The form includes supplier selection, purchase date, and status fields,
/// along with an add/remove mechanism for line items.
class PurchaseFormPage extends StatelessWidget {
  const PurchaseFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PurchasesBloc>(),
      child: const _PurchaseFormView(),
    );
  }
}

class _PurchaseFormView extends StatefulWidget {
  const _PurchaseFormView();

  @override
  State<_PurchaseFormView> createState() => _PurchaseFormViewState();
}

class _PurchaseFormViewState extends State<_PurchaseFormView> {
  final _formKey = GlobalKey<FormState>();
  final _supplierNameController = TextEditingController();
  final _supplierIdController = TextEditingController();
  final _purchaseDateController = TextEditingController(
    text: DateTime.now().toString().substring(0, 10),
  );
  late String _selectedStatus;

  final List<_PurchaseItemForm> _items = [];

  static const _statuses = ['pending', 'received', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _selectedStatus = 'pending';
    _addItem();
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _supplierIdController.dispose();
    _purchaseDateController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_PurchaseItemForm());
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  int _calculateSubtotal() {
    int subtotal = 0;
    for (final item in _items) {
      final qty = int.tryParse(item.quantityController.text) ?? 0;
      final price = int.tryParse(item.unitPriceController.text) ?? 0;
      subtotal += qty * price;
    }
    return subtotal;
  }

  int _calculateTaxAmount() {
    int tax = 0;
    for (final item in _items) {
      final qty = int.tryParse(item.quantityController.text) ?? 0;
      final price = int.tryParse(item.unitPriceController.text) ?? 0;
      final taxRate = double.tryParse(item.taxRateController.text) ?? 0.0;
      tax += ((qty * price) * taxRate / 100).round();
    }
    return tax;
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final subtotal = _calculateSubtotal();
    final taxAmount = _calculateTaxAmount();
    final totalAmount = subtotal + taxAmount;

    final purchaseItems = _items.map((item) {
      final qty = int.tryParse(item.quantityController.text) ?? 0;
      final price = int.tryParse(item.unitPriceController.text) ?? 0;
      final taxRate = double.tryParse(item.taxRateController.text) ?? 0.0;
      final lineTax = ((qty * price) * taxRate / 100).round();
      final lineTotal = qty * price + lineTax;

      return PurchaseItem(
        id: const Uuid().v4(),
        productId: item.productIdController.text.trim(),
        productName: item.productNameController.text.trim(),
        quantity: qty.toDouble(),
        unitPrice: price,
        taxRate: taxRate,
        taxAmount: lineTax,
        totalAmount: lineTotal,
        batchNumber: item.batchController.text.trim().isEmpty
            ? null
            : item.batchController.text.trim(),
      );
    }).toList();

    final purchase = Purchase(
      id: const Uuid().v4(),
      purchaseNumber: 'PO-${now.millisecondsSinceEpoch}',
      supplierId: _supplierIdController.text.trim().isEmpty
          ? null
          : _supplierIdController.text.trim(),
      supplierName: _supplierNameController.text.trim().isEmpty
          ? null
          : _supplierNameController.text.trim(),
      purchaseDate: DateTime.parse(_purchaseDateController.text),
      subtotal: subtotal,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      status: _selectedStatus,
      createdAt: now,
      updatedAt: now,
      items: purchaseItems,
    );

    context.read<PurchasesBloc>().add(
          CreatePurchaseRequested(purchase: purchase),
        );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _calculateSubtotal();
    final taxAmount = _calculateTaxAmount();
    final totalAmount = subtotal + taxAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Purchase Order'),
      ),
      body: BlocConsumer<PurchasesBloc, PurchasesState>(
        listener: (context, state) {
          if (state is PurchaseCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Purchase order created successfully'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          } else if (state is PurchasesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _supplierNameController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier Name',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _supplierIdController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier ID',
                      prefixIcon: Icon(Icons.tag),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _purchaseDateController,
                    decoration: const InputDecoration(
                      labelText: 'Purchase Date *',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        _purchaseDateController.text =
                            date.toString().substring(0, 10);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Purchase date is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status *',
                      prefixIcon: Icon(Icons.flag),
                      border: OutlineInputBorder(),
                    ),
                    items: _statuses
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s[0].toUpperCase() + s.substring(1),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedStatus = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Line Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add_circle),
                        color: const Color(0xFF1B5E20),
                        tooltip: 'Add Item',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_items.length, (index) {
                    return _buildItemCard(index);
                  }),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _summaryRow('Subtotal', '₹$subtotal'),
                          const SizedBox(height: 8),
                          _summaryRow('Tax', '₹$taxAmount'),
                          const Divider(),
                          _summaryRow(
                            'Total',
                            '₹$totalAmount',
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: state is PurchasesLoading ? null : _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: state is PurchasesLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create Purchase Order',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (_items.length > 1)
                  IconButton(
                    onPressed: () => _removeItem(index),
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    tooltip: 'Remove Item',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.productIdController,
              decoration: const InputDecoration(
                labelText: 'Product ID *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.productNameController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Qty *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      final num = int.tryParse(value.trim());
                      if (num == null || num <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.unitPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Unit Price *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      final num = int.tryParse(value.trim());
                      if (num == null || num < 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.taxRateController,
                    decoration: const InputDecoration(
                      labelText: 'Tax %',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.batchController,
              decoration: const InputDecoration(
                labelText: 'Batch Number',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// Holds controllers for a single purchase line item form.
class _PurchaseItemForm {
  final productIdController = TextEditingController();
  final productNameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitPriceController = TextEditingController();
  final taxRateController = TextEditingController(text: '0');
  final batchController = TextEditingController();

  void dispose() {
    productIdController.dispose();
    productNameController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    taxRateController.dispose();
    batchController.dispose();
  }
}
