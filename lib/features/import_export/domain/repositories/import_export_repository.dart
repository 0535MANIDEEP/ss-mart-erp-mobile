import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/import_export_entity.dart';

/// Abstract repository contract for data import and export operations.
///
/// This interface defines the data access boundary for the import/export feature.
/// Supports bulk import of products, customers, and other entities from CSV/Excel
/// files, with field mapping, duplicate detection, validation, and rollback.
///
/// Exports generate CSV/Excel files from filtered entity data with
/// configurable field selection and saved export templates.
///
/// All methods return [Either<Failure, T>] to enable functional error handling
/// without exceptions, following the Clean Architecture data flow convention.
abstract class ImportExportRepository {
  /// Starts a bulk import job for the specified entity type.
  ///
  /// [entityType] is the target entity (e.g., 'product', 'customer').
  /// [rows] contains the raw parsed data from the uploaded file.
  /// [mappings] defines how source columns map to entity fields.
  /// [skipDuplicates] controls whether duplicate records are skipped or updated.
  /// Returns an [ImportJob] that tracks the import progress and results.
  Future<Either<Failure, ImportJob>> startImport({
    required String entityType,
    required String fileName,
    required String fileType,
    required List<Map<String, dynamic>> rows,
    required List<FieldMapping> mappings,
    bool skipDuplicates = true,
  });

  /// Retrieves the status and results of a specific import job.
  Future<Either<Failure, ImportJob>> getImportJob(String jobId);

  /// Retrieves paginated import job history, optionally filtered by entity type.
  Future<Either<Failure, List<ImportJob>>> getImportJobs({
    String? entityType,
    int page = 1,
    int perPage = 20,
  });

  /// Validates import data against entity constraints before starting the import.
  /// Returns a list of validation errors with row numbers and field details.
  Future<Either<Failure, List<ImportError>>> validateImportData({
    required String entityType,
    required List<Map<String, dynamic>> rows,
    required List<FieldMapping> mappings,
  });

  /// Scans the import data for potential duplicate records.
  /// Matches by configured unique fields (e.g., SKU for products, phone for customers).
  Future<Either<Failure, List<Map<String, dynamic>>>> detectDuplicates({
    required String entityType,
    required List<Map<String, dynamic>> rows,
  });

  /// Retrieves the default field mappings for the specified entity type.
  /// Used to auto-map CSV columns to entity fields on file upload.
  Future<Either<Failure, List<FieldMapping>>> getFieldMappings(String entityType);

  /// Exports entity data to a file in the specified format.
  ///
  /// [entityType] is the source entity to export.
  /// [format] is the output format ('csv' or 'excel').
  /// [fields] specifies which entity fields to include in the export.
  /// [filterCriteria] is an optional JSON filter for the exported data.
  /// Returns the file path of the generated export file.
  Future<Either<Failure, String>> exportData({
    required String entityType,
    required String format,
    required List<String> fields,
    String? filterCriteria,
  });

  /// Saves a reusable export template with predefined fields and filters.
  Future<Either<Failure, ExportTemplate>> saveExportTemplate(ExportTemplate template);

  /// Retrieves saved export templates for the specified entity type.
  Future<Either<Failure, List<ExportTemplate>>> getExportTemplates(String entityType);

  /// Deletes a saved export template by its unique identifier.
  Future<Either<Failure, void>> deleteExportTemplate(String templateId);

  /// Rolls back a previously completed import job.
  /// Reverts all database changes made during the import (best-effort).
  Future<Either<Failure, void>> rollbackImport(String jobId);

  /// Retrieves paginated import logs for auditing and troubleshooting.
  Future<Either<Failure, List<ImportLog>>> getImportLogs({
    String? entityType,
    int page = 1,
    int perPage = 20,
  });

  /// Previews the first N rows of an import file without starting an import.
  /// Used for field mapping configuration and data preview before import.
  Future<Either<Failure, List<Map<String, dynamic>>>> previewImportFile({
    required String fileName,
    required String fileType,
    int maxRows = 10,
  });
}
