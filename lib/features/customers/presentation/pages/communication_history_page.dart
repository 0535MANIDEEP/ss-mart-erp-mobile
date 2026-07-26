import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../database/app_database.dart';

/// Page for viewing and adding customer communication history.
class CommunicationHistoryPage extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CommunicationHistoryPage({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CommunicationHistoryPage> createState() => _CommunicationHistoryPageState();
}

class _CommunicationHistoryPageState extends State<CommunicationHistoryPage> {
  List<CommunicationHistoryData> _communications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCommunications();
  }

  Future<void> _loadCommunications() async {
    final db = GetIt.instance<AppDatabase>();
    final comms = await (db.select(db.communicationHistory)
      ..where((t) => t.customerId.equals(widget.customerId))
      ..orderBy([(t) => OrderingTerm.desc(t.communicationDate)])).get();
    setState(() { _communications = comms; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.customerName} - Communications'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCommunicationDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _communications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.message, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No communication history'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _communications.length,
                  itemBuilder: (context, index) {
                    final comm = _communications[index];
                    final icon = comm.communicationType == 'call'
                        ? Icons.phone
                        : comm.communicationType == 'whatsapp'
                            ? Icons.chat
                            : comm.communicationType == 'email'
                                ? Icons.email
                                : Icons.message;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Icon(icon)),
                        title: Text(comm.communicationType.toUpperCase()),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (comm.notes != null) Text(comm.notes!),
                            if (comm.outcome != null)
                              Text('Outcome: ${comm.outcome}', style: const TextStyle(fontSize: 12)),
                            Text(DateFormat('dd/MM/yyyy HH:mm').format(comm.communicationDate),
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }

  void _showAddCommunicationDialog() {
    String type = 'call';
    final notesController = TextEditingController();
    final outcomeController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log Communication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'call', child: Text('Call')),
                DropdownMenuItem(value: 'sms', child: Text('SMS')),
                DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                DropdownMenuItem(value: 'email', child: Text('Email')),
                DropdownMenuItem(value: 'visit', child: Text('Visit')),
              ],
              onChanged: (v) { if (v != null) type = v; },
            ),
            const SizedBox(height: 12),
            TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
            const SizedBox(height: 12),
            TextField(controller: outcomeController, decoration: const InputDecoration(labelText: 'Outcome')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final db = GetIt.instance<AppDatabase>();
              await db.into(db.communicationHistory).insert(CommunicationHistoryCompanion.insert(
                id: const Uuid().v4(),
                customerId: widget.customerId,
                communicationType: type,
                notes: Value(notesController.text.isEmpty ? null : notesController.text),
                outcome: Value(outcomeController.text.isEmpty ? null : outcomeController.text),
                performedBy: 'current_user',
                communicationDate: DateTime.now(),
                createdAt: DateTime.now(),
              ));
              Navigator.pop(context);
              _loadCommunications();
            },
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }
}
