import 'package:get_it/get_it.dart';
import '../features/accounting/data/repositories/accounting_repository_impl.dart';
import '../features/accounting/presentation/bloc/accounting_bloc.dart';

/// Registers accounting (ledger / trial balance) feature dependencies.
///
/// Basic ledger management — view ledger entries, manual journal entries,
/// trial balance view, and date range filtering.
void registerAccountingFeature(GetIt sl) {
  sl.registerFactory(() => AccountingBloc(
        repository: sl(),
      ));
  sl.registerLazySingleton<AccountingRepositoryImpl>(
    () => AccountingRepositoryImpl(),
  );
}
