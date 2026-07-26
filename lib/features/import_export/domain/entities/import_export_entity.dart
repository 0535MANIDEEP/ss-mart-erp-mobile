import 'package:equatable/equatable.dart';

class ImportJob extends Equatable {
  final String id;
  final String entityType;
  final String fileName;
  final String fileType;
  final int totalRows;
  final int processedRows;
  final int successRows;
  final int errorRows;
  final int skippedRows;
  final String status;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<ImportError> errors;

  const ImportJob({
    required this.id,
    required this.entityType,
    required this.fileName,
    required this.fileType,
    this.totalRows = 0,
    this.processedRows = 0,
    this.successRows = 0,
    this.errorRows = 0,
    this.skippedRows = 0,
    this.status = 'pending',
    this.error,
    required this.createdAt,
    this.completedAt,
    this.errors = const [],
  });

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isRolledBack => status == 'rolled_back';
  double get progress => totalRows > 0 ? processedRows / totalRows : 0.0;
  bool get hasErrors => errorRows > 0;

  @override
  List<Object?> get props => [
        id, entityType, fileName, fileType, totalRows,
        processedRows, successRows, errorRows, skippedRows,
        status, error, createdAt, completedAt, errors,
      ];

  ImportJob copyWith({
    String? id,
    String? entityType,
    String? fileName,
    String? fileType,
    int? totalRows,
    int? processedRows,
    int? successRows,
    int? errorRows,
    int? skippedRows,
    String? status,
    String? error,
    DateTime? createdAt,
    DateTime? completedAt,
    List<ImportError>? errors,
  }) {
    return ImportJob(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      totalRows: totalRows ?? this.totalRows,
      processedRows: processedRows ?? this.processedRows,
      successRows: successRows ?? this.successRows,
      errorRows: errorRows ?? this.errorRows,
      skippedRows: skippedRows ?? this.skippedRows,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errors: errors ?? this.errors,
    );
  }
}

class ImportError extends Equatable {
  final int rowNumber;
  final String field;
  final String message;
  final String? value;

  const ImportError({
    required this.rowNumber,
    required this.field,
    required this.message,
    this.value,
  });

  @override
  List<Object?> get props => [rowNumber, field, message, value];
}

class FieldMapping extends Equatable {
  final String sourceField;
  final String targetField;
  final String dataType;
  final bool isRequired;
  final String? defaultValue;
  final String? transform;

  const FieldMapping({
    required this.sourceField,
    required this.targetField,
    required this.dataType,
    this.isRequired = false,
    this.defaultValue,
    this.transform,
  });

  @override
  List<Object?> get props => [
        sourceField, targetField, dataType,
        isRequired, defaultValue, transform,
      ];

  FieldMapping copyWith({
    String? sourceField,
    String? targetField,
    String? dataType,
    bool? isRequired,
    String? defaultValue,
    String? transform,
  }) {
    return FieldMapping(
      sourceField: sourceField ?? this.sourceField,
      targetField: targetField ?? this.targetField,
      dataType: dataType ?? this.dataType,
      isRequired: isRequired ?? this.isRequired,
      defaultValue: defaultValue ?? this.defaultValue,
      transform: transform ?? this.transform,
    );
  }
}

class ExportTemplate extends Equatable {
  final String id;
  final String name;
  final String entityType;
  final List<String> fields;
  final String format;
  final bool includeHeaders;
  final String? filterCriteria;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExportTemplate({
    required this.id,
    required this.name,
    required this.entityType,
    required this.fields,
    this.format = 'csv',
    this.includeHeaders = true,
    this.filterCriteria,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id, name, entityType, fields, format,
        includeHeaders, filterCriteria, createdAt, updatedAt,
      ];
}

class ImportLog extends Equatable {
  final String id;
  final String jobId;
  final String entityType;
  final String action;
  final int rowCount;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool canRollback;

  const ImportLog({
    required this.id,
    required this.jobId,
    required this.entityType,
    required this.action,
    this.rowCount = 0,
    this.error,
    required this.createdAt,
    this.completedAt,
    this.canRollback = true,
  });

  @override
  List<Object?> get props => [
        id, jobId, entityType, action, rowCount,
        error, createdAt, completedAt, canRollback,
      ];
}
