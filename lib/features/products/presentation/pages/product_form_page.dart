import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/product_entity.dart';
import '../bloc/product_bloc.dart';
import '../../../../injection/injection_container.dart';

/// Form page for creating or editing a [Product].
///
/// When [product] is provided, the form is pre-filled for edit mode.
/// Otherwise, a blank form is shown for creating a new product.
class ProductFormPage extends StatefulWidget {
  final Product? product;

  const ProductFormPage({super.key, this.product});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _hsnCodeController;
  late final TextEditingController _mrpController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _taxRateController;
  late final TextEditingController _categoryIdController;
  late final TextEditingController _reorderLevelController;
  late final TextEditingController _currentStockController;
  late String _unit;
  bool get _isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _hsnCodeController = TextEditingController(text: p?.hsnCode ?? '');
    _mrpController = TextEditingController(
      text: p != null ? (p.mrp / 100).toStringAsFixed(2) : '',
    );
    _sellingPriceController = TextEditingController(
      text: p != null ? (p.sellingPrice / 100).toStringAsFixed(2) : '',
    );
    _purchasePriceController = TextEditingController(
      text: p?.purchasePrice != null
          ? (p!.purchasePrice! / 100).toStringAsFixed(2)
          : '',
    );
    _taxRateController = TextEditingController(
      text: p?.taxRate.toString() ?? '',
    );
    _categoryIdController = TextEditingController(text: p?.categoryId ?? '');
    _reorderLevelController = TextEditingController(
      text: p?.reorderLevel.toString() ?? '10',
    );
    _currentStockController = TextEditingController(
      text: p?.currentStock.toString() ?? '0',
    );
    _unit = p?.unit ?? 'PCS';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _hsnCodeController.dispose();
    _mrpController.dispose();
    _sellingPriceController.dispose();
    _purchasePriceController.dispose();
    _taxRateController.dispose();
    _categoryIdController.dispose();
    _reorderLevelController.dispose();
    _currentStockController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      sku: _skuController.text.trim().isEmpty
          ? null
          : _skuController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      hsnCode: _hsnCodeController.text.trim(),
      unit: _unit,
      mrp: (double.parse(_mrpController.text) * 100).round(),
      sellingPrice: (double.parse(_sellingPriceController.text) * 100).round(),
      purchasePrice: _purchasePriceController.text.trim().isEmpty
          ? null
          : (double.parse(_purchasePriceController.text) * 100).round(),
      taxRate: _taxRateController.text.trim().isEmpty
          ? 0.0
          : double.parse(_taxRateController.text.trim()),
      categoryId: _categoryIdController.text.trim().isEmpty
          ? null
          : _categoryIdController.text.trim(),
      reorderLevel: _reorderLevelController.text.trim().isEmpty
          ? 10
          : int.parse(_reorderLevelController.text.trim()),
      currentStock: _currentStockController.text.trim().isEmpty
          ? 0
          : int.parse(_currentStockController.text.trim()),
      createdAt: widget.product?.createdAt ?? now,
      updatedAt: now,
      version: widget.product?.version ?? 1,
    );

    if (_isEditMode) {
      context.read<ProductBloc>().add(UpdateProduct(product: product));
    } else {
      context.read<ProductBloc>().add(CreateProduct(product: product));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductBloc>(),
      child: BlocListener<ProductBloc, ProductState>(
        listener: (context, state) {
          if (state is ProductOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          } else if (state is ProductError) {
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
            title: Text(_isEditMode ? 'Edit Product' : 'Add Product'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      prefixIcon: Icon(Icons.inventory),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter product name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(
                      labelText: 'SKU',
                      prefixIcon: Icon(Icons.qr_code),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Barcode',
                      prefixIcon: Icon(Icons.barcode_reader),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _hsnCodeController,
                    decoration: const InputDecoration(
                      labelText: 'HSN Code *',
                      prefixIcon: Icon(Icons.confirmation_number),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter HSN code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      prefixIcon: Icon(Icons.straighten),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'PCS', child: Text('PCS (Pieces)')),
                      DropdownMenuItem(value: 'KG', child: Text('KG (Kilograms)')),
                      DropdownMenuItem(value: 'LTR', child: Text('LTR (Litres)')),
                      DropdownMenuItem(value: 'MTR', child: Text('MTR (Metres)')),
                      DropdownMenuItem(value: 'BOX', child: Text('BOX (Boxes)')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _unit = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mrpController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'MRP (₹) *',
                      prefixIcon: Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter MRP';
                      }
                      if (double.tryParse(value.trim()) == null) {
                        return 'Please enter a valid number';
                      }
                      if (double.parse(value.trim()) < 0) {
                        return 'MRP cannot be negative';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sellingPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Selling Price (₹) *',
                      prefixIcon: Icon(Icons.sell),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter selling price';
                      }
                      if (double.tryParse(value.trim()) == null) {
                        return 'Please enter a valid number';
                      }
                      if (double.parse(value.trim()) < 0) {
                        return 'Selling price cannot be negative';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _purchasePriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Purchase Price (₹)',
                      prefixIcon: Icon(Icons.shopping_cart),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        if (double.tryParse(value.trim()) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value.trim()) < 0) {
                          return 'Purchase price cannot be negative';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _taxRateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Tax Rate (%)',
                      prefixIcon: Icon(Icons.receipt),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        if (double.tryParse(value.trim()) == null) {
                          return 'Please enter a valid number';
                        }
                        final rate = double.parse(value.trim());
                        if (rate < 0 || rate > 100) {
                          return 'Tax rate must be between 0 and 100';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _categoryIdController,
                    decoration: const InputDecoration(
                      labelText: 'Category ID',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reorderLevelController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Reorder Level',
                      prefixIcon: Icon(Icons.warning_amber),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        if (int.tryParse(value.trim()) == null) {
                          return 'Please enter a valid whole number';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _currentStockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Current Stock',
                      prefixIcon: Icon(Icons.inventory_2),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        if (int.tryParse(value.trim()) == null) {
                          return 'Please enter a valid whole number';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  BlocBuilder<ProductBloc, ProductState>(
                    builder: (context, state) {
                      return SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: state is ProductLoading
                              ? null
                              : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                          ),
                          child: state is ProductLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  _isEditMode ? 'Update Product' : 'Create Product',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
