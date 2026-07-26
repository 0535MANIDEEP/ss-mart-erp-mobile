import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/expenses_bloc.dart';
import '../../domain/entities/expense.dart';

/// Form page for creating or editing an expense record.
///
/// Provides fields for category selection, amount, date, payment mode,
/// payee, and description. Validates required fields before submission
/// and dispatches [AddExpense] or [UpdateExpense] events to the BLoC.
/// Supports both creation mode (null expense) and edit mode (existing expense).
class ExpenseFormPage extends StatefulWidget {
  final Expense? expense;

  const ExpenseFormPage({super.key, this.expense});

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _payeeController;
  late TextEditingController _descriptionController;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  String _selectedPaymentMode = 'CASH';
  bool _isRecurring = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final exp = widget.expense;
    _amountController = TextEditingController(
      text: exp != null ? (exp.amount / 100).toStringAsFixed(2) : '',
    );
    _payeeController = TextEditingController(text: exp?.payee ?? '');
    _descriptionController = TextEditingController(text: exp?.description ?? '');
    _selectedCategoryId = exp?.expenseCategoryId;
    _selectedDate = exp?.expenseDate ?? DateTime.now();
    _selectedPaymentMode = exp?.paymentMode ?? 'CASH';
    _isRecurring = exp?.isRecurring ?? false;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _payeeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amountInPaise = (double.parse(_amountController.text) * 100).toInt();

    if (_isEditing) {
      final updated = widget.expense!.copyWith(
        expenseCategoryId: _selectedCategoryId,
        expenseDate: _selectedDate,
        amount: amountInPaise,
        paymentMode: _selectedPaymentMode,
        payee: _payeeController.text.isEmpty ? null : _payeeController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        isRecurring: _isRecurring,
      );
      context.read<ExpensesBloc>().add(UpdateExpense(updated));
    } else {
      final expense = Expense(
        id: '',
        expenseNumber: '',
        expenseCategoryId: _selectedCategoryId,
        expenseDate: _selectedDate,
        amount: amountInPaise,
        paymentMode: _selectedPaymentMode,
        payee: _payeeController.text.isEmpty ? null : _payeeController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        isRecurring: _isRecurring,
        createdAt: DateTime.now(),
      );
      context.read<ExpensesBloc>().add(AddExpense(expense));
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                context.read<ExpensesBloc>().add(
                  DeleteExpenseEvent(widget.expense!.id),
                );
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Amount is required';
                if (double.tryParse(v) == null) return 'Enter a valid amount';
                if (double.parse(v) <= 0) return 'Amount must be positive';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category
            BlocBuilder<ExpensesBloc, ExpensesState>(
              buildWhen: (prev, curr) => prev.categories != curr.categories,
              builder: (context, state) {
                return DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: state.categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                );
              },
            ),
            const SizedBox(height: 16),

            // Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Expense Date'),
              subtitle: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            const Divider(),

            // Payment mode
            DropdownButtonFormField<String>(
              value: _selectedPaymentMode,
              decoration: const InputDecoration(
                labelText: 'Payment Mode',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
              ),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                DropdownMenuItem(value: 'BANK', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'CARD', child: Text('Card')),
                DropdownMenuItem(value: 'CREDIT', child: Text('Credit')),
              ],
              onChanged: (v) => setState(() => _selectedPaymentMode = v!),
            ),
            const SizedBox(height: 16),

            // Payee
            TextFormField(
              controller: _payeeController,
              decoration: const InputDecoration(
                labelText: 'Payee / Vendor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 16),

            // Recurring
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recurring Expense'),
              subtitle: Text(_isRecurring ? 'This expense repeats periodically' : 'One-time expense'),
              value: _isRecurring,
              onChanged: (v) => setState(() => _isRecurring = v),
            ),
            const SizedBox(height: 24),

            // Submit
            FilledButton.icon(
              onPressed: _submit,
              icon: Icon(_isEditing ? Icons.save : Icons.add),
              label: Text(_isEditing ? 'Save Changes' : 'Add Expense'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
