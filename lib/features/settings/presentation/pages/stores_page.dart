import 'package:flutter/material.dart';

/// Multi-Location stores management page.
///
/// Lists all store locations with stock summaries, supports
/// stock transfers between locations, and displays per-location
/// inventory with real-time quantities.
class StoresPage extends StatefulWidget {
  const StoresPage({super.key});

  @override
  State<StoresPage> createState() => _StoresPageState();
}

class _StoresPageState extends State<StoresPage> {
  final List<_Store> _stores = [
    _Store(id: '1', name: 'SS Mart — Main Branch', code: 'MAIN', address: '123 Market Road', city: 'Hyderabad', phone: '040-12345678', manager: 'Sneha Reddy', isMain: true, productCount: 25, totalQty: 2840, totalValue: 12500000),
    _Store(id: '2', name: 'SS Mart — Branch 2', code: 'BR2', address: '456 Commercial Street', city: 'Hyderabad', phone: '040-87654321', manager: 'Ravi Kumar', isMain: false, productCount: 18, totalQty: 1200, totalValue: 5200000),
    _Store(id: '3', name: 'SS Mart — Warehouse', code: 'WH1', address: '789 Industrial Area', city: 'Hyderabad', phone: '040-11223344', manager: 'Sneha Reddy', isMain: false, productCount: 22, totalQty: 4500, totalValue: 18000000),
  ];

  final List<_Transfer> _transfers = [
    _Transfer(number: 'TRF-0001', from: 'MAIN', to: 'BR2', date: DateTime.now().subtract(const Duration(days: 2)), qty: 50, status: 'received'),
    _Transfer(number: 'TRF-0002', from: 'WH1', to: 'MAIN', date: DateTime.now().subtract(const Duration(days: 1)), qty: 120, status: 'in_transit'),
    _Transfer(number: 'TRF-0003', from: 'MAIN', to: 'WH1', date: DateTime.now(), qty: 30, status: 'pending'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Multi-Location'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Locations'),
              Tab(text: 'Transfers'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_location_alt),
              onPressed: () => _showAddStoreDialog(),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildLocationsTab(),
            _buildTransfersTab(),
        ]),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showNewTransferDialog(),
          child: const Icon(Icons.swap_horiz),
          tooltip: 'New Transfer',
        ),
      ),
    );
  }

  Widget _buildLocationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _stores.map((store) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: store.isMain
                ? Colors.blue.withValues(alpha: 0.2)
                : Colors.green.withValues(alpha: 0.2),
            child: Icon(
              store.isMain ? Icons.store : Icons.storefront,
              color: store.isMain ? Colors.blue : Colors.green,
            ),
          ),
          title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${store.code} • ${store.manager}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(Icons.location_on, store.address),
                  _infoRow(Icons.phone, store.phone),
                  _infoRow(Icons.person, store.manager),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statColumn('${store.productCount}', 'Products'),
                      _statColumn('${store.totalQty}', 'Qty'),
                      _statColumn('₹${(store.totalValue / 100000).toStringAsFixed(1)}L', 'Value'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showTransferFromDialog(store),
                          icon: const Icon(Icons.upload, size: 16),
                          label: const Text('Send Stock'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Receive'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildTransfersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transfers.length,
      itemBuilder: (context, index) {
        final t = _transfers[index];
        final statusColor = _getTransferStatusColor(t.status);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.2),
              child: Icon(Icons.swap_horiz, color: statusColor, size: 20),
            ),
            title: Text(t.number, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${t.from} → ${t.to} • ${t.qty} units • ${_formatDate(t.date)}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(t.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
        ],
      ),
    );
  }

  Widget _statColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Color _getTransferStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'in_transit': return Colors.blue;
      case 'received': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddStoreDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final managerController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Store Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Store Name', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Code', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: managerController, decoration: const InputDecoration(labelText: 'Manager', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() => _stores.add(_Store(
                id: '${_stores.length + 1}',
                name: nameController.text,
                code: codeController.text,
                address: addressController.text,
                city: '',
                phone: phoneController.text,
                manager: managerController.text,
                isMain: false,
                productCount: 0,
                totalQty: 0,
                totalValue: 0,
              )));
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showTransferFromDialog(_Store store) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('From: ${store.name}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'To Location', border: OutlineInputBorder()),
              items: _stores
                  .where((s) => s.id != store.id)
                  .map((s) => DropdownMenuItem(value: s.code, child: Text(s.code)))
                  .toList(),
              onChanged: (_) {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transfer created')),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showNewTransferDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Stock Transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'From Location', border: OutlineInputBorder()),
              items: _stores.map((s) => DropdownMenuItem(value: s.code, child: Text(s.name))).toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'To Location', border: OutlineInputBorder()),
              items: _stores.map((s) => DropdownMenuItem(value: s.code, child: Text(s.name))).toList(),
              onChanged: (_) {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _Store {
  final String id;
  final String name;
  final String code;
  final String address;
  final String city;
  final String phone;
  final String manager;
  final bool isMain;
  final int productCount;
  final int totalQty;
  final int totalValue;

  _Store({
    required this.id, required this.name, required this.code,
    required this.address, required this.city, required this.phone,
    required this.manager, required this.isMain,
    required this.productCount, required this.totalQty, required this.totalValue,
  });
}

class _Transfer {
  final String number;
  final String from;
  final String to;
  final DateTime date;
  final int qty;
  final String status;

  _Transfer({
    required this.number, required this.from, required this.to,
    required this.date, required this.qty, required this.status,
  });
}
