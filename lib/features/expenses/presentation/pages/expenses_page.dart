import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/expenses_bloc.dart';
import 'expense_form_page.dart';

/// List page displaying all recorded business expenses.
///
/// Shows expenses in a chronological card list with category badges,
/// payment mode chips, and amount highlights. Supports date-range
/// filtering via a top filter bar and provides a FAB to add new expenses.
/// Each expense card is tappable to view details or edit.
class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    context.read<ExpensesBloc>().add(const LoadExpenses());
    context.read<ExpensesBloc>().add(const LoadExpenseCategories());
  }

  void _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    context.read<ExpensesBloc>().add(LoadExpenses(
      startDate: _startDate,
      endDate: _endDate,
      categoryId: _selectedCategoryId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDateRange,
            tooltip: 'Filter by date range',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: BlocBuilder<ExpensesBloc, ExpensesState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.error != null) {
                  return Center(child: Text('Error: ${state.error}'));
                }
                if (state.expenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No expenses found', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Text('Tap + to add your first expense', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  );
                }
                return _buildExpenseList(state);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar() {
    return BlocBuilder<ExpensesBloc, ExpensesState>(
      buildWhen: (prev, curr) => prev.categories != curr.categories,
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  hint: const Text('All Categories'),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Categories')),
                    ...state.categories.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedCategoryId = value);
                    _applyFilters();
                  },
                ),
              ),
              if (_startDate != null) ...[
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onDeleted: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    _applyFilters();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseList(ExpensesState state) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.expenses.length,
      itemBuilder: (context, index) {
        final expense = state.expenses[index];
        final categoryColor = _getCategoryColor(expense.categoryName);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: categoryColor.withValues(alpha: 0.2),
              child: Icon(Icons.receipt_long, color: categoryColor, size: 20),
            ),
            title: Text(
              expense.description ?? expense.payee ?? expense.expenseNumber,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${expense.categoryName ?? "Uncategorized"} • ${expense.paymentMode}',
                  // ignore: lines_longer_than_80_chars
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  expense.formattedAmount,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 15,
                  ),
                ),
                Text(
                  DateFormat('dd MMM').format(expense.expenseDate),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            onTap: () => _navigateToForm(context, expense: expense),
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String? categoryName) {
    switch (categoryName) {
      case 'Rent':
        return const Color(0xFFF44336);
      case 'Utilities':
        return const Color(0xFFFF9800);
      case 'Salary':
        return const Color(0xFF4CAF50);
      case 'Transport':
        return const Color(0xFF2196F3);
      case 'Marketing':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF607D8B);
    }
  }

  void _navigateToForm(BuildContext context, {dynamic expense}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ExpensesBloc>(),
          child: ExpenseFormPage(expense: expense),
        ),
      ),
    ).then((_) {
      _applyFilters();
    });
  }
}
