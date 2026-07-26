import 'dart:convert';
import 'dart:io';

/// Data source for importing DBF (dBASE) format files.
///
/// Parses DBF file format and converts rows to a list of maps
/// for use in the import pipeline. DBF is a legacy format still
/// used by some Indian retail inventory systems.
class DbfImportDataSource {
  /// Reads a DBF file and returns a list of row maps.
  ///
  /// DBF files contain a header section with field definitions
  /// followed by data records. This implementation supports
  /// DBF versions III and IV (most common in Indian retail).
  Future<List<Map<String, dynamic>>> readFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('DBF file not found: $filePath');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length < 32) {
      throw Exception('Invalid DBF file: too short');
    }

    // Parse DBF header (simplified for common retail DBF files)
    final numFields = (bytes[32] - 33) ~/ 32;
    final fields = <_DbfField>[];

    for (int i = 0; i < numFields && (33 + i * 32 + 32) <= bytes.length; i++) {
      final offset = 33 + i * 32;
      final nameBytes = bytes.sublist(offset, offset + 11);
      final name = String.fromCharCodes(nameBytes.where((b) => b != 0));
      final type = String.fromCharCode(bytes[offset + 11]);
      final length = bytes[offset + 16];
      fields.add(_DbfField(name: name, type: type, length: length));
    }

    // Find data start (after header terminator 0x0D)
    int dataStart = 33 + numFields * 32 + 1;
    while (dataStart < bytes.length && bytes[dataStart] != 0x0D) {
      dataStart++;
    }
    dataStart++; // Skip the 0x0D terminator

    // Parse data records
    final records = <Map<String, dynamic>>[];
    int pos = dataStart;
    final recordLength = fields.fold<int>(0, (sum, f) => sum + f.length) + 1; // +1 for delete flag

    while (pos + recordLength <= bytes.length) {
      final deleteFlag = bytes[pos];
      if (deleteFlag == 0x20) { // 0x20 = active record
        final record = <String, dynamic>{};
        int fieldOffset = pos + 1;
        for (final field in fields) {
          final value = String.fromCharCodes(bytes.sublist(fieldOffset, fieldOffset + field.length)).trim();
          record[field.name] = _parseFieldValue(value, field.type);
          fieldOffset += field.length;
        }
        records.add(record);
      }
      pos += recordLength;
    }

    return records;
  }

  dynamic _parseFieldValue(String value, String type) {
    switch (type) {
      case 'N': // Numeric
        return num.tryParse(value) ?? 0;
      case 'D': // Date (YYYYMMDD format)
        if (value.length == 8) {
          try {
            return DateTime(int.parse(value.substring(0, 4)), int.parse(value.substring(4, 6)), int.parse(value.substring(6, 8)));
          } catch (_) {}
        }
        return value;
      case 'L': // Logical
        return value.toUpperCase() == 'Y' || value.toUpperCase() == 'T';
      default: // Character
        return value;
    }
  }
}

class _DbfField {
  final String name;
  final String type;
  final int length;

  const _DbfField({required this.name, required this.type, required this.length});
}
