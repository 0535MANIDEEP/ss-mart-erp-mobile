import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Billing',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more),
            label: 'More',
          ),
        ],
      ),
    );
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/billing')) return 1;
    if (location.startsWith('/products')) return 2;
    if (location.startsWith('/customers')) return 3;
    return 4;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/billing');
        break;
      case 2:
        context.go('/products');
        break;
      case 3:
        context.go('/customers');
        break;
      case 4:
        _showMoreMenu(context);
        break;
    }
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.inventory),
                title: const Text('Inventory'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/inventory');
                },
              ),
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('Categories'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/products/categories');
                },
              ),
              ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('Employees'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/employees');
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Shift Schedules'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/employees/shifts');
                },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: const Text('Purchases'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/purchases');
                },
              ),
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Suppliers'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/suppliers');
                },
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Loyalty'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/loyalty/cards');
                },
              ),
              ListTile(
                leading: const Icon(Icons.assessment),
                title: const Text('Reports'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/reports');
                },
              ),
              ListTile(
                leading: const Icon(Icons.import_export),
                title: const Text('Import / Export'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/import-export');
                },
              ),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sync'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/sync');
                },
              ),
              ListTile(
                leading: const Icon(Icons.print),
                title: const Text('Printer Settings'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/settings/printer');
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Expiry Alerts'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/inventory/expiry-alerts');
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/settings');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
