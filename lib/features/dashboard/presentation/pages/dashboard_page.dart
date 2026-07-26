import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/dashboard_bloc.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../../sync/presentation/bloc/sync_bloc.dart';
import '../../../../injection/injection_container.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<DashboardBloc>()..add(const LoadDashboard()),
        ),
        BlocProvider(
          create: (_) => sl<SyncBloc>(),
        ),
      ],
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SS MART Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          BlocBuilder<DashboardBloc, DashboardState>(
            builder: (context, state) {
              return IconButton(
                icon: state is DashboardLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                onPressed: () {
                  context.read<DashboardBloc>().add(const RefreshDashboard());
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              _showNotificationsSheet(context);
            },
          ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is DashboardError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${state.message}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<DashboardBloc>().add(const LoadDashboard());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state is DashboardLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<DashboardBloc>().add(const RefreshDashboard());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSyncBanner(context, state.stats.sync),
                    const SizedBox(height: 16),
                    _buildSalesCard(state.stats.sales),
                    const SizedBox(height: 12),
                    _buildSummaryCards(context, state.stats),
                    const SizedBox(height: 12),
                    _buildQuickStatsGrid(context, state.stats),
                    const SizedBox(height: 16),
                    _buildQuickActionButtons(context),
                    const SizedBox(height: 16),
                    _buildLowStockAlertsCard(context, state.stats.inventory),
                    const SizedBox(height: 12),
                    _buildExpiryAlertsCard(context, state.stats.inventory),
                    const SizedBox(height: 16),
                    _buildInventoryAlerts(context, state.stats.inventory),
                    const SizedBox(height: 16),
                    _buildEmployeeActivity(state.stats.employees),
                    const SizedBox(height: 16),
                    _buildLoyaltySummary(state.stats.loyalty),
                    const SizedBox(height: 16),
                    _buildPurchaseSummary(state.stats.purchases),
                    const SizedBox(height: 16),
                    _buildCustomerStats(state.stats.customers),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, DashboardStats stats) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context,
            'Today\'s Sales',
            '₹${stats.sales.todaySales.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
            Icons.receipt_long,
            const Color(0xFF1B5E20),
            '/billing',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Pending Sync',
            '${stats.sync.pendingItems}',
            Icons.sync_problem,
            Colors.orange,
            '/sync',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Low Stock',
            '${stats.inventory.lowStockCount}',
            Icons.warning_amber,
            Colors.red,
            '/inventory',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Expiring Soon',
            '${stats.inventory.nearExpiryCount}',
            Icons.schedule,
            Colors.amber,
            '/inventory/expiry-alerts',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    String route,
  ) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 9, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLowStockAlertsCard(BuildContext context, InventoryStats inventory) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/inventory'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Low Stock Alerts',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${inventory.lowStockCount} products need attention',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${inventory.lowStockCount}',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryAlertsCard(BuildContext context, InventoryStats inventory) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/inventory/expiry-alerts'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.schedule, color: Colors.amber.shade700, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expiring Soon',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${inventory.nearExpiryCount} items expiring within 30 days',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${inventory.nearExpiryCount}',
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButtons(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  context,
                  'New Bill',
                  Icons.point_of_sale,
                  Colors.green,
                  '/billing',
                ),
                _buildActionButton(
                  context,
                  'Add Product',
                  Icons.add_box,
                  Colors.blue,
                  '/products',
                ),
                _buildActionButton(
                  context,
                  'Stock Adjust',
                  Icons.tune,
                  Colors.orange,
                  '/inventory/adjustment',
                ),
                _buildActionButton(
                  context,
                  'Purchase',
                  Icons.shopping_cart,
                  Colors.purple,
                  '/purchases',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  context,
                  'Customers',
                  Icons.people,
                  Colors.teal,
                  '/customers',
                ),
                _buildActionButton(
                  context,
                  'Employees',
                  Icons.badge,
                  Colors.indigo,
                  '/employees',
                ),
                _buildActionButton(
                  context,
                  'Reports',
                  Icons.assessment,
                  Colors.brown,
                  '/reports',
                ),
                _buildActionButton(
                  context,
                  'Sync',
                  Icons.sync,
                  Colors.cyan,
                  '/sync',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    String route,
  ) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBanner(BuildContext context, SyncStats sync) {
    return Card(
      color: sync.isConnected ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              sync.isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: sync.isConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sync.isConnected ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: sync.isConnected ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                  Text(
                    sync.isSyncing
                        ? 'Syncing...'
                        : sync.pendingItems > 0
                            ? '${sync.pendingItems} items pending sync'
                            : 'All data synced',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (sync.pendingItems > 0)
              TextButton(
                onPressed: () {
                  context.read<SyncBloc>().add(const StartSync());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Syncing data...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Sync Now'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesCard(SalesStats sales) {
    return Card(
      color: const Color(0xFF1B5E20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Sales',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${sales.todaySales.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  sales.salesGrowthPercent >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: sales.salesGrowthPercent >= 0
                      ? Colors.green.shade200
                      : Colors.red.shade200,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${sales.salesGrowthPercent >= 0 ? '+' : ''}${sales.salesGrowthPercent.toStringAsFixed(1)}% vs yesterday',
                  style: TextStyle(
                    color: sales.salesGrowthPercent >= 0
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSalesStat('Transactions', '${sales.todayTransactions}'),
                _buildSalesStat('Avg. Bill', '₹${sales.averageTransactionValue}'),
                _buildSalesStat('This Month', '₹${(sales.monthSales / 1000).toStringAsFixed(0)}K'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildQuickStatsGrid(BuildContext context, DashboardStats stats) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.2,
      children: [
        _buildQuickStatCard(
          context,
          'Products',
          '${stats.inventory.totalProducts}',
          Icons.inventory_2,
          Colors.blue,
          '/products',
        ),
        _buildQuickStatCard(
          context,
          'Customers',
          '${stats.customers.totalCustomers}',
          Icons.people,
          Colors.green,
          '/customers',
        ),
        _buildQuickStatCard(
          context,
          'Low Stock',
          '${stats.inventory.lowStockCount}',
          Icons.warning,
          Colors.orange,
          '/inventory',
        ),
        _buildQuickStatCard(
          context,
          'Employees',
          '${stats.employees.clockedInNow}',
          Icons.badge,
          Colors.purple,
          '/employees',
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    String route,
  ) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryAlerts(BuildContext context, InventoryStats inventory) {
    if (inventory.lowStockItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Low Stock Alerts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/inventory'),
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          ...inventory.lowStockItems.map(
            (item) => ListTile(
              dense: true,
              title: Text(item.productName),
              subtitle: Text('Stock: ${item.currentStock} | Reorder: ${item.reorderLevel}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item.currentStock} left',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeActivity(EmployeeStats employees) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employee Activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEmployeeStat('On Duty', '${employees.clockedInNow}', Colors.green),
                _buildEmployeeStat('Active Today', '${employees.activeToday}', Colors.blue),
                _buildEmployeeStat('Total', '${employees.totalEmployees}', Colors.grey),
              ],
            ),
            if (employees.topPerformerName.isNotEmpty) ...[
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Top: ${employees.topPerformerName}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(
                    '₹${employees.topPerformerSales.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLoyaltySummary(LoyaltyStats loyalty) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Loyalty Program',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLoyaltyStat('Members', '${loyalty.totalMembers}'),
                _buildLoyaltyStat('Active', '${loyalty.activeMembers}'),
                _buildLoyaltyStat('Points Issued', '${(loyalty.totalPointsIssued / 1000).toStringAsFixed(0)}K'),
                _buildLoyaltyStat('Redeemed', '${(loyalty.totalPointsRedeemed / 1000).toStringAsFixed(0)}K'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPurchaseSummary(PurchaseStats purchases) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Purchases',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPurchaseStat('Today', '₹${purchases.todayPurchases.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'),
                _buildPurchaseStat('This Month', '₹${(purchases.monthPurchases / 1000).toStringAsFixed(0)}K'),
                _buildPurchaseStat('Pending', '${purchases.pendingOrders}'),
                _buildPurchaseStat('Suppliers', '${purchases.totalSuppliers}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildCustomerStats(CustomerStats customers) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCustomerStat('Total', '${customers.totalCustomers}'),
                _buildCustomerStat('New Today', '${customers.newCustomersToday}'),
                _buildCustomerStat('B2B', '${customers.b2bCustomers}'),
                _buildCustomerStat(
                  'Outstanding',
                  '₹${(customers.totalOutstanding / 1000).toStringAsFixed(0)}K',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    final state = context.read<DashboardBloc>().state;
    if (state is! DashboardLoaded) return;

    final stats = state.stats;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              if (stats.sync.pendingItems > 0)
                ListTile(
                  leading: const Icon(Icons.sync, color: Colors.orange),
                  title: Text('${stats.sync.pendingItems} items pending sync'),
                  subtitle: const Text('Tap Sync Now to upload pending changes'),
                ),
              if (stats.inventory.lowStockCount > 0)
                ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text('${stats.inventory.lowStockCount} products low on stock'),
                  subtitle: const Text('Reorder needed'),
                ),
              if (stats.purchases.pendingPayments > 0)
                ListTile(
                  leading: const Icon(Icons.payment, color: Colors.orange),
                  title: Text('${stats.purchases.pendingPayments} pending payments'),
                  subtitle: const Text('Bills with outstanding amounts'),
                ),
              if (stats.inventory.nearExpiryCount > 0)
                ListTile(
                  leading: const Icon(Icons.schedule, color: Colors.amber),
                  title: Text('${stats.inventory.nearExpiryCount} items near expiry'),
                  subtitle: const Text('Within next 30 days'),
                ),
              if (stats.sync.pendingItems == 0 &&
                  stats.inventory.lowStockCount == 0 &&
                  stats.purchases.pendingPayments == 0 &&
                  stats.inventory.nearExpiryCount == 0)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, size: 48, color: Colors.green),
                        SizedBox(height: 16),
                        Text('All clear!', style: TextStyle(fontSize: 16)),
                        Text('No pending items', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
