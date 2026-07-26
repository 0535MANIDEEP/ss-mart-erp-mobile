import 'package:get_it/get_it.dart';
import '../features/labels/data/repositories/label_repository_impl.dart';
import '../features/labels/presentation/bloc/labels_bloc.dart';

/// Registers labels feature dependencies.
///
/// The labels feature has a minimal dependency graph:
/// - **Repository**: [LabelRepositoryImpl] wraps the existing [AppDatabase]
///   to read products and generate print jobs. No remote data source is
///   needed since labels are generated purely from local product data.
/// - **BLoC**: [LabelsBloc] is registered as a factory so each navigation
///   to the labels page gets a fresh state instance.
///
/// Note: The [LabelsBloc] is also provided via [BlocProvider] in the page
/// itself. This factory registration exists for DI testing and for cases
/// where the BLoC needs to be resolved from the service locator.
void registerLabelsFeature(GetIt sl) {
  sl.registerFactory(
    () => LabelsBloc(labelRepository: sl()),
  );
  sl.registerLazySingleton<LabelRepositoryImpl>(
    () => LabelRepositoryImpl(database: sl()),
  );
}
