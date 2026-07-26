import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/inventory_bloc.dart';
import '../../domain/entities/stock_entity.dart';
import '../../../../injection/injection_container.dart';

/// Form page for adjusting stock quantity of a product.
///
/// Allows the user to select a product, choose an adjustment type, enter
/// a quantity and reason, and optionally specify a batch number. Dispatches
/// an [AdjustStock] event via [InventoryBloc] on save.
///
/// The adjustment type determines the nature of the stock change:
/// purchase, sale, return, damage, adjustment, transfer, or correction.
class StockAdjustmentPage extends StatelessWidget {
  const StockAdjustmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InventoryBloc>()..add(const LoadStock()),
      child: const _StockAdjustmentView(),
    );
  }
}

class _StockAdjustmentView extends StatefulWidget {
  const _StockAdjustmentView();

  @override
  State<_StockAdjustmentView> createState() => _StockAdjustmentViewState();
}

class _StockAdjustmentViewState extends State<_StockAdjustmentView> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _batchController = TextEditingController();
  final _searchController = TextEditingController();

  Stock? _selectedStock;
  String _selectedAdjustmentType = 'adjustment';
  List<Stock> _filteredStock = [];

  static const _adjustmentTypes = [
    'purchase',
    'sale',
    'return',
    'damage',
    'adjustment',
    'transfer',
    'correction',
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _batchController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterStock(List<Stock> stock) {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStock = query.isEmpty
          ? stock
          : stock
              .where(
                (s) =>
                    s.productName.toLowerCase().contains(query) ||
                    s.productId.toLowerCase().contains(query),
              )
              .toList();
    });
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    context.read<InventoryBloc>().add(
          AdjustStock(
            productId: _selectedStock!.productId,
            adjustmentType: _selectedAdjustmentType,
            quantity: int.parse(_quantityController.text.trim()),
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
            batchNumber: _batchController.text.trim().isEmpty
                ? null
                : _batchController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Adjustment'),
      ),
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (context, state) {
          if (state is StockOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          } else if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          List<Stock> allStock = [];
          if (state is InventoryLoaded) {
            allStock = state.stock;
            if (_filteredStock.isEmpty && _searchController.text.isEmpty) {
              _filteredStock = allStock;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedStock == null) ...[
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search Product',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _filterStock(allStock),
                    ),
                    const SizedBox(height: 8),
                    if (_filteredStock.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredStock.length,
                          itemBuilder: (context, index) {
                            final stock = _filteredStock[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: stock.isLowStock
                                    ? Colors.red
                                    : Colors.green,
                                radius: 16,
                                child: Text(
                                  stock.availableQuantity.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              title: Text(stock.productName),
                              subtitle: Text(
                                'Available: ${stock.availableQuantity} | '
                                'Location: ${stock.locationId}',
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedStock = stock;
                                  _batchController.text =
                                      stock.batchNumber ?? '';
                                });
                              },
                            );
                          },
                        ),
                      ),
                  ] else ...[
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _selectedStock!.isLowStock
                              ? Colors.red
                              : Colors.green,
                          child: const Icon(
                            Icons.inventory_2,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          _selectedStock!.productName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          'Available: ${_selectedStock!.availableQuantity} | '
                          'Location: ${_selectedStock!.locationId}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() => _selectedStock = null);
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedAdjustmentType,
                    decoration: const InputDecoration(
                      labelText: 'Adjustment Type *',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: _adjustmentTypes
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(
                                type[0].toUpperCase() + type.substring(1),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedAdjustmentType = value);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Adjustment type is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Quantity is required';
                      }
                      final num = int.tryParse(value.trim());
                      if (num == null || num <= 0) {
                        return 'Enter a valid positive number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      prefixIcon: Icon(Icons.notes),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _batchController,
                    decoration: const InputDecoration(
                      labelText: 'Batch Number',
                      prefixIcon: Icon(Icons.qr_code),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: state is InventoryLoading ? null : _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: state is InventoryLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Adjust Stock',
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
}
