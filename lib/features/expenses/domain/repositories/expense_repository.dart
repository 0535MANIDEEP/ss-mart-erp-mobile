import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/expense.dart';
import '../entities/expense_category.dart';

/// Repository interface for expense management operations.
///
/// Defines the contract between the domain layer and data layer for
/// CRUD operations on expenses and expense categories. Implementations
/// may use local SQLite storage or remote API calls.
abstract class ExpenseRepository {
  /// Retrieves all expenses, optionally filtered by date range or category.
  Future<Either<Failure, List<Expense>>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
  });

  /// Retrieves a single expense by its unique identifier.
  Future<Either<Failure, Expense>> getExpenseById(String id);

  /// Persists a new expense record.
  Future<Either<Failure, Expense>> createExpense(Expense expense);

  /// Updates an existing expense record.
  Future<Either<Failure, void>> updateExpense(Expense expense);

  /// Soft-deletes an expense record.
  Future<Either<Failure, void>> deleteExpense(String id);

  /// Returns aggregated expense data for reporting.
  Future<Either<Failure, Map<String, dynamic>>> getExpenseSummary({
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Retrieves all active expense categories.
  Future<Either<Failure, List<ExpenseCategory>>> getExpenseCategories();

  /// Persists a new expense category.
  Future<Either<Failure, ExpenseCategory>> createExpenseCategory(
    ExpenseCategory category,
  );
}
