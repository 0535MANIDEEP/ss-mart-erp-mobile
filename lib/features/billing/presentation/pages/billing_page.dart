import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../bloc/billing_bloc.dart';
import '../../domain/entities/bill_entity.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../../core/services/bluetooth_printer_service.dart';

class BillingPage extends StatelessWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.instance<BillingBloc>()..add(const InitializeBilling()),
      child: const BillingView(),
    );
  }
}

class BillingView extends StatelessWidget {
  const BillingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SS MART - Billing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showRecentBills(context),
          ),
        ],
      ),
      body: BlocListener<BillingBloc, BillingState>(
        listener: (context, state) {
          if (state is BillingSuccess) {
            _showBillSuccessDialog(context, state);
          }
        },
        child: Column(
        children: [
          _buildCustomerBar(context),
          Expanded(
            child: BlocBuilder<BillingBloc, BillingState>(
              builder: (context, state) {
                if (state is BillingReady && state.items.isNotEmpty) {
                  return _buildCartList(context, state);
                }
                return _buildEmptyCart();
              },
            ),
          ),
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              if (state is BillingReady && state.items.isNotEmpty) {
                return _buildBillSummary(context, state);
              }
              return const SizedBox.shrink();
            },
          ),
        ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'scan',
            onPressed: () => _navigateToScanner(context),
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'cart',
            onPressed: () => _showProductSearch(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  void _showBillSuccessDialog(BuildContext context, BillingSuccess state) {
    final bill = state.bill;
    if (bill == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Bill Completed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bill No: ${bill.billNumber}'),
            Text('Total: \u20B9${bill.totalAmount.toStringAsFixed(2)}'),
            Text('Payment: ${bill.paymentMode}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _doPrintReceipt(context, bill);
                },
                icon: const Icon(Icons.print),
                label: const Text('Print Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    ).then((_) {
      _printReceipt(context, bill);
    });
  }

  Widget _buildCustomerBar(BuildContext context) {
    return BlocBuilder<BillingBloc, BillingState>(
      builder: (context, state) {
        final customerName = state is BillingReady ? state.customerName : 'Walk-in Customer';
        final hasCustomer = state is BillingReady && state.hasCustomer;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.grey[100],
          child: Row(
            children: [
              const Icon(Icons.person, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    if (hasCustomer)
                      Text(
                        'Customer selected',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              if (hasCustomer)
                TextButton(
                  onPressed: () {
                    context.read<BillingBloc>().add(const ClearCustomer());
                  },
                  child: const Text('Clear'),
                )
              else
                TextButton.icon(
                  onPressed: () => _showCustomerSearch(context),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Select'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyCart() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
          SizedBox(height: 8),
          Text('Scan barcode or search product', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCartList(BuildContext context, BillingReady state) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        return _buildCartItem(context, item);
      },
    );
  }

  Widget _buildCartItem(BuildContext context, BillItem item) {
    return GestureDetector(
      onLongPress: () => _showItemDiscountDialog(context, item),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.discountAmount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.discountPercent.toStringAsFixed(1)}% OFF',
                              style: TextStyle(
                                color: Colors.green[800],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\u20B9${item.unitPrice} x ${item.quantity.round()}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    if (item.batchNumber != null)
                      Text(
                        'Batch: ${item.batchNumber}',
                        style: TextStyle(color: Colors.blue[600], fontSize: 11),
                      ),
                    if (item.expiryDate != null)
                      Text(
                        'Exp: ${item.expiryDate!.day}/${item.expiryDate!.month}/${item.expiryDate!.year}',
                        style: TextStyle(
                          color: item.expiryDate!.isBefore(DateTime.now())
                              ? Colors.red[700]
                              : Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    if (item.taxAmount > 0)
                      Text(
                        'Tax: \u20B9${item.taxAmount}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 24),
                    onPressed: () {
                      if (item.quantity > 1) {
                        context.read<BillingBloc>().add(
                              UpdateCartItemQuantity(
                                itemId: item.id,
                                quantity: item.quantity - 1,
                              ),
                            );
                      } else {
                        context.read<BillingBloc>().add(
                              RemoveFromCart(itemId: item.id),
                            );
                      }
                    },
                  ),
                  Text(
                    '${item.quantity.round()}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 24),
                    onPressed: () {
                      context.read<BillingBloc>().add(
                            UpdateCartItemQuantity(
                              itemId: item.id,
                              quantity: item.quantity + 1,
                            ),
                          );
                    },
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\u20B9${item.totalAmount}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (item.discountAmount > 0)
                    Text(
                      '-\u20B9${item.discountAmount}',
                      style: TextStyle(color: Colors.green[700], fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillSummary(BuildContext context, BillingReady state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', '\u20B9${state.subtotal}'),
          _buildSummaryRow('Tax (GST)', '\u20B9${state.taxAmount}'),
          if (state.discountAmount > 0)
            _buildSummaryRow('Item Discount', '-\u20B9${state.discountAmount}'),
          if (state.billDiscountAmount > 0)
            _buildSummaryRow('Bill Discount', '-\u20B9${state.billDiscountAmount}'),
          if (state.roundOff != 0)
            _buildSummaryRow('Round Off', '\u20B9${state.roundOff}'),
          const Divider(),
          _buildSummaryRow('Total', '\u20B9${state.totalAmount}', isBold: true),
          _buildSummaryRow('Items: ${state.itemCount} | Qty: ${state.totalQuantity}', '', isLabel: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showBillDiscountDialog(context, state),
                  icon: const Icon(Icons.discount, size: 18),
                  label: const Text('Discount'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.read<BillingBloc>().add(const ClearCart());
                  },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _showPaymentDialog(context, state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Pay Now', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool isLabel = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: isLabel
          ? Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(fontSize: isBold ? 17 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
                Text(value, style: TextStyle(fontSize: isBold ? 17 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
    );
  }

  void _showItemDiscountDialog(BuildContext context, BillItem item) {
    final percentController = TextEditingController();
    final amountController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Discount - ${item.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Item total: \u20B9${item.subtotal}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: percentController,
              decoration: const InputDecoration(
                labelText: 'Discount %',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Discount Amount',
                border: OutlineInputBorder(),
                prefixText: '\u20B9 ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter either % or amount',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (item.discountAmount > 0)
            TextButton(
              onPressed: () {
                context.read<BillingBloc>().add(ApplyItemDiscount(
                  itemId: item.id,
                  discountPercent: 0,
                  discountAmount: 0,
                ));
                Navigator.pop(dialogContext);
              },
              child: const Text('Remove'),
            ),
          ElevatedButton(
            onPressed: () {
              final pct = double.tryParse(percentController.text) ?? 0;
              final amt = int.tryParse(amountController.text) ?? 0;
              if (pct > 0 || amt > 0) {
                context.read<BillingBloc>().add(ApplyItemDiscount(
                  itemId: item.id,
                  discountPercent: pct,
                  discountAmount: amt,
                ));
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showBillDiscountDialog(BuildContext context, BillingReady state) {
    final percentController = TextEditingController();
    final amountController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bill Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Subtotal: \u20B9${state.subtotal}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: percentController,
              decoration: const InputDecoration(
                labelText: 'Discount %',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Discount Amount',
                border: OutlineInputBorder(),
                prefixText: '\u20B9 ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter either % or amount',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (state.billDiscountAmount > 0)
            TextButton(
              onPressed: () {
                context.read<BillingBloc>().add(const ApplyBillDiscount(
                  discountPercent: 0,
                  discountAmount: 0,
                ));
                Navigator.pop(dialogContext);
              },
              child: const Text('Remove'),
            ),
          ElevatedButton(
            onPressed: () {
              final pct = double.tryParse(percentController.text) ?? 0;
              final amt = int.tryParse(amountController.text) ?? 0;
              if (pct > 0 || amt > 0) {
                context.read<BillingBloc>().add(ApplyBillDiscount(
                  discountPercent: pct,
                  discountAmount: amt,
                ));
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showProductSearch(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<BillingBloc>(),
        child: const ProductSearchSheet(),
      ),
    );
  }

  void _navigateToScanner(BuildContext context) async {
    final barcode = await context.push<String>('/barcode-scanner');
    if (barcode != null && barcode.isNotEmpty && context.mounted) {
      _lookupBarcode(context, barcode);
    }
  }

  void _lookupBarcode(BuildContext context, String barcode) async {
    final productRepo = GetIt.instance<ProductRepository>();
    final result = await productRepo.getProducts(
      search: barcode,
      perPage: 10,
    );

    result.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      (products) {
        final matched = products.where((p) => p.barcode == barcode).toList();
        if (matched.isNotEmpty) {
          _addScannedProductToCart(context, matched.first);
        } else if (products.isNotEmpty) {
          _addScannedProductToCart(context, products.first);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product not found for barcode'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      },
    );
  }

  void _addScannedProductToCart(BuildContext context, Product product) {
    final taxAmount = (product.sellingPrice * product.taxRate / 100).round();
    final totalAmount = product.sellingPrice + taxAmount;

    String? buyerStateCode;
    final billingState = context.read<BillingBloc>().state;
    if (billingState is BillingReady && billingState.customerStateCode != null) {
      buyerStateCode = billingState.customerStateCode;
    }

    context.read<BillingBloc>().add(AddToCart(
      productId: product.id,
      productName: product.name,
      quantity: 1,
      unitPrice: product.sellingPrice,
      taxRate: product.taxRate,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      buyerStateCode: buyerStateCode,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _printReceipt(BuildContext context, Bill bill) async {
    final printerService = GetIt.instance<BluetoothPrinterService>();

    if (printerService.autoPrint) {
      _doPrintReceipt(context, bill);
    }
  }

  void _doPrintReceipt(BuildContext context, Bill bill) async {
    final printerService = GetIt.instance<BluetoothPrinterService>();

    if (!printerService.isConnected) {
      final reconnected = await printerService.connectPrinter();
      if (!reconnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printer not connected. Go to Settings > Printer Settings.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    try {
      await printerService.printReceipt(
        storeName: 'SS MART',
        storeAddress: null,
        storeGstin: null,
        billNumber: bill.billNumber,
        billDate: bill.billDate,
        items: bill.items,
        subtotal: bill.subtotal,
        taxAmount: bill.taxAmount,
        discountAmount: bill.discountAmount,
        totalAmount: bill.totalAmount,
        paymentMode: bill.paymentMode,
        customerName: bill.customerName,
        roundOff: bill.roundOff,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt printed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to print receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCustomerSearch(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<BillingBloc>(),
        child: const CustomerSearchSheet(),
      ),
    );
  }

  void _showRecentBills(BuildContext context) {
    context.read<BillingBloc>().add(const LoadRecentBills());
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<BillingBloc>(),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Bills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: BlocBuilder<BillingBloc, BillingState>(
                    builder: (context, state) {
                      if (state is BillingRecentLoaded) {
                        if (state.bills.isEmpty) {
                          return const Center(child: Text('No recent bills'));
                        }
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: state.bills.length,
                          itemBuilder: (context, index) {
                            final bill = state.bills[index];
                            return ListTile(
                              leading: Icon(
                                bill.isReturn ? Icons.replay : Icons.receipt,
                                color: bill.isReturn ? Colors.red : Colors.green,
                              ),
                              title: Text(bill.billNumber),
                              subtitle: Text(
                                '${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year} - ${bill.items.length} items',
                              ),
                              trailing: Text(
                                '\u20B9${bill.totalAmount}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        );
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, BillingReady state) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Process Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total: \u20B9${state.totalAmount}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (state.totalDiscount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'You save: \u20B9${state.totalDiscount.toInt()}',
                  style: TextStyle(color: Colors.green[700], fontSize: 14),
                ),
              ),
            const SizedBox(height: 20),
            const Text('Select Payment Mode:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPaymentButton(dialogContext, 'CASH', Icons.money, state),
                _buildPaymentButton(dialogContext, 'UPI', Icons.qr_code, state),
                _buildPaymentButton(dialogContext, 'CARD', Icons.credit_card, state),
                _buildPaymentButton(dialogContext, 'CREDIT', Icons.credit_score, state),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton(
    BuildContext context,
    String mode,
    IconData icon,
    BillingReady state,
  ) {
    return SizedBox(
      width: 100,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          context.read<BillingBloc>().add(
                ProcessPayment(
                  paymentMode: mode,
                  paidAmount: state.totalAmount,
                ),
              );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: const Color(0xFF1B5E20)),
              const SizedBox(height: 4),
              Text(mode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductSearchSheet extends StatefulWidget {
  const ProductSearchSheet({super.key});

  @override
  State<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<ProductSearchSheet> {
  final _searchController = TextEditingController();
  final _productRepo = GetIt.instance<ProductRepository>();
  List<Product> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final result = await _productRepo.getProducts(
      search: query.trim(),
      perPage: 50,
    );

    result.fold(
      (failure) {
        setState(() {
          _results = [];
          _isLoading = false;
          _hasSearched = true;
        });
      },
      (products) {
        setState(() {
          _results = products.where((p) => p.isActive).toList();
          _isLoading = false;
          _hasSearched = true;
        });
      },
    );
  }

  void _addToCart(Product product) {
    final taxAmount = (product.sellingPrice * product.taxRate / 100).round();
    final totalAmount = product.sellingPrice + taxAmount;

    // Get buyer state code from selected customer (if any)
    String? buyerStateCode;
    final billingState = context.read<BillingBloc>().state;
    if (billingState is BillingReady && billingState.customerStateCode != null) {
      buyerStateCode = billingState.customerStateCode;
    }

    context.read<BillingBloc>().add(AddToCart(
      productId: product.id,
      productName: product.name,
      quantity: 1,
      unitPrice: product.sellingPrice,
      taxRate: product.taxRate,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      buyerStateCode: buyerStateCode,
    ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search by name or barcode',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                      onSubmitted: _search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      Navigator.pop(context);
                      final barcode = await context.push<String>('/barcode-scanner');
                      if (barcode != null && barcode.isNotEmpty && context.mounted) {
                        final productRepo = GetIt.instance<ProductRepository>();
                        final result = await productRepo.getProducts(
                          search: barcode,
                          perPage: 10,
                        );
                        result.fold(
                          (failure) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${failure.message}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          (products) {
                            final matched = products.where((p) => p.barcode == barcode).toList();
                            if (matched.isNotEmpty) {
                              _addToCart(matched.first);
                            } else if (products.isNotEmpty) {
                              _addToCart(products.first);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Product not found for barcode'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          },
                        );
                      }
                    },
                    tooltip: 'Scan barcode',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : !_hasSearched
                        ? const Center(child: Text('Type to search products'))
                        : _results.isEmpty
                            ? const Center(child: Text('No products found'))
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _results.length,
                                itemBuilder: (context, index) {
                                  final product = _results[index];
                                  return _buildProductTile(product);
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductTile(Product product) {
    final taxAmount = (product.sellingPrice * product.taxRate / 100).round();
    final priceWithTax = product.sellingPrice + taxAmount;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: product.isLowStock ? Colors.red[100] : Colors.green[100],
          child: Icon(
            product.isLowStock ? Icons.warning : Icons.inventory,
            color: product.isLowStock ? Colors.red : Colors.green,
            size: 20,
          ),
        ),
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\u20B9${product.sellingPrice} + ${product.taxRate}% GST = \u20B9$priceWithTax'),
            if (product.isLowStock)
              Text(
                'Low stock: ${product.currentStock}',
                style: TextStyle(color: Colors.red[700], fontSize: 11),
              ),
          ],
        ),
        trailing: product.isOutOfStock
            ? Text('Out of stock', style: TextStyle(color: Colors.red[700], fontSize: 12))
            : IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF1B5E20)),
                onPressed: () => _addToCart(product),
              ),
      ),
    );
  }
}

class CustomerSearchSheet extends StatefulWidget {
  const CustomerSearchSheet({super.key});

  @override
  State<CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends State<CustomerSearchSheet> {
  final _searchController = TextEditingController();
  final _customerRepo = GetIt.instance<CustomerRepository>();
  List<Customer> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final result = await _customerRepo.getCustomers(
      search: query.trim(),
      perPage: 50,
    );

    result.fold(
      (failure) {
        setState(() {
          _results = [];
          _isLoading = false;
          _hasSearched = true;
        });
      },
      (customers) {
        setState(() {
          _results = customers.where((c) => c.isActive).toList();
          _isLoading = false;
          _hasSearched = true;
        });
      },
    );
  }

  void _selectCustomer(Customer customer) {
    context.read<BillingBloc>().add(SelectCustomer(
      customerId: customer.id,
      customerName: customer.name,
      customerStateCode: customer.state,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search by name or phone',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onSubmitted: _search,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : !_hasSearched
                        ? const Center(child: Text('Search for a customer'))
                        : _results.isEmpty
                            ? const Center(child: Text('No customers found'))
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _results.length,
                                itemBuilder: (context, index) {
                                  final customer = _results[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue[100],
                                      child: Text(
                                        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                        style: TextStyle(color: Colors.blue[800]),
                                      ),
                                    ),
                                    title: Text(customer.name),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (customer.phone != null)
                                          Text(customer.phone!),
                                        Text(
                                          'Type: ${customer.type} | Loyalty: ${customer.loyaltyPoints} pts',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _selectCustomer(customer),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}
