part of 'import_export_bloc.dart';

abstract class ImportExportState extends Equatable {
  const ImportExportState();

  @override
  List<Object> get props => [];
}

class ImportExportInitial extends ImportExportState {
  const ImportExportInitial();
}

class ImportLoading extends ImportExportState {
  const ImportLoading();
}

class ImportJobStarted extends ImportExportState {
  final ImportJob job;

  const ImportJobStarted({required this.job});

  @override
  List<Object> get props => [job];
}

class ImportValidating extends ImportExportState {
  const ImportValidating();
}

class ImportDataValidated extends ImportExportState {
  final List<ImportError> errors;
  final int rowCount;

  const ImportDataValidated({required this.errors, required this.rowCount});

  bool get hasErrors => errors.isNotEmpty;

  @override
  List<Object> get props => [errors, rowCount];
}

class ExportLoading extends ImportExportState {
  const ExportLoading();
}

class ExportCompleted extends ImportExportState {
  final String filePath;

  const ExportCompleted({required this.filePath});

  @override
  List<Object> get props => [filePath];
}

class ImportLogsLoading extends ImportExportState {
  const ImportLogsLoading();
}

class ImportLogsLoaded extends ImportExportState {
  final List<ImportLog> logs;

  const ImportLogsLoaded({required this.logs});

  @override
  List<Object> get props => [logs];
}

class ImportRollingBack extends ImportExportState {
  const ImportRollingBack();
}

class ImportRollbackCompleted extends ImportExportState {
  final String jobId;

  const ImportRollbackCompleted({required this.jobId});

  @override
  List<Object> get props => [jobId];
}

class ImportPreviewLoading extends ImportExportState {
  const ImportPreviewLoading();
}

class ImportPreviewLoaded extends ImportExportState {
  final List<String> headers;
  final List<Map<String, dynamic>> rows;

  const ImportPreviewLoaded({required this.headers, required this.rows});

  @override
  List<Object> get props => [headers, rows];
}

class ImportExportError extends ImportExportState {
  final String message;

  const ImportExportError({required this.message});

  @override
  List<Object> get props => [message];
}
