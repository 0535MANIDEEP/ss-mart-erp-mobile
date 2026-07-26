import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/purchases_bloc.dart';
import '../../domain/entities/purchase_entity.dart';
import '../../../../injection/injection_container.dart';
import 'purchase_form_page.dart';
import 'purchase_detail_page.dart';

class PurchasesPage extends StatelessWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PurchasesBloc>()..add(const LoadPurchases()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Purchases'),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                _showFilterDialog(context);
              },
            ),
          ],
        ),
        body: BlocBuilder<PurchasesBloc, PurchasesState>(
          builder: (context, state) {
            if (state is PurchasesLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is PurchasesError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${state.message}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<PurchasesBloc>().add(const LoadPurchases());
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            if (state is PurchasesLoaded) {
              if (state.purchases.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No purchases found'),
                    ],
                  ),
                );
              }
              return _buildPurchasesList(state.purchases);
            }
            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => const PurchaseFormPage(),
              ),
            );
            if (result == true && context.mounted) {
              context.read<PurchasesBloc>().add(const LoadPurchases());
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildPurchasesList(List<Purchase> purchases) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: purchases.length,
      itemBuilder: (context, index) {
        final purchase = purchases[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: purchase.isPending
                  ? Colors.orange
                  : purchase.isReceived
                      ? Colors.green
                      : Colors.red,
              child: Icon(
                purchase.isPending
                    ? Icons.schedule
                    : purchase.isReceived
                        ? Icons.check
                        : Icons.cancel,
                color: Colors.white,
              ),
            ),
            title: Text('Purchase #${purchase.purchaseNumber}'),
            subtitle: Text(
              'Supplier: ${purchase.supplierName ?? 'Unknown'}\n'
              '${purchase.items.length} items',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${purchase.totalAmount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  purchase.purchaseDate.toString().substring(0, 10),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            onTap: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => PurchaseDetailPage(purchase: purchase),
                ),
              );
              if (result == true && context.mounted) {
                context.read<PurchasesBloc>().add(const LoadPurchases());
              }
            },
          ),
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    DateTime? startDate;
    DateTime? endDate;
    String? selectedSupplier;

    final suppliers = <String>['All Suppliers', 'Supplier A', 'Supplier B', 'Supplier C'];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Purchases'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Date Range'),
                subtitle: Text(
                  startDate != null && endDate != null
                      ? '${startDate.toString().substring(0, 10)} to ${endDate.toString().substring(0, 10)}'
                      : 'Select date range',
                ),
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      startDate = picked.start;
                      endDate = picked.end;
                    });
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Supplier'),
                subtitle: Text(selectedSupplier ?? 'All Suppliers'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('Select Supplier'),
                      children: suppliers.map((s) => SimpleDialogOption(
                        onPressed: () {
                          setDialogState(() {
                            selectedSupplier = s == 'All Suppliers' ? null : s;
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(s),
                      )).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Filters applied: ${startDate != null ? '${startDate.toString().substring(0, 10)} - ${endDate.toString().substring(0, 10)}' : 'No date filter'}'
                      '${selectedSupplier != null ? ', $selectedSupplier' : ''}',
                    ),
                  ),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
