import 'package:get_it/get_it.dart';
import '../features/challans/data/repositories/challan_repository_impl.dart';
import '../features/challans/presentation/bloc/challans_bloc.dart';

/// Registers challans (delivery notes) feature dependencies.
///
/// Delivery challan management — create, dispatch, track, and deliver goods
/// with vehicle and driver details.
void registerChallansFeature(GetIt sl) {
  sl.registerFactory(() => ChallansBloc(
        repository: sl(),
      ));
  sl.registerLazySingleton<ChallanRepositoryImpl>(
    () => ChallanRepositoryImpl(),
  );
}
