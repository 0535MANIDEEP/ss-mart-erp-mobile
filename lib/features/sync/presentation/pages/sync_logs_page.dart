import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../database/app_database.dart';

/// Page displaying the sync queue history/logs.
class SyncLogsPage extends StatefulWidget {
  const SyncLogsPage({super.key});

  @override
  State<SyncLogsPage> createState() => _SyncLogsPageState();
}

class _SyncLogsPageState extends State<SyncLogsPage> {
  List<SyncQueueData> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final db = GetIt.instance<AppDatabase>();
    final logs = await (db.select(db.syncQueue)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
    setState(() { _logs = logs; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Logs'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No sync history'))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final statusColor = log.status == 'completed'
                        ? Colors.green
                        : log.status == 'failed'
                            ? Colors.red
                            : log.status == 'syncing'
                                ? Colors.orange
                                : Colors.grey;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.2),
                          child: Icon(
                            log.status == 'completed'
                                ? Icons.check
                                : log.status == 'failed'
                                    ? Icons.error
                                    : Icons.sync,
                            color: statusColor,
                          ),
                        ),
                        title: Text('${log.entityType} - ${log.operation}'),
                        subtitle: Text(
                          '${log.entityId.substring(0, 8)}...\n'
                          '${DateFormat('dd/MM/yyyy HH:mm').format(log.createdAt)}',
                          style: const TextStyle(fontSize: 12),
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
                              child: Text(
                                log.status,
                                style: TextStyle(color: statusColor, fontSize: 10),
                              ),
                            ),
                            if (log.error != null) ...[
                              const SizedBox(height: 4),
                              const Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
