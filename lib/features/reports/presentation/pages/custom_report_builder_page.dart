import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../database/app_database.dart';

/// Page for building custom reports with configurable filters and grouping.
class CustomReportBuilderPage extends StatefulWidget {
  const CustomReportBuilderPage({super.key});

  @override
  State<CustomReportBuilderPage> createState() => _CustomReportBuilderPageState();
}

class _CustomReportBuilderPageState extends State<CustomReportBuilderPage> {
  String _selectedModule = 'Bills';
  String _selectedGroupBy = 'Date';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _reportData = [];
  bool _isGenerated = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Report Builder'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report Configuration', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    DropdownButtonFormField<String>(
                      value: _selectedModule,
                      decoration: const InputDecoration(labelText: 'Data Source'),
                      items: const [
                        DropdownMenuItem(value: 'Bills', child: Text('Bills')),
                        DropdownMenuItem(value: 'Products', child: Text('Products')),
                        DropdownMenuItem(value: 'Customers', child: Text('Customers')),
                        DropdownMenuItem(value: 'Stock', child: Text('Stock')),
                        DropdownMenuItem(value: 'Employees', child: Text('Employees')),
                        DropdownMenuItem(value: 'Purchases', child: Text('Purchases')),
                      ],
                      onChanged: (v) { if (v != null) setState(() => _selectedModule = v); },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedGroupBy,
                      decoration: const InputDecoration(labelText: 'Group By'),
                      items: const [
                        DropdownMenuItem(value: 'Date', child: Text('Date')),
                        DropdownMenuItem(value: 'Product', child: Text('Product')),
                        DropdownMenuItem(value: 'Customer', child: Text('Customer')),
                        DropdownMenuItem(value: 'Category', child: Text('Category')),
                        DropdownMenuItem(value: 'Employee', child: Text('Employee')),
                      ],
                      onChanged: (v) { if (v != null) setState(() => _selectedGroupBy = v); },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text('From'),
                            subtitle: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context, initialDate: _startDate,
                                firstDate: DateTime(2020), lastDate: DateTime.now(),
                              );
                              if (picked != null) setState(() => _startDate = picked);
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: const Text('To'),
                            subtitle: Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context, initialDate: _endDate,
                                firstDate: DateTime(2020), lastDate: DateTime.now(),
                              );
                              if (picked != null) setState(() => _endDate = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generateReport,
              icon: const Icon(Icons.assessment),
              label: const Text('Generate Report'),
            ),
            if (_isGenerated) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Results (${_reportData.length} rows)',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Divider(),
                      if (_reportData.isEmpty)
                        const Text('No data found for the selected criteria')
                      else
                        ..._reportData.map((row) => ListTile(
                          dense: true,
                          title: Text(row['group']?.toString() ?? 'N/A'),
                          trailing: Text(row['count']?.toString() ?? '0'),
                        )),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generateReport() async {
    final db = GetIt.instance<AppDatabase>();
    List<Map<String, dynamic>> data = [];

    if (_selectedModule == 'Bills') {
      final bills = await (db.select(db.bills)
        ..where((t) => t.billDate.isBetweenValues(_startDate, _endDate))).get();
      data = _groupByDate(bills.map((b) => b.billDate).toList());
    } else if (_selectedModule == 'Products') {
      final products = await db.select(db.products).get();
      data = [{'group': 'Total Products', 'count': products.length}];
    } else if (_selectedModule == 'Customers') {
      final customers = await db.select(db.customers).get();
      data = [{'group': 'Total Customers', 'count': customers.length}];
    }

    setState(() { _reportData = data; _isGenerated = true; });
  }

  List<Map<String, dynamic>> _groupByDate(List<DateTime> dates) {
    final Map<String, int> grouped = {};
    for (final date in dates) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      grouped[key] = (grouped[key] ?? 0) + 1;
    }
    return grouped.entries.map((e) => {'group': e.key, 'count': e.value}).toList();
  }
}
