import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/import_export_bloc.dart';
import '../../domain/entities/import_export_entity.dart';
import '../../../../injection/injection_container.dart';

class ImportExportPage extends StatelessWidget {
  const ImportExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Import / Export'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.upload), text: 'Import'),
              Tab(icon: Icon(Icons.download), text: 'Export'),
              Tab(icon: Icon(Icons.history), text: 'Logs'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ImportTab(),
            ExportTab(),
            ImportLogsTab(),
          ],
        ),
      ),
    );
  }
}

class ImportTab extends StatefulWidget {
  const ImportTab({super.key});

  @override
  State<ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends State<ImportTab> {
  String _selectedEntityType = 'products';
  String _selectedFileType = 'csv';
  bool _skipDuplicates = true;
  List<Map<String, dynamic>> _previewRows = [];
  List<String> _headers = [];
  List<FieldMapping> _mappings = [];
  bool _showMapping = false;
  String? _selectedFilePath;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ImportExportBloc>(),
      child: BlocConsumer<ImportExportBloc, ImportExportState>(
        listener: (context, state) {
          if (state is ImportJobStarted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Import completed: ${state.job.successRows} success, ${state.job.errorRows} errors'),
                backgroundColor: state.job.hasErrors ? Colors.orange : Colors.green,
              ),
            );
          } else if (state is ImportExportError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Import Type', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'products', label: Text('Products')),
                    ButtonSegment(value: 'customers', label: Text('Customers')),
                    ButtonSegment(value: 'stock', label: Text('Stock')),
                  ],
                  selected: {_selectedEntityType},
                  onSelectionChanged: (selected) {
                    setState(() => _selectedEntityType = selected.first);
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select File', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  _showFilePathDialog(context);
                                },
                                icon: const Icon(Icons.file_upload),
                                label: const Text('Choose CSV/Excel File'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'csv', label: Text('CSV')),
                                ButtonSegment(value: 'xlsx', label: Text('Excel')),
                              ],
                              selected: {_selectedFileType},
                              onSelectionChanged: (selected) {
                                setState(() => _selectedFileType = selected.first);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('Skip Duplicates'),
                          subtitle: const Text('Skip rows that match existing records'),
                          value: _skipDuplicates,
                          onChanged: (value) {
                            setState(() => _skipDuplicates = value);
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_previewRows.isNotEmpty) ...[
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Text('Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text('${_previewRows.length} rows'),
                              TextButton(
                                onPressed: () {
                                  setState(() => _showMapping = !_showMapping);
                                },
                                child: Text(_showMapping ? 'Hide Mapping' : 'Configure Mapping'),
                              ),
                            ],
                          ),
                        ),
                        if (_showMapping) _buildFieldMapping(),
                        _buildPreviewTable(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _loadAndPreviewFile(context);
                        },
                        child: const Text('Load & Preview'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _previewRows.isNotEmpty
                            ? () {
                                context.read<ImportExportBloc>().add(StartImportJob(
                                      entityType: _selectedEntityType,
                                      fileName: 'import_file.$_selectedFileType',
                                      fileType: _selectedFileType,
                                      rows: _previewRows,
                                      mappings: _mappings.isNotEmpty
                                          ? _mappings
                                          : _getDefaultMappings(),
                                      skipDuplicates: _skipDuplicates,
                                    ));
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start Import'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFieldMapping() {
    final mappings = _mappings.isNotEmpty ? _mappings : _getDefaultMappings();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Field Mapping', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...mappings.map((mapping) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(mapping.sourceField, style: const TextStyle(fontSize: 13)),
                    ),
                    const Icon(Icons.arrow_forward, size: 16),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: mapping.targetField,
                        isDense: true,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: _getAvailableFields().map((f) => DropdownMenuItem(
                              value: f,
                              child: Text(f, style: const TextStyle(fontSize: 13)),
                            )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            final idx = mappings.indexOf(mapping);
                            setState(() {
                              _mappings = List.from(mappings);
                              _mappings[idx] = _mappings[idx].copyWith(targetField: value);
                            });
                          }
                        },
                      ),
                    ),
                    if (mapping.isRequired)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              )),
          const Divider(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPreviewTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: _headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontSize: 12)))).toList(),
        rows: _previewRows.take(5).map((row) {
          return DataRow(
            cells: _headers.map((h) => DataCell(
                  Text(row[h]?.toString() ?? '-', style: const TextStyle(fontSize: 12)),
                )).toList(),
          );
        }).toList(),
      ),
    );
  }

  List<String> _getAvailableFields() {
    switch (_selectedEntityType) {
      case 'products':
        return ['name', 'sku', 'barcode', 'hsnCode', 'unit', 'mrp', 'sellingPrice', 'purchasePrice', 'taxRate', 'reorderLevel'];
      case 'customers':
        return ['name', 'phone', 'email', 'address', 'city', 'state', 'pincode', 'gstin', 'type', 'creditLimit'];
      case 'stock':
        return ['productId', 'quantity', 'batchNumber', 'expiryDate'];
      default:
        return [];
    }
  }

  List<FieldMapping> _getDefaultMappings() {
    switch (_selectedEntityType) {
      case 'products':
        return const [
          FieldMapping(sourceField: 'name', targetField: 'name', dataType: 'string', isRequired: true),
          FieldMapping(sourceField: 'sku', targetField: 'sku', dataType: 'string'),
          FieldMapping(sourceField: 'mrp', targetField: 'mrp', dataType: 'int', isRequired: true),
          FieldMapping(sourceField: 'selling_price', targetField: 'sellingPrice', dataType: 'int', isRequired: true),
          FieldMapping(sourceField: 'hsn_code', targetField: 'hsnCode', dataType: 'string', isRequired: true),
        ];
      case 'customers':
        return const [
          FieldMapping(sourceField: 'name', targetField: 'name', dataType: 'string', isRequired: true),
          FieldMapping(sourceField: 'phone', targetField: 'phone', dataType: 'string'),
          FieldMapping(sourceField: 'email', targetField: 'email', dataType: 'string'),
        ];
      default:
        return const [];
    }
  }

  void _showFilePathDialog(BuildContext context) {
    final pathController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter File Path'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                labelText: 'File path',
                hintText: 'e.g., /storage/emulated/0/import.csv',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use a file browser to find your CSV/Excel file and paste the path here.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final path = pathController.text.trim();
              if (path.isNotEmpty) {
                setState(() => _selectedFilePath = path);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected: $path')),
                );
              }
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAndPreviewFile(BuildContext context) async {
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final file = File(_selectedFilePath!);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final content = await file.readAsString();
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

      if (lines.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File is empty'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final delimiter = _selectedFileType == 'csv' ? ',' : '\t';
      final headers = lines.first.split(delimiter).map((h) => h.trim()).toList();
      final rows = <Map<String, dynamic>>[];

      for (var i = 1; i < lines.length && i < 20; i++) {
        final values = lines[i].split(delimiter).map((v) => v.trim()).toList();
        final row = <String, dynamic>{};
        for (var j = 0; j < headers.length && j < values.length; j++) {
          row[headers[j]] = values[j];
        }
        rows.add(row);
      }

      setState(() {
        _headers = headers;
        _previewRows = rows;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class ExportTab extends StatefulWidget {
  const ExportTab({super.key});

  @override
  State<ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<ExportTab> {
  String _selectedEntityType = 'products';
  String _selectedFormat = 'csv';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ImportExportBloc>(),
      child: BlocConsumer<ImportExportBloc, ImportExportState>(
        listener: (context, state) {
          if (state is ExportCompleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Export saved to: ${state.filePath}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Export Data', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Data Type'),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'products', label: Text('Products')),
                            ButtonSegment(value: 'customers', label: Text('Customers')),
                            ButtonSegment(value: 'bills', label: Text('Sales')),
                            ButtonSegment(value: 'stock', label: Text('Stock')),
                          ],
                          selected: {_selectedEntityType},
                          onSelectionChanged: (selected) {
                            setState(() => _selectedEntityType = selected.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Export Format'),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'csv', label: Text('CSV')),
                            ButtonSegment(value: 'xlsx', label: Text('Excel')),
                            ButtonSegment(value: 'pdf', label: Text('PDF')),
                          ],
                          selected: {_selectedFormat},
                          onSelectionChanged: (selected) {
                            setState(() => _selectedFormat = selected.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: state is ExportLoading ? null : () {
                      context.read<ImportExportBloc>().add(ExportData(
                            entityType: _selectedEntityType,
                            format: _selectedFormat,
                            fields: _getAllFields(),
                          ));
                    },
                    icon: state is ExportLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download),
                    label: Text(state is ExportLoading ? 'Exporting...' : 'Export Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<String> _getAllFields() {
    switch (_selectedEntityType) {
      case 'products':
        return ['name', 'sku', 'barcode', 'hsnCode', 'unit', 'mrp', 'sellingPrice', 'purchasePrice', 'taxRate', 'currentStock'];
      case 'customers':
        return ['name', 'phone', 'email', 'address', 'city', 'state', 'gstin', 'type', 'loyaltyPoints', 'currentBalance'];
      case 'bills':
        return ['billNumber', 'customerName', 'subtotal', 'taxAmount', 'totalAmount', 'paymentMode', 'billDate'];
      case 'stock':
        return ['productName', 'quantity', 'batchNumber', 'expiryDate', 'locationId'];
      default:
        return [];
    }
  }
}

class ImportLogsTab extends StatelessWidget {
  const ImportLogsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ImportExportBloc>()..add(const LoadImportLogs()),
      child: BlocBuilder<ImportExportBloc, ImportExportState>(
        builder: (context, state) {
          if (state is ImportLogsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ImportLogsLoaded) {
            if (state.logs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No import logs'),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: state.logs.length,
              itemBuilder: (context, index) {
                final log = state.logs[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      log.canRollback ? Icons.check_circle : Icons.info,
                      color: log.error != null ? Colors.red : Colors.green,
                    ),
                    title: Text('${log.entityType} - ${log.action}'),
                    subtitle: Text(
                      '${log.rowCount} rows processed\n${log.createdAt}',
                    ),
                    trailing: log.canRollback
                        ? TextButton(
                            onPressed: () {
                              context.read<ImportExportBloc>().add(
                                    RollbackImportJob(jobId: log.jobId),
                                  );
                            },
                            child: const Text('Rollback'),
                          )
                        : null,
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
