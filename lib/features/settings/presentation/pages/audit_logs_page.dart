import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../database/app_database.dart';

/// Page for viewing the system audit trail.
class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  List<AuditLog> _logs = [];
  bool _isLoading = true;
  String? _filterEntityType;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final db = GetIt.instance<AppDatabase>();
    final query = db.select(db.auditLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (_filterEntityType != null) {
      query.where((t) => t.entityType.equals(_filterEntityType!));
    }
    final logs = await query.get();
    setState(() { _logs = logs; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() { _filterEntityType = value; _isLoading = true; });
              _loadLogs();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All')),
              const PopupMenuItem(value: 'Product', child: Text('Products')),
              const PopupMenuItem(value: 'Customer', child: Text('Customers')),
              const PopupMenuItem(value: 'Bill', child: Text('Bills')),
              const PopupMenuItem(value: 'Stock', child: Text('Stock')),
              const PopupMenuItem(value: 'Employee', child: Text('Employees')),
              const PopupMenuItem(value: 'Purchase', child: Text('Purchases')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No audit logs found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final actionColor = log.action == 'create'
                        ? Colors.green
                        : log.action == 'update'
                            ? Colors.blue
                            : Colors.red;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: actionColor.withOpacity(0.2),
                          child: Icon(
                            log.action == 'create'
                                ? Icons.add
                                : log.action == 'update'
                                    ? Icons.edit
                                    : Icons.delete,
                            color: actionColor,
                            size: 20,
                          ),
                        ),
                        title: Text('${log.action} ${log.entityType ?? "N/A"}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (log.entityId != null)
                              Text('ID: ${log.entityId!.substring(0, 8)}...',
                                  style: const TextStyle(fontSize: 12)),
                            Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(log.createdAt),
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        trailing: log.oldValue != null
                            ? const Icon(Icons.info_outline, size: 16)
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
