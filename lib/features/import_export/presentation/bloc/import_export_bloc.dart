import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/import_export_entity.dart';
import '../../domain/usecases/import_export_usecases.dart';
import '../../../../core/usecases/base_usecase.dart';

part 'import_export_event.dart';
part 'import_export_state.dart';

class ImportExportBloc extends Bloc<ImportExportEvent, ImportExportState> {
  final StartImportUseCase startImportUseCase;
  final ValidateImportDataUseCase validateImportDataUseCase;
  final ExportDataUseCase exportDataUseCase;
  final GetImportLogsUseCase getImportLogsUseCase;
  final RollbackImportUseCase rollbackImportUseCase;
  final PreviewImportFileUseCase previewImportFileUseCase;

  ImportExportBloc({
    required this.startImportUseCase,
    required this.validateImportDataUseCase,
    required this.exportDataUseCase,
    required this.getImportLogsUseCase,
    required this.rollbackImportUseCase,
    required this.previewImportFileUseCase,
  }) : super(ImportExportInitial()) {
    on<StartImportJob>(_onStartImport);
    on<ValidateImportData>(_onValidateData);
    on<ExportData>(_onExportData);
    on<LoadImportLogs>(_onLoadLogs);
    on<RollbackImportJob>(_onRollback);
    on<PreviewImportFile>(_onPreviewFile);
  }

  Future<void> _onStartImport(
    StartImportJob event,
    Emitter<ImportExportState> emit,
  ) async {
    emit(ImportLoading());
    final result = await startImportUseCase(
      StartImportParams(
        entityType: event.entityType,
        fileName: event.fileName,
        fileType: event.fileType,
        rows: event.rows,
        mappings: event.mappings,
        skipDuplicates: event.skipDuplicates,
      ),
    );
    result.fold(
      (failure) => emit(ImportExportError(message: failure.message)),
      (job) => emit(ImportJobStarted(job: job)),
    );
  }

  Future<void> _onValidateData(
    ValidateImportData event,
    Emitter<ImportExportState> emit,
  ) async {
    emit(ImportValidating());
    final result = await validateImportDataUseCase(
      ValidateImportParams(
        entityType: event.entityType,
        rows: event.rows,
        mappings: event.mappings,
      ),
    );
    result.fold(
      (failure) => emit(ImportExportError(message: failure.message)),
      (errors) => emit(ImportDataValidated(errors: errors, rowCount: event.rows.length)),
    );
  }

  Future<void> _onExportData(
    ExportData event,
    Emitter<ImportExportState> emit,
  ) async {
    emit(ExportLoading());
    final result = await exportDataUseCase(
      ExportDataParams(
        entityType: event.entityType,
        format: event.format,
        fields: event.fields,
        filterCriteria: event.filterCriteria,
      ),
    );
    result.fold(
      (failure) => emit(ImportExportError(message: failure.message)),
      (filePath) => emit(ExportCompleted(filePath: filePath)),
    );
  }

  Future<void> _onLoadLogs(
    LoadImportLogs event,
    Emitter<ImportExportState> emit,
  ) async {
    emit(ImportLogsLoading());
    final result = await getImportLogsUseCase(
      GetImportLogsParams(
        entityType: event.entityType,
        page: event.page,
      ),
    );
    result.fold(
      (failure) => emit(ImportExportError(message: failure.message)),
      (logs) => emit(ImportLogsLoaded(logs: logs)),
    );
  }

  Future<void> _onRollback(
    RollbackImportJob event,
    Emitter<ImportExportState> emit,
  ) async {
    emit(ImportRollingBack());
    final result = await rollbackImportUseCase(event.jobId);
    result.fold(
      (failure) => emit(ImportExportError(message: failure.message)),
      (_) => emit(ImportRollbackCompleted(jobId: event.jobId)),
    );
  }

  /// Handles file preview by parsing the CSV file and returning headers and rows.
  ///
  /// Reads the file at [event.fileName], parses the CSV content, extracts
  /// headers from the first line, and returns up to 10 data rows for UI preview.
  Future<void> _onPreviewFile(
    PreviewImportFile event,
    Emitter<ImportExportState> emit,
  ) async {
    emit(ImportPreviewLoading());
    final result = await previewImportFileUseCase(
      PreviewImportParams(
        fileName: event.fileName,
        fileType: event.fileType,
      ),
    );
    result.fold(
      (failure) => emit(ImportExportError(message: failure.message)),
      (rows) {
        if (rows.isEmpty) {
          emit(const ImportPreviewLoaded(headers: [], rows: []));
          return;
        }
        final headers = rows.first.keys.toList();
        emit(ImportPreviewLoaded(headers: headers, rows: rows));
      },
    );
  }
}
