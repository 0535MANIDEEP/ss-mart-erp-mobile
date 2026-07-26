import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import '../../../../database/app_database.dart';

/// Page for managing customer tags.
class CustomerTagsPage extends StatefulWidget {
  const CustomerTagsPage({super.key});

  @override
  State<CustomerTagsPage> createState() => _CustomerTagsPageState();
}

class _CustomerTagsPageState extends State<CustomerTagsPage> {
  List<CustomerTag> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final db = GetIt.instance<AppDatabase>();
    final tags = await db.select(db.customerTags).get();
    setState(() { _tags = tags; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Tags'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: _showTagDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tags.isEmpty
              ? const Center(child: Text('No tags defined'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tags.length,
                  itemBuilder: (context, index) {
                    final tag = _tags[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(int.parse('0xFF${tag.colorCode.replaceAll('#', '')}')),
                          child: Text(tag.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(tag.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final db = GetIt.instance<AppDatabase>();
                            await (db.delete(db.customerTags)..where((t) => t.id.equals(tag.id))).go();
                            _loadTags();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showTagDialog() {
    final nameController = TextEditingController();
    String selectedColor = '#FF9800';
    final colors = ['#FF9800', '#4CAF50', '#2196F3', '#F44336', '#9C27B0', '#FF5722', '#795548', '#607D8B'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tag Name *')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(int.parse('0xFF${color.replaceAll('#', '')}')),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final db = GetIt.instance<AppDatabase>();
                await db.into(db.customerTags).insert(CustomerTagsCompanion.insert(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  colorCode: Value(selectedColor),
                  createdAt: DateTime.now(),
                ));
                Navigator.pop(context);
                _loadTags();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
