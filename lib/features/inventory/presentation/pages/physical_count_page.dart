import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../database/app_database.dart';
import '../../../../shared/utils/helpers.dart';

/// Page for managing physical stock counts / stocktakes.
///
/// Allows warehouse staff to perform physical inventory counts, record
/// counted quantities, and reconcile with system stock.
class PhysicalCountPage extends StatefulWidget {
  const PhysicalCountPage({super.key});

  @override
  State<PhysicalCountPage> createState() => _PhysicalCountPageState();
}

class _PhysicalCountPageState extends State<PhysicalCountPage> {
  List<PhysicalCount> _counts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final db = GetIt.instance<AppDatabase>();
    final counts = await (db.select(db.physicalCounts)..orderBy([(t) => OrderingTerm.desc(t.countDate)])).get();
    setState(() { _counts = counts; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Physical Stock Count'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewCount,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _counts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fact_check, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No physical counts recorded'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _counts.length,
                  itemBuilder: (context, index) {
                    final count = _counts[index];
                    final statusColor = count.status == 'completed'
                        ? Colors.green
                        : count.status == 'in_progress'
                            ? Colors.orange
                            : Colors.grey;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.2),
                          child: Icon(Icons.fact_check, color: statusColor),
                        ),
                        title: Text(count.countNumber),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy HH:mm').format(count.countDate)}\n'
                          'Location: ${count.locationId}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(count.status, style: TextStyle(color: statusColor, fontSize: 12)),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }

  void _startNewCount() {
    final locationController = TextEditingController(text: 'MAIN');
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start New Count'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
            const SizedBox(height: 12),
            TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final db = GetIt.instance<AppDatabase>();
              final countNumber = AppHelpers.generateBillNumber('PC', await db.select(db.physicalCounts).get().then((l) => l.length + 1));
              await db.into(db.physicalCounts).insert(PhysicalCountsCompanion.insert(
                id: const Uuid().v4(),
                countNumber: countNumber,
                locationId: Value(locationController.text),
                status: const Value('draft'),
                notes: Value(notesController.text.isEmpty ? null : notesController.text),
                performedBy: 'current_user',
                countDate: DateTime.now(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                version: const Value(1),
                syncStatus: const Value('pending'),
              ));
              Navigator.pop(context);
              _loadCounts();
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
