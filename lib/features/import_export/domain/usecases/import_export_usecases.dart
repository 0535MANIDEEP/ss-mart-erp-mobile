import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/import_export_entity.dart';
import '../repositories/import_export_repository.dart';

class StartImportUseCase extends UseCase<ImportJob, StartImportParams> {
  final ImportExportRepository repository;

  StartImportUseCase(this.repository);

  @override
  Future<Either<Failure, ImportJob>> call(StartImportParams params) async {
    return await repository.startImport(
      entityType: params.entityType,
      fileName: params.fileName,
      fileType: params.fileType,
      rows: params.rows,
      mappings: params.mappings,
      skipDuplicates: params.skipDuplicates,
    );
  }
}

class StartImportParams {
  final String entityType;
  final String fileName;
  final String fileType;
  final List<Map<String, dynamic>> rows;
  final List<FieldMapping> mappings;
  final bool skipDuplicates;

  const StartImportParams({
    required this.entityType,
    required this.fileName,
    required this.fileType,
    required this.rows,
    required this.mappings,
    this.skipDuplicates = true,
  });
}

class ValidateImportDataUseCase extends UseCase<List<ImportError>, ValidateImportParams> {
  final ImportExportRepository repository;

  ValidateImportDataUseCase(this.repository);

  @override
  Future<Either<Failure, List<ImportError>>> call(ValidateImportParams params) async {
    return await repository.validateImportData(
      entityType: params.entityType,
      rows: params.rows,
      mappings: params.mappings,
    );
  }
}

class ValidateImportParams {
  final String entityType;
  final List<Map<String, dynamic>> rows;
  final List<FieldMapping> mappings;

  const ValidateImportParams({
    required this.entityType,
    required this.rows,
    required this.mappings,
  });
}

class ExportDataUseCase extends UseCase<String, ExportDataParams> {
  final ImportExportRepository repository;

  ExportDataUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(ExportDataParams params) async {
    return await repository.exportData(
      entityType: params.entityType,
      format: params.format,
      fields: params.fields,
      filterCriteria: params.filterCriteria,
    );
  }
}

class ExportDataParams {
  final String entityType;
  final String format;
  final List<String> fields;
  final String? filterCriteria;

  const ExportDataParams({
    required this.entityType,
    required this.format,
    required this.fields,
    this.filterCriteria,
  });
}

class GetImportLogsUseCase extends UseCase<List<ImportLog>, GetImportLogsParams> {
  final ImportExportRepository repository;

  GetImportLogsUseCase(this.repository);

  @override
  Future<Either<Failure, List<ImportLog>>> call(GetImportLogsParams params) async {
    return await repository.getImportLogs(
      entityType: params.entityType,
      page: params.page,
      perPage: params.perPage,
    );
  }
}

class GetImportLogsParams {
  final String? entityType;
  final int page;
  final int perPage;

  const GetImportLogsParams({
    this.entityType,
    this.page = 1,
    this.perPage = 20,
  });
}

class RollbackImportUseCase extends UseCase<void, String> {
  final ImportExportRepository repository;

  RollbackImportUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String jobId) async {
    return await repository.rollbackImport(jobId);
  }
}

/// Use case for previewing the first N rows of an import file.
///
/// Reads the file, parses it, and returns row maps for UI preview
/// before the actual import is started.
class PreviewImportFileUseCase extends UseCase<List<Map<String, dynamic>>, PreviewImportParams> {
  final ImportExportRepository repository;

  PreviewImportFileUseCase(this.repository);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> call(PreviewImportParams params) async {
    return await repository.previewImportFile(
      fileName: params.fileName,
      fileType: params.fileType,
      maxRows: params.maxRows,
    );
  }
}

/// Parameters for [PreviewImportFileUseCase].
class PreviewImportParams {
  final String fileName;
  final String fileType;
  final int maxRows;

  const PreviewImportParams({
    required this.fileName,
    required this.fileType,
    this.maxRows = 10,
  });
}
