import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../bloc/accounting_bloc.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_button.dart';

/// Manual journal entry form for creating double-entry bookkeeping records.
///
/// Allows the user to create a ledger entry by specifying the entry date,
/// account head, entry type (debit/credit), amount, description, and
/// optional reference details. Dispatches [CreateJournalEntry] via
/// [AccountingBloc] on save. After successful creation, the form resets
/// for the next entry.
class JournalEntryFormPage extends StatefulWidget {
  const JournalEntryFormPage({super.key});

  @override
  State<JournalEntryFormPage> createState() => _JournalEntryFormPageState();
}

class _JournalEntryFormPageState extends State<JournalEntryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController(
    text: DateTime.now().toString().substring(0, 10),
  );
  final _accountHeadController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceIdController = TextEditingController();

  String _entryType = 'debit';
  String _referenceType = 'journal';

  static const _accountHeads = [
    'Sales Revenue',
    'Cash',
    'Bank',
    'Accounts Receivable',
    'Accounts Payable',
    'Purchases',
    'GST Payable',
    'Expenses',
    'Capital',
    'Drawings',
  ];

  static const _referenceTypes = [
    'journal',
    'bill',
    'purchase',
    'payment',
    'return',
  ];

  @override
  void dispose() {
    _dateController.dispose();
    _accountHeadController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _referenceIdController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final amountRupees = double.tryParse(_amountController.text.trim()) ?? 0;
    final amountPaise = (amountRupees * 100).round();

    final entry = LedgerEntry(
      id: const Uuid().v4(),
      entryDate: DateTime.parse(_dateController.text),
      entryType: _entryType,
      accountHead: _accountHeadController.text.trim(),
      referenceType: _referenceType,
      referenceId: _referenceIdController.text.trim().isEmpty
          ? 'manual-${DateTime.now().millisecondsSinceEpoch}'
          : _referenceIdController.text.trim(),
      amount: amountPaise,
      description: _descriptionController.text.trim(),
      createdAt: DateTime.now(),
    );

    context.read<AccountingBloc>().add(CreateJournalEntry(entry: entry));
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _dateController.text = DateTime.now().toString().substring(0, 10);
      _accountHeadController.clear();
      _amountController.clear();
      _descriptionController.clear();
      _referenceIdController.clear();
      _entryType = 'debit';
      _referenceType = 'journal';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: BlocConsumer<AccountingBloc, AccountingState>(
        listener: (context, state) {
          if (state is JournalEntryCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Journal entry created successfully'),
                backgroundColor: Colors.green,
              ),
            );
            _resetForm();
          } else if (state is AccountingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _dateController,
                  label: 'Entry Date *',
                  prefixIcon: Icons.calendar_today,
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      _dateController.text = date.toString().substring(0, 10);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Date is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _accountHeadController.text.isEmpty
                      ? null
                      : _accountHeadController.text,
                  decoration: const InputDecoration(
                    labelText: 'Account Head *',
                    prefixIcon: Icon(Icons.account_balance),
                    border: OutlineInputBorder(),
                  ),
                  items: _accountHeads
                      .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _accountHeadController.text = value;
                    }
                  },
                  validator: (value) {
                    if (_accountHeadController.text.trim().isEmpty) {
                      return 'Account head is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _referenceType,
                  decoration: const InputDecoration(
                    labelText: 'Reference Type',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                  ),
                  items: _referenceTypes
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t[0].toUpperCase() + t.substring(1)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _referenceType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _referenceIdController,
                  label: 'Reference ID (optional)',
                  prefixIcon: Icons.tag,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Entry Type *',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Debit'),
                        subtitle: const Text('Money out / Asset increase'),
                        value: 'debit',
                        groupValue: _entryType,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _entryType = value);
                          }
                        },
                        activeColor: Colors.red,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Credit'),
                        subtitle: const Text('Money in / Liability increase'),
                        value: 'credit',
                        groupValue: _entryType,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _entryType = value);
                          }
                        },
                        activeColor: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _amountController,
                  label: 'Amount (₹) *',
                  prefixIcon: Icons.currency_rupee,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Amount is required';
                    }
                    final num = double.tryParse(value.trim());
                    if (num == null || num <= 0) {
                      return 'Enter a valid positive amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description *',
                  prefixIcon: Icons.description,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Create Journal Entry',
                  icon: Icons.save,
                  isLoading: state is AccountingLoading,
                  onPressed: state is AccountingLoading ? null : _onSave,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
