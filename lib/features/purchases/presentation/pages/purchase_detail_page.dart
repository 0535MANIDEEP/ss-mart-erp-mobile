import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/purchases_bloc.dart';
import '../../domain/entities/purchase_entity.dart';
import '../../../../injection/injection_container.dart';

/// Detail page displaying all information for a purchase order.
///
/// Shows the purchase header (supplier, date, totals, status) and a list
/// of all line items. If the purchase status is 'pending', a "Receive Goods"
/// button is displayed that opens a dialog for marking items as received
/// with actual quantities. Dispatches [ReceivePurchaseRequested] via
/// [PurchasesBloc] on confirmation.
class PurchaseDetailPage extends StatelessWidget {
  final Purchase purchase;

  const PurchaseDetailPage({super.key, required this.purchase});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PurchasesBloc>(),
      child: _PurchaseDetailView(purchase: purchase),
    );
  }
}

class _PurchaseDetailView extends StatelessWidget {
  final Purchase purchase;

  const _PurchaseDetailView({required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Purchase #${purchase.purchaseNumber}'),
      ),
      body: BlocConsumer<PurchasesBloc, PurchasesState>(
        listener: (context, state) {
          if (state is PurchaseReceived) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Goods received successfully'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBadge(),
                const SizedBox(height: 16),
                _buildInfoCard(),
                const SizedBox(height: 16),
                _buildItemsSection(),
                const SizedBox(height: 16),
                _buildTotalsCard(),
                if (purchase.isPending) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: state is PurchasesLoading
                          ? null
                          : () => _showReceiveDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: state is PurchasesLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.inventory),
                      label: const Text(
                        'Receive Goods',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    IconData icon;
    switch (purchase.status) {
      case 'received':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            purchase.status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Purchase Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _infoRow(Icons.business, 'Supplier',
                purchase.supplierName ?? 'Unknown'),
            const SizedBox(height: 8),
            _infoRow(Icons.calendar_today, 'Date',
                purchase.purchaseDate.toString().substring(0, 10)),
            const SizedBox(height: 8),
            _infoRow(Icons.tag, 'Order Number', purchase.purchaseNumber),
            const SizedBox(height: 8),
            _infoRow(Icons.inventory_2, 'Items',
                '${purchase.items.length} items'),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Line Items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (purchase.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No items in this purchase order',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...purchase.items.map((item) => _itemRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(PurchaseItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '₹${item.totalAmount}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Qty: ${item.quantity.toInt()} × ₹${item.unitPrice}'
            '${item.taxRate > 0 ? ' + ${item.taxRate}% tax' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (item.batchNumber != null && item.batchNumber!.isNotEmpty)
            Text(
              'Batch: ${item.batchNumber}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('Subtotal', '₹${purchase.subtotal}'),
            const SizedBox(height: 8),
            _summaryRow('Tax', '₹${purchase.taxAmount}'),
            const Divider(),
            _summaryRow(
              'Total',
              '₹${purchase.totalAmount}',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
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

  void _showReceiveDialog(BuildContext context) {
    final receivedQuantities = <String, TextEditingController>{};
    for (final item in purchase.items) {
      receivedQuantities[item.id] = TextEditingController(
        text: item.quantity.toInt().toString(),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receive Goods'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Confirm actual quantities received for each item:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ...purchase.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Ordered: ${item.quantity.toInt()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: receivedQuantities[item.id],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final receivedItems = purchase.items.map((item) {
                final qty = int.tryParse(
                      receivedQuantities[item.id]?.text ?? '',
                    ) ??
                    item.quantity.toInt();
                return PurchaseItem(
                  id: item.id,
                  productId: item.productId,
                  productName: item.productName,
                  quantity: qty.toDouble(),
                  unitPrice: item.unitPrice,
                  taxRate: item.taxRate,
                  taxAmount: item.taxAmount,
                  totalAmount: item.totalAmount,
                  batchNumber: item.batchNumber,
                );
              }).toList();

              context.read<PurchasesBloc>().add(
                    ReceivePurchaseRequested(
                      purchaseId: purchase.id,
                      receivedItems: receivedItems,
                    ),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Receipt'),
          ),
        ],
      ),
    ).then((_) {
      for (final controller in receivedQuantities.values) {
        controller.dispose();
      }
    });
  }
}
