import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import '../../../../database/app_database.dart';

/// Page for configuring bill/invoice numbering format and sequences.
class NumberingSettingsPage extends StatefulWidget {
  const NumberingSettingsPage({super.key});

  @override
  State<NumberingSettingsPage> createState() => _NumberingSettingsPageState();
}

class _NumberingSettingsPageState extends State<NumberingSettingsPage> {
  List<NumberingConfigData> _configs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final db = GetIt.instance<AppDatabase>();
    final configs = await db.select(db.numberingConfig).get();
    if (configs.isEmpty) {
      await _createDefaults();
      final updated = await db.select(db.numberingConfig).get();
      setState(() { _configs = updated; _isLoading = false; });
    } else {
      setState(() { _configs = configs; _isLoading = false; });
    }
  }

  Future<void> _createDefaults() async {
    final db = GetIt.instance<AppDatabase>();
    final defaults = [
      {'type': 'BILL', 'prefix': 'BILL', 'format': 'PREFIX-YYYYMMDD-NNNN'},
      {'type': 'PURCHASE', 'prefix': 'PUR', 'format': 'PREFIX-YYYYMMDD-NNNN'},
      {'type': 'RETURN', 'prefix': 'RET', 'format': 'PREFIX-YYYYMMDD-NNNN'},
      {'type': 'PHYSICAL_COUNT', 'prefix': 'PC', 'format': 'PREFIX-YYYYMMDD-NNNN'},
    ];
    for (final config in defaults) {
      await db.into(db.numberingConfig).insert(NumberingConfigCompanion.insert(
        id: const Uuid().v4(),
        documentType: config['type']!,
        prefix: Value(config['prefix']!),
        nextSequence: const Value(1),
        format: Value(config['format']!),
        isActive: const Value(true),
        updatedAt: DateTime.now(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Numbering Settings'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _configs.length,
              itemBuilder: (context, index) {
                final config = _configs[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.numbers),
                    title: Text(config.documentType),
                    subtitle: Text('Prefix: ${config.prefix} | Format: ${config.format}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Next: ${config.nextSequence}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editConfig(config),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _editConfig(NumberingConfigData config) {
    final prefixController = TextEditingController(text: config.prefix);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit ${config.documentType}'),
        content: TextField(
          controller: prefixController,
          decoration: const InputDecoration(labelText: 'Prefix'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final db = GetIt.instance<AppDatabase>();
              await (db.update(db.numberingConfig)
                ..where((t) => t.id.equals(config.id)))
                  .write(NumberingConfigCompanion(
                    prefix: Value(prefixController.text),
                    updatedAt: Value(DateTime.now()),
                  ));
              Navigator.pop(context);
              _loadConfigs();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
