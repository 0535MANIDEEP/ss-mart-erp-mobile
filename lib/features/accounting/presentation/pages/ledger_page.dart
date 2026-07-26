import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/accounting_bloc.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';

/// Scrollable list of ledger entries with date range filtering.
///
/// Displays all financial transactions (debits and credits) in reverse
/// chronological order. Each entry shows the account head, description,
/// amount, and a colored badge indicating debit (red) or credit (green).
///
/// The date range filter allows narrowing the view to a specific accounting
/// period. When no filter is applied, all entries are shown.
class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _filterType;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: BlocBuilder<AccountingBloc, AccountingState>(
            builder: (context, state) {
              if (state is AccountingLoading) {
                return const LoadingWidget(message: 'Loading ledger...');
              }
              if (state is AccountingError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${state.message}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadEntries(context),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              if (state is LedgerLoaded) {
                if (state.entries.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.menu_book_outlined,
                    title: 'No ledger entries found',
                    subtitle: _startDate != null
                        ? 'Try adjusting the date range'
                        : 'Entries are auto-generated from bills and purchases',
                  );
                }
                return _buildLedgerList(state.entries);
              }
              // Auto-load on first build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (state is AccountingInitial) {
                  _loadEntries(context);
                }
              });
              return const LoadingWidget(message: 'Loading ledger...');
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
                      : 'Select date range',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by type',
            onSelected: (value) {
              setState(() => _filterType = value);
              _loadEntries(context);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All Entries')),
              const PopupMenuItem(value: 'debit', child: Text('Debits Only')),
              const PopupMenuItem(value: 'credit', child: Text('Credits Only')),
            ],
          ),
          if (_startDate != null || _filterType != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear filters',
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _filterType = null;
                });
                _loadEntries(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLedgerList(List<LedgerEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _LedgerEntryCard(entry: entry);
      },
    );
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
      _loadEntries(context);
    }
  }

  void _loadEntries(BuildContext context) {
    if (_startDate != null && _endDate != null) {
      context.read<AccountingBloc>().add(
            LoadLedgerByDateRange(
              startDate: _startDate!,
              endDate: _endDate!,
            ),
          );
    } else {
      context.read<AccountingBloc>().add(
            LoadLedger(entryType: _filterType),
          );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

/// Card widget for a single ledger entry.
class _LedgerEntryCard extends StatelessWidget {
  final LedgerEntry entry;

  const _LedgerEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDebit = entry.isDebit;
    final color = isDebit ? Colors.red : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                isDebit ? 'DR' : 'CR',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.accountHead,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.description,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDate(entry.entryDate)} · ${entry.referenceType}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₹${(entry.amount / 100).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
