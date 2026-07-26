import 'package:flutter/material.dart';

/// Stock Expiry Processing page.
///
/// Displays expiry batches grouped by urgency (expired, critical, warning, safe),
/// supports write-off of expired items with reason tracking, and provides
/// a summary of stock at risk with total value impact.
class ExpiryProcessingPage extends StatefulWidget {
  const ExpiryProcessingPage({super.key});

  @override
  State<ExpiryProcessingPage> createState() => _ExpiryProcessingPageState();
}

class _ExpiryProcessingPageState extends State<ExpiryProcessingPage> {
  String _filter = 'all';
  int _expiryAlertDays = 30;

  final List<_ExpiryBatch> _batches = [
    _ExpiryBatch(product: 'Amul Butter 100g', batch: 'BATCH-AB1-2025', qty: 20,
      mfg: DateTime.now().subtract(const Duration(days: 240)),
      expiry: DateTime.now().subtract(const Duration(days: 2)),
      price: 5000, status: 'expired'),
    _ExpiryBatch(product: 'Maggi Noodles 70g', batch: 'BATCH-M7-2025', qty: 50,
      mfg: DateTime.now().subtract(const Duration(days: 150)),
      expiry: DateTime.now().add(const Duration(days: 3)),
      price: 1200, status: 'critical'),
    _ExpiryBatch(product: 'Basmati Rice 5kg', batch: 'BATCH-R1-2025', qty: 30,
      mfg: DateTime.now().subtract(const Duration(days: 300)),
      expiry: DateTime.now().add(const Duration(days: 15)),
      price: 42000, status: 'warning'),
    _ExpiryBatch(product: 'Amul Milk 500ml', batch: 'BATCH-AM5-2025', qty: 40,
      mfg: DateTime.now().subtract(const Duration(days: 30)),
      expiry: DateTime.now().add(const Duration(days: 45)),
      price: 2800, status: 'safe'),
    _ExpiryBatch(product: 'Coca-Cola 750ml', batch: 'BATCH-CC7-2025', qty: 25,
      mfg: DateTime.now().subtract(const Duration(days: 90)),
      expiry: DateTime.now().add(const Duration(days: 180)),
      price: 3800, status: 'safe'),
  ];

  List<_ExpiryBatch> get _filteredBatches {
    if (_filter == 'all') return _batches;
    return _batches.where((b) => b.status == _filter).toList();
  }

  int get _totalAtRisk => _batches
      .where((b) => b.status == 'expired' || b.status == 'critical' || b.status == 'warning')
      .fold<int>(0, (s, b) => s + b.qty);

  int get _totalValueAtRisk => _batches
      .where((b) => b.status == 'expired' || b.status == 'critical' || b.status == 'warning')
      .fold<int>(0, (s, b) => s + (b.price * b.qty));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Expiry Processing'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all', child: Text('All Batches')),
              PopupMenuItem(value: 'expired', child: Text('Expired')),
              PopupMenuItem(value: 'critical', child: Text('Critical (≤7 days)')),
              PopupMenuItem(value: 'warning', child: Text('Warning (≤30 days)')),
              PopupMenuItem(value: 'safe', child: Text('Safe (>30 days)')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAlertBanner(),
          _buildSummaryCards(),
          Expanded(child: _buildBatchList()),
        ],
      ),
    );
  }

  Widget _buildAlertBanner() {
    final expiredCount = _batches.where((b) => b.status == 'expired').length;
    final criticalCount = _batches.where((b) => b.status == 'critical').length;

    if (expiredCount == 0 && criticalCount == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.red.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$expiredCount expired, $criticalCount critical batches require attention',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _summaryChip('At Risk', '$_totalAtRisk units', Colors.red),
          const SizedBox(width: 8),
          _summaryChip('Value', '₹${(_totalValueAtRisk / 100).toStringAsFixed(0)}', Colors.orange),
          const SizedBox(width: 8),
          _summaryChip('Batches', '${_batches.length}', Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(
              value: _expiryAlertDays.toDouble(),
              min: 7,
              max: 90,
              divisions: 83,
              label: '$_expiryAlertDays days',
              onChanged: (v) => setState(() => _expiryAlertDays = v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchList() {
    final batches = _filteredBatches;
    if (batches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text('No $_filter batches', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: batches.length,
      itemBuilder: (context, index) {
        final batch = batches[index];
        final daysLeft = batch.expiry.difference(DateTime.now()).inDays;
        final statusColor = _getStatusColor(batch.status);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.2),
              child: Icon(_getStatusIcon(batch.status), color: statusColor, size: 20),
            ),
            title: Text(batch.product, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Batch: ${batch.batch} • Qty: ${batch.qty}', style: const TextStyle(fontSize: 12)),
                Text(
                  daysLeft >= 0 ? 'Expires in $daysLeft days' : 'Expired ${-daysLeft} days ago',
                  style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _handleAction(action, batch),
              itemBuilder: (_) => [
                if (batch.status == 'expired' || batch.status == 'critical')
                  const PopupMenuItem(value: 'writeoff', child: Text('Write Off')),
                const PopupMenuItem(value: 'detail', child: Text('View Details')),
                const PopupMenuItem(value: 'discount', child: Text('Apply Discount')),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleAction(String action, _ExpiryBatch batch) {
    switch (action) {
      case 'writeoff':
        _showWriteOffDialog(batch);
        break;
      case 'detail':
        _showDetailDialog(batch);
        break;
      case 'discount':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apply clearance discount on ${batch.product}')),
        );
        break;
    }
  }

  void _showWriteOffDialog(_ExpiryBatch batch) {
    final reasonController = TextEditingController(text: 'Expired');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Write Off Batch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${batch.product}'),
            Text('Batch: ${batch.batch}'),
            Text('Quantity: ${batch.qty}'),
            Text('Value: ₹${((batch.price * batch.qty) / 100).toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => batch.status = 'written_off');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${batch.product} batch written off')),
              );
            },
            child: const Text('Write Off'),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(_ExpiryBatch batch) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(batch.product),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Batch Number', batch.batch),
            _detailRow('Quantity', '${batch.qty}'),
            _detailRow('Mfg Date', '${batch.mfg.day}/${batch.mfg.month}/${batch.mfg.year}'),
            _detailRow('Expiry Date', '${batch.expiry.day}/${batch.expiry.month}/${batch.expiry.year}'),
            _detailRow('Unit Price', '₹${(batch.price / 100).toStringAsFixed(2)}'),
            _detailRow('Total Value', '₹${((batch.price * batch.qty) / 100).toStringAsFixed(2)}'),
            _detailRow('Status', batch.status.toUpperCase()),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'expired': return Colors.red;
      case 'critical': return Colors.deepOrange;
      case 'warning': return Colors.orange;
      case 'safe': return Colors.green;
      case 'written_off': return Colors.grey;
      default: return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'expired': return Icons.error;
      case 'critical': return Icons.warning_amber;
      case 'warning': return Icons.schedule;
      case 'safe': return Icons.check_circle;
      case 'written_off': return Icons.delete;
      default: return Icons.inventory;
    }
  }
}

class _ExpiryBatch {
  String product;
  String batch;
  int qty;
  DateTime mfg;
  DateTime expiry;
  int price; // paise per unit
  String status;

  _ExpiryBatch({
    required this.product,
    required this.batch,
    required this.qty,
    required this.mfg,
    required this.expiry,
    required this.price,
    required this.status,
  });
}
