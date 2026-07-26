import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/inventory_bloc.dart';
import '../../domain/entities/stock_entity.dart';
import '../../../../injection/injection_container.dart';
import 'stock_adjustment_page.dart';
import 'stock_transfer_page.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InventoryBloc>()..add(const LoadStock()),
      child: const InventoryView(),
    );
  }
}

class InventoryView extends StatelessWidget {
  const InventoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: StockSearchDelegate(
                  inventoryBloc: context.read<InventoryBloc>(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'low_stock') {
                context.read<InventoryBloc>().add(const LoadLowStock());
              } else if (value == 'all') {
                context.read<InventoryBloc>().add(const LoadStock());
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Stock')),
              const PopupMenuItem(value: 'low_stock', child: Text('Low Stock Only')),
            ],
          ),
        ],
      ),
      body: BlocBuilder<InventoryBloc, InventoryState>(
        builder: (context, state) {
          if (state is InventoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is InventoryError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.message}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<InventoryBloc>().add(const LoadStock());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state is InventoryLoaded) {
            if (state.stock.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No stock records found'),
                  ],
                ),
              );
            }
            return _buildStockList(state.stock);
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'adjust',
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute<bool>(
                  builder: (_) => const StockAdjustmentPage(),
                ),
              );
              if (result == true && context.mounted) {
                context.read<InventoryBloc>().add(const LoadStock());
              }
            },
            child: const Icon(Icons.tune),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'transfer',
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute<bool>(
                  builder: (_) => const StockTransferPage(),
                ),
              );
              if (result == true && context.mounted) {
                context.read<InventoryBloc>().add(const LoadStock());
              }
            },
            child: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
    );
  }

  Widget _buildStockList(List<Stock> stockList) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: stockList.length,
      itemBuilder: (context, index) {
        final stock = stockList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: stock.isLowStock
                  ? Colors.red
                  : stock.isExpired
                      ? Colors.orange
                      : Colors.green,
              child: Icon(
                stock.isLowStock
                    ? Icons.warning
                    : stock.isExpired
                        ? Icons.schedule
                        : Icons.check,
                color: Colors.white,
              ),
            ),
            title: Text(
              stock.productName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Available: ${stock.availableQuantity}'),
                    const SizedBox(width: 16),
                    Text('Reserved: ${stock.reservedQuantity}'),
                  ],
                ),
                if (stock.hasBatch)
                  Text(
                    'Batch: ${stock.batchNumber}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (stock.isNearExpiry)
                  Text(
                    'Near Expiry!',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stock.quantity}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: stock.isLowStock ? Colors.red : Colors.black,
                  ),
                ),
                Text(
                  stock.locationId,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<dynamic>(
                  builder: (_) => StockDetailPage(stock: stock),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class StockDetailPage extends StatelessWidget {
  final Stock stock;
  const StockDetailPage({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(stock.productName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.productName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Product ID', stock.productId),
                  _buildDetailRow('Location', stock.locationId),
                  _buildDetailRow('Quantity', '${stock.quantity}'),
                  _buildDetailRow('Reserved', '${stock.reservedQuantity}'),
                  _buildDetailRow('Available', '${stock.availableQuantity}'),
                  if (stock.hasBatch)
                    _buildDetailRow('Batch', stock.batchNumber!),
                  if (stock.expiryDate != null)
                    _buildDetailRow('Expiry', stock.expiryDate.toString().substring(0, 10)),
                  _buildDetailRow('Last Updated', stock.lastUpdated.toString().substring(0, 19)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (stock.isLowStock)
            Card(
              color: Colors.red.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Low Stock Alert - This product needs restocking',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (stock.isNearExpiry)
            Card(
              color: Colors.orange.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Near Expiry - This product will expire within 30 days',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class StockSearchDelegate extends SearchDelegate<Stock?> {
  final InventoryBloc inventoryBloc;

  StockSearchDelegate({required this.inventoryBloc});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    inventoryBloc.add(SearchStock(query: query));
    return BlocBuilder<InventoryBloc, InventoryState>(
      bloc: inventoryBloc,
      builder: (context, state) {
        if (state is InventoryLoaded) {
          if (state.stock.isEmpty) {
            return const Center(child: Text('No results found'));
          }
          return ListView.builder(
            itemCount: state.stock.length,
            itemBuilder: (context, index) {
              final stock = state.stock[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: stock.isLowStock ? Colors.red : Colors.green,
                  child: Text(stock.quantity.toString()),
                ),
                title: Text(stock.productName),
                subtitle: Text('Available: ${stock.availableQuantity} | Location: ${stock.locationId}'),
                onTap: () => close(context, stock),
              );
            },
          );
        }
        if (state is InventoryLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return const Center(child: Text('Type to search'));
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('Type a product name to search'));
    }
    inventoryBloc.add(SearchStock(query: query));
    return BlocBuilder<InventoryBloc, InventoryState>(
      bloc: inventoryBloc,
      builder: (context, state) {
        if (state is InventoryLoaded) {
          return ListView.builder(
            itemCount: state.stock.length,
            itemBuilder: (context, index) {
              final stock = state.stock[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: stock.isLowStock ? Colors.red : Colors.green,
                  child: Text(stock.quantity.toString()),
                ),
                title: Text(stock.productName),
                subtitle: Text('Available: ${stock.availableQuantity}'),
                onTap: () {
                  query = stock.productName;
                  showResults(context);
                },
              );
            },
          );
        }
        return const Center(child: Text('Type to search'));
      },
    );
  }
}
