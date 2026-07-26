import 'package:get_it/get_it.dart';
import '../features/import_export/data/repositories/import_export_repository_impl.dart';
import '../features/import_export/domain/repositories/import_export_repository.dart';
import '../features/import_export/domain/usecases/import_export_usecases.dart';
import '../features/import_export/presentation/bloc/import_export_bloc.dart';

/// Registers import/export feature dependencies.
///
/// Bulk data import/export — CSV/Excel parsing, field mapping, validation, rollback.
void registerImportExportFeature(GetIt sl) {
  sl.registerFactory(() => ImportExportBloc(
    startImportUseCase: sl(),
    validateImportDataUseCase: sl(),
    exportDataUseCase: sl(),
    getImportLogsUseCase: sl(),
    rollbackImportUseCase: sl(),
    previewImportFileUseCase: sl(),
  ));
  sl.registerLazySingleton(() => StartImportUseCase(sl()));
  sl.registerLazySingleton(() => ValidateImportDataUseCase(sl()));
  sl.registerLazySingleton(() => ExportDataUseCase(sl()));
  sl.registerLazySingleton(() => GetImportLogsUseCase(sl()));
  sl.registerLazySingleton(() => RollbackImportUseCase(sl()));
  sl.registerLazySingleton(() => PreviewImportFileUseCase(sl()));
  sl.registerLazySingleton<ImportExportRepository>(
    () => ImportExportRepositoryImpl(dao: sl()),
  );
}
