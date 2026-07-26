import 'package:get_it/get_it.dart';
import '../features/settings/data/datasources/settings_local_datasource.dart';
import '../features/settings/data/repositories/settings_repository_impl.dart';
import '../features/settings/domain/repositories/settings_repository.dart';
import '../features/settings/domain/usecases/settings_usecases.dart';

/// Registers settings feature dependencies.
///
/// Application settings — key-value prefs, business profile, sync configuration.
/// Settings are local-only (no remote data source needed).
void registerSettingsFeature(GetIt sl) {
  sl.registerLazySingleton<SettingsLocalDataSource>(
    () => SettingsLocalDataSourceImpl(dao: sl()),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetSettingUseCase(sl()));
  sl.registerLazySingleton(() => SetSettingUseCase(sl()));
  sl.registerLazySingleton(() => GetAllSettingsUseCase(sl()));
  sl.registerLazySingleton(() => DeleteSettingUseCase(sl()));
  sl.registerLazySingleton(() => GetBusinessProfileUseCase(sl()));
  sl.registerLazySingleton(() => SaveBusinessProfileUseCase(sl()));
  sl.registerLazySingleton(() => GetAllBusinessProfilesUseCase(sl()));
  sl.registerLazySingleton(() => GetSyncSettingsUseCase(sl()));
  sl.registerLazySingleton(() => SaveSyncSettingsUseCase(sl()));
}
