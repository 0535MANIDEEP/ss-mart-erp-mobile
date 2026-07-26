import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../database/app_database.dart';

/// Page for viewing the inventory stock audit trail.
///
/// Displays a chronological log of all stock-affecting operations
/// (sales, purchases, adjustments, transfers) with before/after snapshots.
class StockAuditTrailPage extends StatefulWidget {
  const StockAuditTrailPage({super.key});

  @override
  State<StockAuditTrailPage> createState() => _StockAuditTrailPageState();
}

class _StockAuditTrailPageState extends State<StockAuditTrailPage> {
  List<StockAuditTrailData> _entries = [];
  bool _isLoading = true;
  String? _filterProduct;

  @override
  void initState() {
    super.initState();
    _loadAuditTrail();
  }

  Future<void> _loadAuditTrail() async {
    final db = GetIt.instance<AppDatabase>();
    final query = db.select(db.stockAuditTrail)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (_filterProduct != null) {
      query.where((t) => t.productId.equals(_filterProduct!));
    }
    final entries = await query.get();
    setState(() { _entries = entries; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Audit Trail'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No audit trail entries'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final changeColor = entry.quantityChange > 0
                        ? Colors.green
                        : entry.quantityChange < 0
                            ? Colors.red
                            : Colors.grey;
                    final operationIcon = entry.operationType == 'sale'
                        ? Icons.shopping_cart
                        : entry.operationType == 'purchase'
                            ? Icons.local_shipping
                            : entry.operationType == 'adjustment'
                                ? Icons.tune
                                : entry.operationType == 'transfer'
                                    ? Icons.swap_horiz
                                    : Icons.inventory;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: changeColor.withOpacity(0.2),
                          child: Icon(operationIcon, color: changeColor, size: 20),
                        ),
                        title: Text('${entry.operationType} - ${entry.productName}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Qty: ${entry.quantityBefore} → ${entry.quantityAfter} (${entry.quantityChange > 0 ? '+' : ''}${entry.quantityChange})'),
                            if (entry.reason != null) Text('Reason: ${entry.reason}', style: const TextStyle(fontSize: 12)),
                            Text(DateFormat('dd/MM/yyyy HH:mm').format(entry.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Filter by Operation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('All'), onTap: () { setState(() => _filterProduct = null); Navigator.pop(context); _loadAuditTrail(); }),
            ListTile(title: const Text('Sales'), onTap: () { Navigator.pop(context); }),
            ListTile(title: const Text('Purchases'), onTap: () { Navigator.pop(context); }),
            ListTile(title: const Text('Adjustments'), onTap: () { Navigator.pop(context); }),
            ListTile(title: const Text('Transfers'), onTap: () { Navigator.pop(context); }),
          ],
        ),
      ),
    );
  }
}
