import 'package:flutter/material.dart';

/// Page for mapping imported file columns to entity fields.
///
/// Displays a two-column mapping UI where users can match source file
/// column headers to destination entity fields. Supports auto-mapping
/// for common column name patterns.
class ImportMappingPage extends StatefulWidget {
  final String entityType;
  final List<String> sourceColumns;
  final List<String> destinationFields;

  const ImportMappingPage({
    super.key,
    required this.entityType,
    required this.sourceColumns,
    required this.destinationFields,
  });

  @override
  State<ImportMappingPage> createState() => _ImportMappingPageState();
}

class _ImportMappingPageState extends State<ImportMappingPage> {
  Map<String, String?> _mapping = {};

  @override
  void initState() {
    super.initState();
    _autoMap();
  }

  void _autoMap() {
    for (final dest in widget.destinationFields) {
      final destLower = dest.toLowerCase();
      final match = widget.sourceColumns.firstWhere(
        (src) => src.toLowerCase() == destLower ||
            src.toLowerCase().replaceAll(' ', '') == destLower.replaceAll(' ', '') ||
            src.toLowerCase().contains(destLower) ||
            destLower.contains(src.toLowerCase()),
        orElse: () => '',
      );
      _mapping[dest] = match.isEmpty ? null : match;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map Columns - $widget.entityType'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              final validMapping = Map<String, String>.fromEntries(
                _mapping.entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value!)),
              );
              Navigator.pop(context, validMapping);
            },
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Map source columns to ${widget.entityType} fields. Unmapped columns will be ignored.',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.destinationFields.length,
              itemBuilder: (context, index) {
                final dest = widget.destinationFields[index];
                final mappedTo = _mapping[dest];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(dest, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      mappedTo != null ? '← $mappedTo' : 'Not mapped (will be skipped)',
                      style: TextStyle(
                        color: mappedTo != null ? Colors.green : Colors.grey,
                      ),
                    ),
                    trailing: DropdownButton<String>(
                      value: mappedTo,
                      hint: const Text('Select column'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('-- Skip --')),
                        ...widget.sourceColumns.map((src) =>
                          DropdownMenuItem(value: src, child: Text(src)),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _mapping[dest] = value;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
