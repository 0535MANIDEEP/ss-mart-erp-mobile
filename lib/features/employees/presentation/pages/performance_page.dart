import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import '../../../../database/app_database.dart';

/// Page for viewing employee performance metrics and sales data.
class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key});

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  List<Map<String, dynamic>> _employeePerformance = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPerformance();
  }

  Future<void> _loadPerformance() async {
    final db = GetIt.instance<AppDatabase>();
    final employees = await (db.select(db.employees)..where((t) => t.isActive.equals(true))).get();
    final bills = await db.select(db.bills).get();
    final attendance = await db.select(db.attendance).get();

    List<Map<String, dynamic>> performance = [];
    for (final emp in employees) {
      final empBills = bills.where((b) => b.createdBy == emp.id).toList();
      final empAttendance = attendance.where((a) => a.employeeId == emp.id).toList();
      final totalSales = empBills.fold<int>(0, (sum, b) => sum + b.totalAmount);
      final totalBills = empBills.length;
      final daysPresent = empAttendance.where((a) => a.status == 'present').length;
      performance.add({
        'employee': emp,
        'totalSales': totalSales,
        'totalBills': totalBills,
        'daysPresent': daysPresent,
        'attendanceRate': empAttendance.isEmpty ? 0.0 : (daysPresent / empAttendance.length * 100),
      });
    }
    performance.sort((a, b) => (b['totalSales'] as int).compareTo(a['totalSales'] as int));
    setState(() { _employeePerformance = performance; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Performance'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _employeePerformance.length,
              itemBuilder: (context, index) {
                final perf = _employeePerformance[index];
                final emp = perf['employee'] as Employee;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(child: Text(emp.name[0].toUpperCase())),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(emp.name, style: Theme.of(context).textTheme.titleMedium),
                                  Text(emp.role, style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMetric('Sales', NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(perf['totalSales'] / 100)),
                            _buildMetric('Bills', '${perf['totalBills']}'),
                            _buildMetric('Days', '${perf['daysPresent']}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
