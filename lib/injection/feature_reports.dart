import 'package:get_it/get_it.dart';
import '../features/reports/data/repositories/report_repository_impl.dart';
import '../features/reports/domain/repositories/report_repository.dart';
import '../features/reports/domain/usecases/get_report_usecase.dart';
import '../features/reports/domain/usecases/export_report_usecase.dart';
import '../features/reports/presentation/bloc/reports_bloc.dart';

/// Registers reports feature dependencies.
///
/// Report generation and export — reads from DAO to compile cross-feature
/// analytics: sales, inventory, customer, employee, and purchase reports.
/// Bloc is Factory (new instance per navigation); everything else is LazySingleton.
void registerReportsFeature(GetIt sl) {
  sl.registerFactory(() => ReportsBloc(
    getReportUseCase: sl(),
    exportReportUseCase: sl(),
  ));
  sl.registerLazySingleton(() => GetReportUseCase(sl()));
  sl.registerLazySingleton(() => ExportReportUseCase(sl()));
  sl.registerLazySingleton<ReportRepository>(
    () => ReportRepositoryImpl(dao: sl(), expenseRepository: sl()),
  );
}
