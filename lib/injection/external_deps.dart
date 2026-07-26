import 'package:get_it/get_it.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../database/app_database.dart';
import '../database/database_dao.dart';

/// Registers external dependencies shared across all features.
///
/// Database and connectivity are shared infrastructure.
/// LazySingleton ensures only one instance is created per app lifecycle.
void registerExternalDependencies(GetIt sl) {
  final database = AppDatabase();
  final databaseDao = DatabaseDao(database);

  sl.registerLazySingleton(() => database);
  sl.registerLazySingleton(() => databaseDao);
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton(() => http.Client());
}
