import 'package:flutter/material.dart';

/// Day-End / Cash Register management page.
///
/// Handles cash register open/close with denomination counting,
/// expected vs actual cash reconciliation, and transaction history.
class DayEndPage extends StatefulWidget {
  const DayEndPage({super.key});

  @override
  State<DayEndPage> createState() => _DayEndPageState();
}

class _DayEndPageState extends State<DayEndPage> {
  bool _sessionOpen = true;
  final _openingBalanceController = TextEditingController(text: '5000');
  final _actualCashController = TextEditingController();
  final _notesController = TextEditingController();

  final List<_DayTransaction> _transactions = [
    _DayTransaction(type: 'sale', amount: 44200, description: 'BILL-0001', mode: 'CASH', time: '09:15 AM'),
    _DayTransaction(type: 'sale', amount: 16200, description: 'BILL-0002', mode: 'UPI', time: '10:30 AM'),
    _DayTransaction(type: 'sale', amount: 8500, description: 'BILL-0003', mode: 'CASH', time: '11:45 AM'),
    _DayTransaction(type: 'payment_out', amount: 50000, description: 'Payment to HUL Distributor', mode: 'BANK', time: '02:00 PM'),
    _DayTransaction(type: 'expense', amount: 1800, description: 'Fuel refill', mode: 'CASH', time: '03:30 PM'),
  ];

  final Map<String, int> _denominations = {
    '2000': 0, '500': 0, '200': 0, '100': 0,
    '50': 0, '20': 0, '10': 0, '5': 0, '2': 0, '1': 0,
  };

  @override
  void dispose() {
    _openingBalanceController.dispose();
    _actualCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _totalSales => _transactions
      .where((t) => t.type == 'sale')
      .fold<int>(0, (s, t) => s + t.amount);

  int get _totalReturns => _transactions
      .where((t) => t.type == 'return')
      .fold<int>(0, (s, t) => s + t.amount);

  int get _totalPaymentsOut => _transactions
      .where((t) => t.type == 'payment_out' || t.type == 'expense')
      .fold<int>(0, (s, t) => s + t.amount);

  int get _openingBalance => (double.tryParse(_openingBalanceController.text) ?? 0).round();
  int get _expectedCash => _openingBalance + _totalSales - _totalReturns - _totalPaymentsOut;
  int get _actualCash => _denominations.entries.fold<int>(0, (s, e) => s + int.parse(e.key) * e.value);
  int get _discrepancy => _actualCash - _expectedCash;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cash Register'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Register'),
              Tab(text: 'Transactions'),
              Tab(text: 'Denominations'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRegisterTab(),
            _buildTransactionsTab(),
            _buildDenominationsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _sessionOpen ? _closeSession() : _openSession(),
          label: Text(_sessionOpen ? 'Close Register' : 'Open Register'),
          icon: Icon(_sessionOpen ? Icons.lock_open : Icons.lock),
        ),
      ),
    );
  }

  Widget _buildRegisterTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: _sessionOpen
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _sessionOpen ? Colors.green : Colors.grey,
                  child: Icon(
                    _sessionOpen ? Icons.lock_open : Icons.lock,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sessionOpen ? 'Session Open' : 'Session Closed',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _sessionOpen ? 'Opened at 09:00 AM today' : 'Last closed at 05:00 PM',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _summaryRow('Opening Balance', '₹${(_openingBalance / 100).toStringAsFixed(2)}'),
        _summaryRow('Total Sales', '₹${(_totalSales / 100).toStringAsFixed(2)}', color: Colors.green),
        _summaryRow('Total Returns', '₹${(_totalReturns / 100).toStringAsFixed(2)}', color: Colors.red),
        _summaryRow('Payments Out', '₹${(_totalPaymentsOut / 100).toStringAsFixed(2)}', color: Colors.orange),
        const Divider(height: 24),
        _summaryRow('Expected Cash', '₹${(_expectedCash / 100).toStringAsFixed(2)}', bold: true),
        _summaryRow('Actual Cash (counted)', '₹${(_actualCash / 100).toStringAsFixed(2)}', bold: true),
        _summaryRow(
          'Discrepancy',
          '₹${(_discrepancy / 100).toStringAsFixed(2)}',
          color: _discrepancy == 0 ? Colors.green : Colors.red,
          bold: true,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today\'s Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statColumn('${_transactions.where((t) => t.type == 'sale').length}', 'Bills'),
                    _statColumn('${_transactions.length}', 'Transactions'),
                    _statColumn(
                      '₹${(_discrepancy / 100).toStringAsFixed(0)}',
                      'Discrepancy',
                      color: _discrepancy == 0 ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return const Center(child: Text('No transactions today'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final t = _transactions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getTxColor(t.type).withValues(alpha: 0.2),
              child: Icon(_getTxIcon(t.type), color: _getTxColor(t.type), size: 20),
            ),
            title: Text(t.description),
            subtitle: Text('${t.mode} • ${t.time}'),
            trailing: Text(
              '${t.type == 'payment_out' || t.type == 'expense' ? '-' : '+'}₹${(t.amount / 100).toStringAsFixed(2)}',
              style: TextStyle(
                color: t.type == 'payment_out' || t.type == 'expense' ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDenominationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Count Cash by Denomination',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                ..._denominations.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text('₹${e.key}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                setState(() {
                                  _denominations[e.key] = (_denominations[e.key]! - 1).clamp(0, 999);
                                });
                              },
                            ),
                            SizedBox(
                              width: 48,
                              child: Text(
                                '${e.value}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                setState(() {
                                  _denominations[e.key] = _denominations[e.key]! + 1;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          '₹${(int.parse(e.key) * e.value / 100).toStringAsFixed(2)}',
                          textAlign: TextAlign.end,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Counted:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      '₹${(_actualCash / 100).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _discrepancy == 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String value, String label, {Color? color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Color _getTxColor(String type) {
    switch (type) {
      case 'sale': return Colors.green;
      case 'return': return Colors.red;
      case 'payment_out': return Colors.orange;
      case 'expense': return Colors.purple;
      case 'adjustment': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getTxIcon(String type) {
    switch (type) {
      case 'sale': return Icons.receipt;
      case 'return': return Icons.replay;
      case 'payment_out': return Icons.money_off;
      case 'expense': return Icons.receipt_long;
      case 'adjustment': return Icons.tune;
      default: return Icons.circle;
    }
  }

  void _openSession() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Cash Register'),
        content: TextField(
          controller: _openingBalanceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Opening Balance (₹)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() => _sessionOpen = true);
              Navigator.pop(ctx);
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  void _closeSession() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Cash Register'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Expected Cash: ₹${(_expectedCash / 100).toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: _actualCashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Actual Cash Counted (₹)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() => _sessionOpen = false);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_discrepancy == 0
                      ? 'Session closed — balanced!'
                      : 'Session closed — discrepancy: ₹${(_discrepancy / 100).toStringAsFixed(2)}'),
                  backgroundColor: _discrepancy == 0 ? Colors.green : Colors.orange,
                ),
              );
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DayTransaction {
  final String type;
  final int amount;
  final String description;
  final String mode;
  final String time;

  _DayTransaction({
    required this.type,
    required this.amount,
    required this.description,
    required this.mode,
    required this.time,
  });
}
