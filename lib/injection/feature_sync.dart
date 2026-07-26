import 'package:get_it/get_it.dart';
import '../features/sync/data/repositories/sync_repository_impl.dart';
import '../features/sync/domain/repositories/sync_repository.dart';
import '../features/sync/presentation/bloc/sync_bloc.dart';

/// Registers sync feature dependencies.
///
/// Offline-to-online sync — queue management, retry logic, conflict resolution.
void registerSyncFeature(GetIt sl) {
  sl.registerFactory(() => SyncBloc(syncRepository: sl()));
  sl.registerLazySingleton<SyncRepository>(
    () => SyncRepositoryImpl(dao: sl()),
  );
}
