import 'package:get_it/get_it.dart';
import '../features/loyalty/data/datasources/loyalty_local_datasource.dart';
import '../features/loyalty/data/datasources/loyalty_remote_datasource.dart';
import '../features/loyalty/data/repositories/loyalty_repository_impl.dart';
import '../features/loyalty/domain/repositories/loyalty_repository.dart';
import '../features/loyalty/domain/usecases/get_loyalty_balance_usecase.dart';
import '../features/loyalty/domain/usecases/earn_points_usecase.dart';
import '../features/loyalty/domain/usecases/redeem_points_usecase.dart';
import '../features/loyalty/presentation/bloc/loyalty_bloc.dart';

/// Registers loyalty feature dependencies.
///
/// Loyalty program — point accrual, redemption, balance tracking, expiry management.
void registerLoyaltyFeature(GetIt sl) {
  sl.registerFactory(() => LoyaltyBloc(
    getLoyaltyBalanceUseCase: sl(),
    earnPointsUseCase: sl(),
    redeemPointsUseCase: sl(),
  ));
  sl.registerLazySingleton(() => GetLoyaltyBalanceUseCase(sl()));
  sl.registerLazySingleton(() => EarnPointsUseCase(sl()));
  sl.registerLazySingleton(() => RedeemPointsUseCase(sl()));
  sl.registerLazySingleton<LoyaltyRepository>(
    () => LoyaltyRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<LoyaltyRemoteDataSource>(
    () => LoyaltyRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<LoyaltyLocalDataSource>(
    () => LoyaltyLocalDataSourceImpl(database: sl()),
  );
}
