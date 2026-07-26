import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/usecases/expense_usecases.dart';

/// ---------------------------------------------------------------------------
/// Events
/// ---------------------------------------------------------------------------

/// Base class for all expense-related BLoC events.
abstract class ExpensesEvent extends Equatable {
  const ExpensesEvent();

  @override
  List<Object?> get props => [];
}

/// Loads all expenses, optionally filtered by date range and category.
class LoadExpenses extends ExpensesEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;

  const LoadExpenses({this.startDate, this.endDate, this.categoryId});

  @override
  List<Object?> get props => [startDate, endDate, categoryId];
}

/// Adds a new expense record.
class AddExpense extends ExpensesEvent {
  final Expense expense;

  const AddExpense(this.expense);

  @override
  List<Object?> get props => [expense];
}

/// Updates an existing expense record.
class UpdateExpense extends ExpensesEvent {
  final Expense expense;

  const UpdateExpense(this.expense);

  @override
  List<Object?> get props => [expense];
}

/// Deletes an expense record by ID.
class DeleteExpenseEvent extends ExpensesEvent {
  final String expenseId;

  const DeleteExpenseEvent(this.expenseId);

  @override
  List<Object?> get props => [expenseId];
}

/// Loads all active expense categories for dropdown selection.
class LoadExpenseCategories extends ExpensesEvent {
  const LoadExpenseCategories();
}

/// Adds a new expense category.
class AddExpenseCategory extends ExpensesEvent {
  final ExpenseCategory category;

  const AddExpenseCategory(this.category);

  @override
  List<Object?> get props => [category];
}

/// Loads aggregated expense summary data for reporting.
class LoadExpenseSummary extends ExpensesEvent {
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadExpenseSummary({this.startDate, this.endDate});

  @override
  List<Object?> get props => [startDate, endDate];
}

/// ---------------------------------------------------------------------------
/// State
/// ---------------------------------------------------------------------------

/// State for the Expenses BLoC.
class ExpensesState extends Equatable {
  final List<Expense> expenses;
  final List<ExpenseCategory> categories;
  final Map<String, dynamic>? summary;
  final bool isLoading;
  final String? error;

  const ExpensesState({
    this.expenses = const [],
    this.categories = const [],
    this.summary,
    this.isLoading = false,
    this.error,
  });

  ExpensesState copyWith({
    List<Expense>? expenses,
    List<ExpenseCategory>? categories,
    Map<String, dynamic>? summary,
    bool? isLoading,
    String? error,
  }) {
    return ExpensesState(
      expenses: expenses ?? this.expenses,
      categories: categories ?? this.categories,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [expenses, categories, summary, isLoading, error];
}

/// ---------------------------------------------------------------------------
/// BLoC
/// ---------------------------------------------------------------------------

/// Manages expense state for the expense management feature.
///
/// Handles CRUD operations on expenses and categories, date-range
/// filtering, and aggregated summary data for expense reports.
class ExpensesBloc extends Bloc<ExpensesEvent, ExpensesState> {
  final GetExpensesUseCase _getExpenses;
  final CreateExpenseUseCase _createExpense;
  final UpdateExpenseUseCase _updateExpense;
  final DeleteExpenseUseCase _deleteExpense;
  final GetExpenseCategoriesUseCase _getCategories;
  final CreateExpenseCategoryUseCase _createCategory;
  final GetExpenseSummaryUseCase _getSummary;

  ExpensesBloc({
    required GetExpensesUseCase getExpenses,
    required CreateExpenseUseCase createExpense,
    required UpdateExpenseUseCase updateExpense,
    required DeleteExpenseUseCase deleteExpense,
    required GetExpenseCategoriesUseCase getCategories,
    required CreateExpenseCategoryUseCase createCategory,
    required GetExpenseSummaryUseCase getSummary,
  })  : _getExpenses = getExpenses,
        _createExpense = createExpense,
        _updateExpense = updateExpense,
        _deleteExpense = deleteExpense,
        _getCategories = getCategories,
        _createCategory = createCategory,
        _getSummary = getSummary,
        super(const ExpensesState()) {
    on<LoadExpenses>(_onLoadExpenses);
    on<AddExpense>(_onAddExpense);
    on<UpdateExpense>(_onUpdateExpense);
    on<DeleteExpenseEvent>(_onDeleteExpense);
    on<LoadExpenseCategories>(_onLoadCategories);
    on<AddExpenseCategory>(_onAddCategory);
    on<LoadExpenseSummary>(_onLoadSummary);
  }

  Future<void> _onLoadExpenses(
    LoadExpenses event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final result = await _getExpenses(
      startDate: event.startDate,
      endDate: event.endDate,
      categoryId: event.categoryId,
    );
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (expenses) => emit(state.copyWith(isLoading: false, expenses: expenses)),
    );
  }

  Future<void> _onAddExpense(
    AddExpense event,
    Emitter<ExpensesState> emit,
  ) async {
    final result = await _createExpense(event.expense);
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (expense) => emit(state.copyWith(
        expenses: [expense, ...state.expenses],
      )),
    );
  }

  Future<void> _onUpdateExpense(
    UpdateExpense event,
    Emitter<ExpensesState> emit,
  ) async {
    final result = await _updateExpense(event.expense);
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) {
        final updated = state.expenses.map((e) =>
            e.id == event.expense.id ? event.expense : e).toList();
        emit(state.copyWith(expenses: updated));
      },
    );
  }

  Future<void> _onDeleteExpense(
    DeleteExpenseEvent event,
    Emitter<ExpensesState> emit,
  ) async {
    final result = await _deleteExpense(event.expenseId);
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) => emit(state.copyWith(
        expenses: state.expenses.where((e) => e.id != event.expenseId).toList(),
      )),
    );
  }

  Future<void> _onLoadCategories(
    LoadExpenseCategories event,
    Emitter<ExpensesState> emit,
  ) async {
    final result = await _getCategories();
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (categories) => emit(state.copyWith(categories: categories)),
    );
  }

  Future<void> _onAddCategory(
    AddExpenseCategory event,
    Emitter<ExpensesState> emit,
  ) async {
    final result = await _createCategory(event.category);
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (category) => emit(state.copyWith(
        categories: [...state.categories, category],
      )),
    );
  }

  Future<void> _onLoadSummary(
    LoadExpenseSummary event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final result = await _getSummary(
      startDate: event.startDate,
      endDate: event.endDate,
    );
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.message)),
      (summary) => emit(state.copyWith(isLoading: false, summary: summary)),
    );
  }
}
