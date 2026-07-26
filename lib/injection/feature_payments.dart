import 'package:get_it/get_it.dart';
import '../features/payments/data/repositories/payment_repository_impl.dart';
import '../features/payments/domain/usecases/payment_usecases.dart';
import '../features/payments/domain/repositories/payment_repository.dart';
import '../features/payments/presentation/bloc/payments_bloc.dart';

/// Registers payment tracking feature dependencies.
///
/// CRUD for customer/supplier payments — receive, make, outstanding
/// balances, advance payments, and cash flow summary.
void registerPaymentsFeature(GetIt sl) {
  sl.registerFactory(() => PaymentsBloc(
        getPayments: sl(),
        createPayment: sl(),
        getOutstanding: sl(),
        getSummary: sl(),
      ));
  sl.registerLazySingleton(() => GetPaymentsUseCase(sl()));
  sl.registerLazySingleton(() => CreatePaymentUseCase(sl()));
  sl.registerLazySingleton(() => GetOutstandingUseCase(sl()));
  sl.registerLazySingleton(() => GetPaymentSummaryUseCase(sl()));
  sl.registerLazySingleton<PaymentRepository>(
    () => PaymentRepositoryImpl(),
  );
}
