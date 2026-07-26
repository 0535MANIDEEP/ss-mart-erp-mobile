import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/expense.dart';
import '../entities/expense_category.dart';
import '../repositories/expense_repository.dart';

/// Fetches all expenses with optional date range and category filters.
class GetExpensesUseCase {
  final ExpenseRepository _repository;

  const GetExpensesUseCase(this._repository);

  Future<Either<Failure, List<Expense>>> call({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
  }) {
    return _repository.getExpenses(
      startDate: startDate,
      endDate: endDate,
      categoryId: categoryId,
    );
  }
}

/// Fetches a single expense by ID.
class GetExpenseByIdUseCase {
  final ExpenseRepository _repository;

  const GetExpenseByIdUseCase(this._repository);

  Future<Either<Failure, Expense>> call(String id) {
    return _repository.getExpenseById(id);
  }
}

/// Creates a new expense record.
class CreateExpenseUseCase {
  final ExpenseRepository _repository;

  const CreateExpenseUseCase(this._repository);

  Future<Either<Failure, Expense>> call(Expense expense) {
    return _repository.createExpense(expense);
  }
}

/// Updates an existing expense record.
class UpdateExpenseUseCase {
  final ExpenseRepository _repository;

  const UpdateExpenseUseCase(this._repository);

  Future<Either<Failure, void>> call(Expense expense) {
    return _repository.updateExpense(expense);
  }
}

/// Soft-deletes an expense record.
class DeleteExpenseUseCase {
  final ExpenseRepository _repository;

  const DeleteExpenseUseCase(this._repository);

  Future<Either<Failure, void>> call(String id) {
    return _repository.deleteExpense(id);
  }
}

/// Fetches aggregated expense summary data for reporting.
class GetExpenseSummaryUseCase {
  final ExpenseRepository _repository;

  const GetExpenseSummaryUseCase(this._repository);

  Future<Either<Failure, Map<String, dynamic>>> call({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _repository.getExpenseSummary(startDate: startDate, endDate: endDate);
  }
}

/// Fetches all active expense categories.
class GetExpenseCategoriesUseCase {
  final ExpenseRepository _repository;

  const GetExpenseCategoriesUseCase(this._repository);

  Future<Either<Failure, List<ExpenseCategory>>> call() {
    return _repository.getExpenseCategories();
  }
}

/// Creates a new expense category.
class CreateExpenseCategoryUseCase {
  final ExpenseRepository _repository;

  const CreateExpenseCategoryUseCase(this._repository);

  Future<Either<Failure, ExpenseCategory>> call(ExpenseCategory category) {
    return _repository.createExpenseCategory(category);
  }
}
