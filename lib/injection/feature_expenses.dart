import 'package:get_it/get_it.dart';
import '../features/expenses/data/repositories/expense_repository_impl.dart';
import '../features/expenses/domain/usecases/expense_usecases.dart';
import '../features/expenses/domain/repositories/expense_repository.dart';
import '../features/expenses/presentation/bloc/expenses_bloc.dart';

/// Registers expense management feature dependencies.
///
/// CRUD for business expenses — list, create, edit, delete expenses
/// and expense categories. Feeds the expense report and P&L analysis.
void registerExpensesFeature(GetIt sl) {
  sl.registerFactory(() => ExpensesBloc(
        getExpenses: sl(),
        createExpense: sl(),
        updateExpense: sl(),
        deleteExpense: sl(),
        getCategories: sl(),
        createCategory: sl(),
        getSummary: sl(),
      ));
  sl.registerLazySingleton(() => GetExpensesUseCase(sl()));
  sl.registerLazySingleton(() => GetExpenseByIdUseCase(sl()));
  sl.registerLazySingleton(() => CreateExpenseUseCase(sl()));
  sl.registerLazySingleton(() => UpdateExpenseUseCase(sl()));
  sl.registerLazySingleton(() => DeleteExpenseUseCase(sl()));
  sl.registerLazySingleton(() => GetExpenseSummaryUseCase(sl()));
  sl.registerLazySingleton(() => GetExpenseCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => CreateExpenseCategoryUseCase(sl()));
  sl.registerLazySingleton<ExpenseRepository>(
    () => ExpenseRepositoryImpl(),
  );
}
