import 'package:get_it/get_it.dart';
import '../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../features/dashboard/domain/usecases/get_dashboard_stats_usecase.dart';
import '../features/dashboard/presentation/bloc/dashboard_bloc.dart';

/// Registers dashboard feature dependencies.
///
/// Dashboard data aggregation — reads from DAO to compile cross-feature metrics.
void registerDashboardFeature(GetIt sl) {
  sl.registerFactory(() => DashboardBloc(
    getDashboardStatsUseCase: sl(),
    repository: sl(),
  ));
  sl.registerLazySingleton(() => GetDashboardStatsUseCase(sl()));
  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(dao: sl(), connectivity: sl()),
  );
}
