import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/accounting_bloc.dart';
import '../../domain/entities/trial_balance.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';

/// Table view showing the trial balance — each account head with debit,
/// credit, and net balance columns. Totals are displayed at the bottom.
///
/// The trial balance verifies that total debits equal total credits across
/// all account heads. A non-zero net total indicates a bookkeeping error.
///
/// Supports optional date range filtering to view the trial balance for
/// a specific accounting period rather than all-time data.
class TrialBalancePage extends StatefulWidget {
  const TrialBalancePage({super.key});

  @override
  State<TrialBalancePage> createState() => _TrialBalancePageState();
}

class _TrialBalancePageState extends State<TrialBalancePage> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrialBalance(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: BlocBuilder<AccountingBloc, AccountingState>(
            builder: (context, state) {
              if (state is AccountingLoading) {
                return const LoadingWidget(message: 'Computing trial balance...');
              }
              if (state is AccountingError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${state.message}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadTrialBalance(context),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              if (state is TrialBalanceLoaded) {
                if (state.rows.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.balance_outlined,
                    title: 'No data for trial balance',
                    subtitle: 'Create bills or journal entries to populate the ledger',
                  );
                }
                return _buildTrialBalanceTable(state.rows);
              }
              return const LoadingWidget(message: 'Loading...');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _selectDateRange,
              child: InputDecorator(
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.date_range, size: 18),
                ),
                child: Text(
                  _startDate != null && _endDate != null
                      ? '${_formatDate(_startDate!)} — ${_formatDate(_endDate!)}'
                      : 'All time (no filter)',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          if (_startDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear filter',
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
                _loadTrialBalance(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTrialBalanceTable(List<TrialBalanceRow> rows) {
    int totalDebit = 0;
    int totalCredit = 0;

    for (final row in rows) {
      totalDebit += row.totalDebit;
      totalCredit += row.totalCredit;
    }

    final netBalance = totalDebit - totalCredit;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade200,
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Account Head',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Debit (₹)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Credit (₹)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Balance (₹)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Table rows
          ...rows.map((row) => _buildRow(row)),
          // Totals row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade800,
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'TOTAL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatPaise(totalDebit),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatPaise(totalCredit),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatPaise(netBalance),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: netBalance == 0 ? Colors.greenAccent : Colors.redAccent,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Balance indicator
          if (netBalance == 0)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Books are balanced',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Out of balance by ₹${(netBalance.abs() / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(TrialBalanceRow row) {
    final isDebitBalance = row.isDebitBalance;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              row.accountHead,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.totalDebit > 0 ? _formatPaise(row.totalDebit) : '—',
              style: TextStyle(
                fontSize: 13,
                color: row.totalDebit > 0 ? Colors.red[700] : Colors.grey,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.totalCredit > 0 ? _formatPaise(row.totalCredit) : '—',
              style: TextStyle(
                fontSize: 13,
                color: row.totalCredit > 0 ? Colors.green[700] : Colors.grey,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatPaise(row.balance),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDebitBalance ? Colors.red[700] : Colors.green[700],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPaise(int paise) {
    final amount = paise / 100;
    if (paise < 0) {
      return '-₹${amount.abs().toStringAsFixed(2)}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadTrialBalance(context);
    }
  }

  void _loadTrialBalance(BuildContext context) {
    context.read<AccountingBloc>().add(
          LoadTrialBalance(
            startDate: _startDate,
            endDate: _endDate,
          ),
        );
  }
}
