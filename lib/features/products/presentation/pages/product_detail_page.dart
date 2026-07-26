import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../domain/entities/product_entity.dart';
import '../bloc/product_bloc.dart';
import 'product_form_page.dart';
import '../../../../injection/injection_container.dart';

/// Read-only detail view for a [Product].
///
/// Displays all product fields, renders a QR code when a barcode is present,
/// and provides edit and delete actions via the AppBar and body.
class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<ProductBloc>().add(LoadProductById(productId: widget.productId));
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ProductBloc>().add(
                    DeleteProduct(productId: product.id),
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
      create: (_) => sl<ProductBloc>(),
      child: BlocConsumer<ProductBloc, ProductState>(
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
        builder: (context, state) {
          if (state is ProductLoading) {
            return Scaffold(
              appBar: AppBar(title: const Text('Product Detail')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (state is ProductDetailLoaded) {
            final product = state.product;
            return _buildDetail(context, product);
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Product Detail')),
            body: const Center(child: Text('Product not found')),
          );
        },
      ),
    );
  }

  Widget _buildDetail(BuildContext context, Product product) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute<dynamic>(
                  builder: (_) => ProductFormPage(product: product),
                ),
              );
              if (result == true && mounted) {
                context.read<ProductBloc>().add(
                      LoadProductById(productId: product.id),
                    );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, product),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.barcode != null && product.barcode!.isNotEmpty) ...[
              Center(
                child: QrImageView(
                  data: product.barcode!,
                  version: QrVersions.auto,
                  size: 180,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  product.barcode!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
            ],
            _buildInfoTile(Icons.inventory, 'Name', product.name),
            _buildInfoTile(Icons.qr_code, 'SKU', product.sku ?? 'N/A'),
            _buildInfoTile(
              Icons.confirmation_number,
              'HSN Code',
              product.hsnCode,
            ),
            _buildInfoTile(Icons.straighten, 'Unit', product.unit),
            const Divider(height: 32),
            _buildInfoTile(
              Icons.currency_rupee,
              'MRP',
              '₹${(product.mrp / 100).toStringAsFixed(2)}',
            ),
            _buildInfoTile(
              Icons.sell,
              'Selling Price',
              '₹${(product.sellingPrice / 100).toStringAsFixed(2)}',
            ),
            if (product.purchasePrice != null)
              _buildInfoTile(
                Icons.shopping_cart,
                'Purchase Price',
                '₹${(product.purchasePrice! / 100).toStringAsFixed(2)}',
              ),
            _buildInfoTile(
              Icons.receipt,
              'Tax Rate',
              '${product.taxRate}%',
            ),
            _buildInfoTile(
              Icons.receipt_long,
              'Tax Type',
              product.taxType,
            ),
            const Divider(height: 32),
            _buildInfoTile(
              Icons.category,
              'Category ID',
              product.categoryId ?? 'Uncategorized',
            ),
            _buildInfoTile(
              Icons.warning_amber,
              'Reorder Level',
              product.reorderLevel.toString(),
            ),
            _buildInfoTile(
              Icons.inventory_2,
              'Current Stock',
              product.currentStock.toString(),
            ),
            if (product.isLowStock)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Low Stock Alert',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 32),
            _buildInfoTile(
              Icons.attach_money,
              'Margin',
              '${product.margin.toStringAsFixed(1)}%',
            ),
            _buildInfoTile(
              Icons.payments,
              'Price incl. Tax',
              '₹${(product.sellingPriceWithTax / 100).toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
