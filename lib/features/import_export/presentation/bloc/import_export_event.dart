part of 'import_export_bloc.dart';

abstract class ImportExportEvent extends Equatable {
  const ImportExportEvent();

  @override
  List<Object> get props => [];
}

class StartImportJob extends ImportExportEvent {
  final String entityType;
  final String fileName;
  final String fileType;
  final List<Map<String, dynamic>> rows;
  final List<FieldMapping> mappings;
  final bool skipDuplicates;

  const StartImportJob({
    required this.entityType,
    required this.fileName,
    required this.fileType,
    required this.rows,
    required this.mappings,
    this.skipDuplicates = true,
  });

  @override
  List<Object> get props => [
        entityType, fileName, fileType, rows,
        mappings, skipDuplicates,
      ];
}

class ValidateImportData extends ImportExportEvent {
  final String entityType;
  final List<Map<String, dynamic>> rows;
  final List<FieldMapping> mappings;

  const ValidateImportData({
    required this.entityType,
    required this.rows,
    required this.mappings,
  });

  @override
  List<Object> get props => [entityType, rows, mappings];
}

class ExportData extends ImportExportEvent {
  final String entityType;
  final String format;
  final List<String> fields;
  final String? filterCriteria;

  const ExportData({
    required this.entityType,
    required this.format,
    required this.fields,
    this.filterCriteria,
  });

  @override
  List<Object> get props => [entityType, format, fields, filterCriteria ?? ''];
}

class LoadImportLogs extends ImportExportEvent {
  final String? entityType;
  final int page;

  const LoadImportLogs({this.entityType, this.page = 1});

  @override
  List<Object> get props => [entityType ?? '', page];
}

class RollbackImportJob extends ImportExportEvent {
  final String jobId;

  const RollbackImportJob({required this.jobId});

  @override
  List<Object> get props => [jobId];
}

class PreviewImportFile extends ImportExportEvent {
  final String fileName;
  final String fileType;

  const PreviewImportFile({
    required this.fileName,
    required this.fileType,
  });

  @override
  List<Object> get props => [fileName, fileType];
}
