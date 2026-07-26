import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_repository.dart';

/// In-memory implementation of [ExpenseRepository].
///
/// Stores expenses and categories in local lists with seed data
/// for development. Provides CRUD operations, date-range filtering,
/// category filtering, and aggregated summary data for reports.
///
/// A production version would use a Drift/SQLite backing store and
/// synchronize with the backend API via the sync engine.
class ExpenseRepositoryImpl implements ExpenseRepository {
  final List<Expense> _expenses = [];
  final List<ExpenseCategory> _categories = [];
  final _uuid = const Uuid();

  ExpenseRepositoryImpl() {
    _seedData();
  }

  /// Seeds sample expense categories and expense records.
  void _seedData() {
    final now = DateTime.now();

    _categories.addAll([
      ExpenseCategory(id: 'cat-rent', name: 'Rent', description: 'Shop/office rent payments', color: '#F44336', icon: 'home', sortOrder: 1),
      ExpenseCategory(id: 'cat-utilities', name: 'Utilities', description: 'Electricity, water, internet', color: '#FF9800', icon: 'bolt', sortOrder: 2),
      ExpenseCategory(id: 'cat-salary', name: 'Salary', description: 'Employee salary payments', color: '#4CAF50', icon: 'people', sortOrder: 3),
      ExpenseCategory(id: 'cat-transport', name: 'Transport', description: 'Delivery, fuel, logistics', color: '#2196F3', icon: 'local_shipping', sortOrder: 4),
      ExpenseCategory(id: 'cat-marketing', name: 'Marketing', description: 'Advertising and promotions', color: '#9C27B0', icon: 'campaign', sortOrder: 5),
      ExpenseCategory(id: 'cat-misc', name: 'Miscellaneous', description: 'Other operating expenses', color: '#607D8B', icon: 'more_horiz', sortOrder: 6),
    ]);

    _expenses.addAll([
      Expense(id: _uuid.v4(), expenseNumber: 'EXP-0001', expenseCategoryId: 'cat-rent', categoryName: 'Rent', expenseDate: now.subtract(const Duration(days: 25)), amount: 2500000, paymentMode: 'BANK', payee: 'Property Owner', description: 'January shop rent', createdAt: now.subtract(const Duration(days: 25))),
      Expense(id: _uuid.v4(), expenseNumber: 'EXP-0002', expenseCategoryId: 'cat-utilities', categoryName: 'Utilities', expenseDate: now.subtract(const Duration(days: 20)), amount: 35000, paymentMode: 'UPI', payee: 'Electricity Board', description: 'Electricity bill — January', createdAt: now.subtract(const Duration(days: 20))),
      Expense(id: _uuid.v4(), expenseNumber: 'EXP-0003', expenseCategoryId: 'cat-salary', categoryName: 'Salary', expenseDate: now.subtract(const Duration(days: 10)), amount: 3000000, paymentMode: 'BANK', payee: 'Ravi Kumar', description: 'Monthly salary — Ravi', createdAt: now.subtract(const Duration(days: 10))),
      Expense(id: _uuid.v4(), expenseNumber: 'EXP-0004', expenseCategoryId: 'cat-transport', categoryName: 'Transport', expenseDate: now.subtract(const Duration(days: 5)), amount: 18000, paymentMode: 'CASH', payee: 'Fuel Station', description: 'Delivery van fuel refill', createdAt: now.subtract(const Duration(days: 5))),
      Expense(id: _uuid.v4(), expenseNumber: 'EXP-0005', expenseCategoryId: 'cat-marketing', categoryName: 'Marketing', expenseDate: now.subtract(const Duration(days: 3)), amount: 50000, paymentMode: 'UPI', payee: 'Print Shop', description: 'Pamphlets and banner printing', createdAt: now.subtract(const Duration(days: 3))),
      Expense(id: _uuid.v4(), expenseNumber: 'EXP-0006', expenseCategoryId: 'cat-utilities', categoryName: 'Utilities', expenseDate: now.subtract(const Duration(days: 2)), amount: 12000, paymentMode: 'CASH', payee: 'Internet Provider', description: 'Broadband monthly plan', createdAt: now.subtract(const Duration(days: 2))),
    ]);
  }

  @override
  Future<Either<Failure, List<Expense>>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
  }) async {
    try {
      var result = List<Expense>.from(_expenses)
        ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

      if (startDate != null) {
        result = result
            .where((e) => e.expenseDate.isAfter(startDate.subtract(const Duration(days: 1))))
            .toList();
      }
      if (endDate != null) {
        result = result
            .where((e) => e.expenseDate.isBefore(endDate.add(const Duration(days: 1))))
            .toList();
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        result = result.where((e) => e.expenseCategoryId == categoryId).toList();
      }

      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Expense>> getExpenseById(String id) async {
    try {
      final expense = _expenses.firstWhere((e) => e.id == id);
      return Right(expense);
    } catch (e) {
      return Left(ServerFailure(message: 'Expense not found'));
    }
  }

  @override
  Future<Either<Failure, Expense>> createExpense(Expense expense) async {
    try {
      final count = _expenses.length;
      final newExpense = expense.copyWith(
        id: expense.id.isEmpty ? _uuid.v4() : expense.id,
        expenseNumber: 'EXP-${(count + 1).toString().padLeft(4, '0')}',
        createdAt: DateTime.now(),
      );
      _expenses.add(newExpense);
      return Right(newExpense);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateExpense(Expense expense) async {
    try {
      final index = _expenses.indexWhere((e) => e.id == expense.id);
      if (index == -1) return Left(ServerFailure(message: 'Expense not found'));
      _expenses[index] = expense;
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteExpense(String id) async {
    try {
      _expenses.removeWhere((e) => e.id == id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getExpenseSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var filtered = List<Expense>.from(_expenses);

      if (startDate != null) {
        filtered = filtered
            .where((e) => e.expenseDate.isAfter(startDate.subtract(const Duration(days: 1))))
            .toList();
      }
      if (endDate != null) {
        filtered = filtered
            .where((e) => e.expenseDate.isBefore(endDate.add(const Duration(days: 1))))
            .toList();
      }

      final totalAmount = filtered.fold<int>(0, (sum, e) => sum + e.amount);

      final byCategory = <String, int>{};
      for (final e in filtered) {
        final catName = e.categoryName ?? 'Uncategorized';
        byCategory[catName] = (byCategory[catName] ?? 0) + e.amount;
      }

      final byPaymentMode = <String, int>{};
      for (final e in filtered) {
        byPaymentMode[e.paymentMode] = (byPaymentMode[e.paymentMode] ?? 0) + e.amount;
      }

      return Right({
        'totalExpenses': filtered.length,
        'totalAmount': totalAmount,
        'averageExpense': filtered.isNotEmpty ? totalAmount ~/ filtered.length : 0,
        'byCategory': byCategory,
        'byPaymentMode': byPaymentMode,
      });
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ExpenseCategory>>> getExpenseCategories() async {
    try {
      final active = _categories.where((c) => c.isActive).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return Right(active);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ExpenseCategory>> createExpenseCategory(
    ExpenseCategory category,
  ) async {
    try {
      final newCategory = category.copyWith(
        id: category.id.isEmpty ? _uuid.v4() : category.id,
      );
      _categories.add(newCategory);
      return Right(newCategory);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
