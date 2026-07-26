import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../bloc/challans_bloc.dart';
import '../../domain/entities/delivery_challan.dart';
import '../../domain/entities/delivery_challan_item.dart';
import '../../../../injection/injection_container.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_button.dart';

/// Form page for creating a new delivery challan.
///
/// Supports dynamic line items where each item has a product ID, name,
/// quantity, delivered quantity, and unit. The form includes customer
/// details, vehicle number, driver name/phone, and an optional sales
/// order reference. Dispatches [CreateChallan] via [ChallansBloc] on save.
///
/// The form includes add/remove mechanisms for line items, matching the
/// pattern established in [PurchaseFormPage].
class ChallanFormPage extends StatelessWidget {
  const ChallanFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChallansBloc>(),
      child: const _ChallanFormView(),
    );
  }
}

class _ChallanFormView extends StatefulWidget {
  const _ChallanFormView();

  @override
  State<_ChallanFormView> createState() => _ChallanFormViewState();
}

class _ChallanFormViewState extends State<_ChallanFormView> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerIdController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _salesOrderIdController = TextEditingController();
  final _challanDateController = TextEditingController(
    text: DateTime.now().toString().substring(0, 10),
  );

  final List<_ChallanItemForm> _items = [];

  @override
  void initState() {
    super.initState();
    _addItem();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerIdController.dispose();
    _vehicleNumberController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _salesOrderIdController.dispose();
    _challanDateController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_ChallanItemForm());
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();

    final challanItems = _items.map((item) {
      final qty = double.tryParse(item.quantityController.text) ?? 0;
      final delivered = double.tryParse(item.deliveredQuantityController.text) ?? 0;

      return DeliveryChallanItem(
        id: const Uuid().v4(),
        productId: item.productIdController.text.trim(),
        productName: item.productNameController.text.trim(),
        quantity: qty,
        deliveredQuantity: delivered,
        unit: item.unitController.text.trim().isEmpty
            ? 'PCS'
            : item.unitController.text.trim(),
      );
    }).toList();

    final challan = DeliveryChallan(
      id: const Uuid().v4(),
      challanNumber: '',
      customerId: _customerIdController.text.trim().isEmpty
          ? 'walk-in'
          : _customerIdController.text.trim(),
      customerName: _customerNameController.text.trim().isEmpty
          ? 'Walk-in Customer'
          : _customerNameController.text.trim(),
      salesOrderId: _salesOrderIdController.text.trim().isEmpty
          ? null
          : _salesOrderIdController.text.trim(),
      challanDate: DateTime.parse(_challanDateController.text),
      vehicleNumber: _vehicleNumberController.text.trim(),
      driverName: _driverNameController.text.trim(),
      driverPhone: _driverPhoneController.text.trim(),
      createdAt: now,
      updatedAt: now,
      items: challanItems,
    );

    context.read<ChallansBloc>().add(CreateChallan(challan: challan));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Delivery Challan'),
      ),
      body: BlocConsumer<ChallansBloc, ChallansState>(
        listener: (context, state) {
          if (state is ChallanCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Challan ${state.challan.challanNumber} created successfully',
                ),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          } else if (state is ChallansError) {
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
                  AppTextField(
                    controller: _customerNameController,
                    label: 'Customer Name',
                    prefixIcon: Icons.person,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _customerIdController,
                    label: 'Customer ID',
                    prefixIcon: Icons.tag,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _challanDateController,
                    label: 'Challan Date *',
                    prefixIcon: Icons.calendar_today,
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        _challanDateController.text =
                            date.toString().substring(0, 10);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Challan date is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _salesOrderIdController,
                    label: 'Sales Order ID (optional)',
                    prefixIcon: Icons.receipt_long,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Vehicle & Driver Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _vehicleNumberController,
                    label: 'Vehicle Number *',
                    prefixIcon: Icons.local_shipping,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vehicle number is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _driverNameController,
                    label: 'Driver Name *',
                    prefixIcon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Driver name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _driverPhoneController,
                    label: 'Driver Phone *',
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Driver phone is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Line Items',
                        style: TextStyle(
                          fontSize: 16,
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
                  const SizedBox(height: 24),
                  AppButton(
                    text: 'Create Challan',
                    icon: Icons.local_shipping,
                    isLoading: state is ChallansLoading,
                    onPressed: state is ChallansLoading ? null : _onSave,
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
                      final num = double.tryParse(value.trim());
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
                    controller: item.deliveredQuantityController,
                    decoration: const InputDecoration(
                      labelText: 'Delivered Qty',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Holds controllers for a single challan line item form.
class _ChallanItemForm {
  final productIdController = TextEditingController();
  final productNameController = TextEditingController();
  final quantityController = TextEditingController();
  final deliveredQuantityController = TextEditingController(text: '0');
  final unitController = TextEditingController(text: 'PCS');

  void dispose() {
    productIdController.dispose();
    productNameController.dispose();
    quantityController.dispose();
    deliveredQuantityController.dispose();
    unitController.dispose();
  }
}
