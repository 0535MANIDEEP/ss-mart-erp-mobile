import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import '../../../../database/app_database.dart';

/// Page for managing customer groups (segmentation).
class CustomerGroupsPage extends StatefulWidget {
  const CustomerGroupsPage({super.key});

  @override
  State<CustomerGroupsPage> createState() => _CustomerGroupsPageState();
}

class _CustomerGroupsPageState extends State<CustomerGroupsPage> {
  List<CustomerGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final db = GetIt.instance<AppDatabase>();
    final groups = await (db.select(db.customerGroups)..where((t) => t.isActive.equals(true))).get();
    setState(() { _groups = groups; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Groups'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: _showGroupDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? const Center(child: Text('No customer groups defined'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.group),
                        ),
                        title: Text(group.name),
                        subtitle: Text(
                          '${group.description ?? "No description"}\n'
                          'Discount: ${group.discountType} ${group.discountValue}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton(
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') _showGroupDialog(group: group);
                            if (value == 'delete') _deleteGroup(group);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showGroupDialog({CustomerGroup? group}) {
    final nameController = TextEditingController(text: group?.name ?? '');
    final descController = TextEditingController(text: group?.description ?? '');
    String discountType = group?.discountType ?? 'percentage';
    final discountValueController = TextEditingController(text: (group?.discountValue ?? 0).toString());
    final isEdit = group != null;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Group' : 'New Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Group Name *')),
            const SizedBox(height: 12),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: discountType,
              decoration: const InputDecoration(labelText: 'Discount Type'),
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
                DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
              ],
              onChanged: (v) { if (v != null) discountType = v; },
            ),
            const SizedBox(height: 12),
            TextField(controller: discountValueController, decoration: const InputDecoration(labelText: 'Discount Value'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final db = GetIt.instance<AppDatabase>();
              final data = {
                'name': nameController.text.trim(),
                'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                'discountType': discountType,
                'discountValue': double.tryParse(discountValueController.text) ?? 0,
              };
              if (isEdit) {
                await (db.update(db.customerGroups)..where((t) => t.id.equals(group.id))).write(
                  CustomerGroupsCompanion(
                    name: Value(data['name'] as String),
                    description: Value(data['description'] as String?),
                    discountType: Value(data['discountType'] as String),
                    discountValue: Value(data['discountValue'] as double),
                    updatedAt: Value(DateTime.now()),
                    version: Value(group.version + 1),
                    syncStatus: const Value('pending'),
                  ),
                );
              } else {
                await db.into(db.customerGroups).insert(CustomerGroupsCompanion.insert(
                  id: const Uuid().v4(),
                  name: data['name'] as String,
                  description: Value(data['description'] as String?),
                  discountType: Value(data['discountType'] as String),
                  discountValue: Value(data['discountValue'] as double),
                  isActive: const Value(true),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  version: const Value(1),
                  syncStatus: const Value('pending'),
                ));
              }
              Navigator.pop(context);
              _loadGroups();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup(CustomerGroup group) async {
    final db = GetIt.instance<AppDatabase>();
    await (db.update(db.customerGroups)..where((t) => t.id.equals(group.id))).write(
      const CustomerGroupsCompanion(isActive: Value(false), syncStatus: Value('pending')),
    );
    _loadGroups();
  }
}
