import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/orders_bloc.dart';
import '../../domain/entities/sales_order_entity.dart';
import '../../domain/entities/purchase_order_entity.dart';
import '../../../../injection/injection_container.dart';
import 'sales_order_form_page.dart';
import 'purchase_order_form_page.dart';
import 'order_detail_page.dart';

/// Main orders page displaying both sales and purchase orders in a tabbed view.
///
/// The first tab shows sales orders and the second shows purchase orders.
/// Each tab has a searchable list with status chips and a FAB for creating
/// new orders. Tapping an order navigates to the [OrderDetailPage].
///
/// ## Architecture
///
/// Uses [BlocProvider] to inject the [OrdersBloc] at the page level, sharing
/// state across both tabs. The initial load triggers both sales and purchase
/// order fetches in parallel.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _searchController.clear();
        _refreshCurrentTab();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refreshCurrentTab() {
    final bloc = context.read<OrdersBloc>();
    if (_tabController.index == 0) {
      bloc.add(const LoadSalesOrders());
    } else {
      bloc.add(const LoadPurchaseOrders());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrdersBloc>()
        ..add(const LoadSalesOrders())
        ..add(const LoadPurchaseOrders()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Sales Orders', icon: Icon(Icons.shopping_cart)),
              Tab(text: 'Purchase Orders', icon: Icon(Icons.local_shipping)),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search orders...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  final bloc = context.read<OrdersBloc>();
                  if (_tabController.index == 0) {
                    bloc.add(SearchSalesOrders(query: value));
                  } else {
                    bloc.add(SearchPurchaseOrders(query: value));
                  }
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _SalesOrdersTab(),
                  _PurchaseOrdersTab(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton(
              onPressed: () async {
                final isSalesTab = _tabController.index == 0;
                final result = await Navigator.of(context).push(
                  MaterialPageRoute<dynamic>(
                    builder: (_) => isSalesTab
                        ? const SalesOrderFormPage()
                        : const PurchaseOrderFormPage(),
                  ),
                );
                if (result == true && mounted) {
                  _refreshCurrentTab();
                }
              },
              child: const Icon(Icons.add),
            );
          },
        ),
      ),
    );
  }
}

/// Sales orders list tab content.
class _SalesOrdersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersBloc, OrdersState>(
      builder: (context, state) {
        if (state is OrdersLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is OrdersError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${state.message}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<OrdersBloc>().add(const LoadSalesOrders());
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is SalesOrdersLoaded) {
          if (state.orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No sales orders found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to create a new sales order',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: state.orders.length,
            itemBuilder: (context, index) {
              return _SalesOrderCard(order: state.orders[index]);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Purchase orders list tab content.
class _PurchaseOrdersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersBloc, OrdersState>(
      builder: (context, state) {
        if (state is OrdersLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is OrdersError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${state.message}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<OrdersBloc>().add(const LoadPurchaseOrders());
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is PurchaseOrdersLoaded) {
          if (state.orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No purchase orders found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to create a new purchase order',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: state.orders.length,
            itemBuilder: (context, index) {
              return _PurchaseOrderCard(order: state.orders[index]);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Card widget for displaying a single sales order in the list.
class _SalesOrderCard extends StatelessWidget {
  final SalesOrder order;

  const _SalesOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(order.status),
          child: Icon(
            Icons.shopping_cart,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          order.orderNumber,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              order.customerName ?? 'Walk-in Customer',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _StatusChip(status: order.status),
                const Spacer(),
                Text(
                  '₹${(order.totalAmount / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute<dynamic>(
              builder: (_) => OrderDetailPage(
                orderId: order.id,
                orderType: 'sales',
              ),
            ),
          );
          if (result == true && context.mounted) {
            context.read<OrdersBloc>().add(const LoadSalesOrders());
          }
        },
      ),
    );
  }
}

/// Card widget for displaying a single purchase order in the list.
class _PurchaseOrderCard extends StatelessWidget {
  final PurchaseOrder order;

  const _PurchaseOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(order.status),
          child: const Icon(
            Icons.local_shipping,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          order.orderNumber,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              order.supplierName ?? 'Unknown Supplier',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _StatusChip(status: order.status),
                const Spacer(),
                Text(
                  '₹${(order.totalAmount / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute<dynamic>(
              builder: (_) => OrderDetailPage(
                orderId: order.id,
                orderType: 'purchase',
              ),
            ),
          );
          if (result == true && context.mounted) {
            context.read<OrdersBloc>().add(const LoadPurchaseOrders());
          }
        },
      ),
    );
  }
}

/// Status chip widget for displaying order status with color coding.
class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _statusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor(status)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          fontSize: 11,
          color: _statusColor(status),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Returns a color associated with the given order [status].
Color _statusColor(String status) {
  switch (status) {
    case 'draft':
      return Colors.grey;
    case 'pending':
      return Colors.orange;
    case 'confirmed':
      return Colors.blue;
    case 'dispatched':
    case 'received':
      return Colors.purple;
    case 'delivered':
    case 'completed':
      return Colors.green;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}
