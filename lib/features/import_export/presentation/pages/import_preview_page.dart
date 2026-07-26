import 'package:flutter/material.dart';
import '../../domain/entities/import_export_entity.dart';

/// Preview page displayed before committing a data import.
///
/// Shows parsed data in a scrollable table format with validation errors
/// highlighted. Provides a summary of row counts and error counts, and
/// allows the user to proceed with import or cancel.
///
/// ## Features
/// - **Data Table**: Scrollable table showing parsed rows with column headers.
/// - **Validation Errors**: Rows with errors are highlighted in red with tooltips.
/// - **Row Summary**: Total rows, valid rows, and error rows counts.
/// - **Column Mapping**: Displays the active field mappings.
/// - **Import/Cancel**: Action buttons to proceed or abort.
///
/// ## Usage
/// ```dart
/// final result = await Navigator.push<bool>(
///   context,
///   MaterialPageRoute(
///     builder: (_) => ImportPreviewPage(
///       entityType: 'Products',
///       headers: ['Name', 'Price', 'SKU'],
///       rows: [
///         {'Name': 'Widget', 'Price': '100', 'SKU': 'W001'},
///         {'Name': '', 'Price': 'abc', 'SKU': 'W002'},
///       ],
///       mappings: {'Name': 'name', 'Price': 'sellingPrice', 'SKU': 'sku'},
///       errors: [
///         ImportError(rowNumber: 2, field: 'Name', message: 'Required'),
///         ImportError(rowNumber: 2, field: 'Price', message: 'Invalid number'),
///       ],
///     ),
///   ),
/// );
/// ```
class ImportPreviewPage extends StatefulWidget {
  /// The type of entity being imported (e.g., 'Products', 'Customers').
  final String entityType;

  /// Column headers from the source file.
  final List<String> headers;

  /// Parsed data rows, each row is a map of header → value.
  final List<Map<String, String>> rows;

  /// Active field mappings (source header → target field name).
  final Map<String, String> mappings;

  /// Validation errors found during preview.
  final List<ImportError> errors;

  const ImportPreviewPage({
    super.key,
    required this.entityType,
    required this.headers,
    required this.rows,
    required this.mappings,
    this.errors = const [],
  });

  @override
  State<ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends State<ImportPreviewPage> {
  /// Set of row indices that contain validation errors.
  late final Set<int> _errorRows;

  @override
  void initState() {
    super.initState();
    _errorRows = widget.errors.map((e) => e.rowNumber - 1).toSet();
  }

  /// Count of rows without any validation errors.
  int get _validRowCount => widget.rows.length - _errorRows.length;

  /// Whether any validation errors exist.
  bool get _hasErrors => widget.errors.isNotEmpty;

  void _confirmImport() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Import ${widget.entityType}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ready to import ${widget.rows.length} rows.'),
            if (_hasErrors) ...[
              const SizedBox(height: 8),
              Text(
                '${_errorRows.length} rows have validation errors and will be skipped.',
                style: TextStyle(color: Colors.orange[700], fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'This action cannot be easily undone.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
              Navigator.pop(dialogContext);
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Import'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview - $widget.entityType'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _confirmImport,
            icon: const Icon(Icons.file_upload, color: Colors.white),
            label: const Text('Import', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryBar(),
          _buildMappingBar(),
          Expanded(child: _buildDataTable()),
        ],
      ),
      bottomNavigationBar: _buildActionBar(),
    );
  }

  /// Builds the summary bar showing row counts and error indicators.
  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _hasErrors ? Colors.orange[50] : Colors.green[50],
      child: Row(
        children: [
          Icon(
            _hasErrors ? Icons.warning_amber : Icons.check_circle,
            color: _hasErrors ? Colors.orange : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCountBadge('Total', widget.rows.length, Colors.blue),
                _buildCountBadge('Valid', _validRowCount, Colors.green),
                if (_hasErrors)
                  _buildCountBadge('Errors', _errorRows.length, Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single count badge for the summary bar.
  Widget _buildCountBadge(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
      ],
    );
  }

  /// Builds the column mapping display bar.
  Widget _buildMappingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          const Icon(Icons.compare_arrows, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.mappings.length} columns mapped',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => _showMappingDetails(),
            child: const Text('View', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Shows the full mapping details in a bottom sheet.
  void _showMappingDetails() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Column Mappings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                itemCount: widget.mappings.length,
                itemBuilder: (context, index) {
                  final entry = widget.mappings.entries.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.arrow_forward, size: 16),
                    title: Text(entry.key, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '→ ${entry.value}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the scrollable data table showing parsed rows.
  Widget _buildDataTable() {
    if (widget.rows.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No data to preview', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          headingRowColor: WidgetStateProperty.resolveWith(
            (states) => Colors.grey[200],
          ),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.blue[50];
            }
            return null;
          }),
          columns: [
            // Row number column
            const DataColumn(
              label: Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            // Status column
            const DataColumn(
              label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            // Data columns from headers
            ...widget.headers.map(
              (h) => DataColumn(
                label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          rows: List.generate(widget.rows.length, (rowIndex) {
            final row = widget.rows[rowIndex];
            final hasError = _errorRows.contains(rowIndex);
            final rowErrors = widget.errors
                .where((e) => e.rowNumber == rowIndex + 1)
                .toList();

            return DataRow(
              color: WidgetStateProperty.resolveWith((states) {
                if (hasError) return Colors.red[50];
                return null;
              }),
              cells: [
                // Row number
                DataCell(
                  Text(
                    '${rowIndex + 1}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
                // Status indicator
                DataCell(
                  hasError
                      ? Tooltip(
                          message: rowErrors.map((e) => '${e.field}: ${e.message}').join('\n'),
                          child: Icon(
                            Icons.error,
                            color: Colors.red[400],
                            size: 18,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                ),
                // Data cells
                ...widget.headers.map((header) {
                  final value = row[header] ?? '';
                  final hasCellError = rowErrors.any(
                    (e) => e.field.toLowerCase() == header.toLowerCase(),
                  );

                  return DataCell(
                    Text(
                      value.isEmpty ? '—' : value,
                      style: TextStyle(
                        color: hasCellError
                            ? Colors.red[700]
                            : value.isEmpty
                                ? Colors.grey[400]
                                : Colors.black87,
                        fontWeight: hasCellError ? FontWeight.w500 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// Builds the bottom action bar with Import and Cancel buttons.
  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _confirmImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Import ${_validRowCount} Rows',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
