import 'package:equatable/equatable.dart';

/// Domain entity representing a single business expense record.
///
/// Tracks operational expenditures (rent, utilities, salary, etc.)
/// with category classification, payment method, and optional recurring
/// scheduling. Expenses feed into the P&L report and expense analytics.
///
/// All monetary values are in paise (smallest currency unit), following
/// the project convention for consistent integer arithmetic.
class Expense extends Equatable {
  /// Unique identifier for this expense (UUID format).
  final String id;

  /// Human-readable expense number (e.g., 'EXP-0001').
  final String expenseNumber;

  /// Foreign key to the [ExpenseCategory] this expense belongs to.
  final String? expenseCategoryId;

  /// Name of the expense category (denormalized from category lookup).
  final String? categoryName;

  /// Date the expense was incurred.
  final DateTime expenseDate;

  /// Monetary amount in paise.
  final int amount;

  /// Payment method used: 'CASH', 'UPI', 'BANK', 'CARD', 'CREDIT'.
  final String paymentMode;

  /// Name of the payee or vendor.
  final String? payee;

  /// Human-readable description of the expense.
  final String? description;

  /// Type of related entity (e.g., 'bill', 'purchase', 'journal').
  final String? referenceType;

  /// Foreign key to the related entity.
  final String? referenceId;

  /// Whether this expense recurs on a schedule (e.g., monthly rent).
  final bool isRecurring;

  /// Recurring frequency: 'daily', 'weekly', 'monthly', 'yearly'.
  final String? recurringFrequency;

  /// Status: 'completed', 'pending', 'cancelled'.
  final String status;

  /// Timestamp when the expense record was created.
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.expenseNumber,
    this.expenseCategoryId,
    this.categoryName,
    required this.expenseDate,
    required this.amount,
    this.paymentMode = 'CASH',
    this.payee,
    this.description,
    this.referenceType,
    this.referenceId,
    this.isRecurring = false,
    this.recurringFrequency,
    this.status = 'completed',
    required this.createdAt,
  });

  /// Formatted amount in rupees (₹ symbol).
  String get formattedAmount => '₹${(amount / 100).toStringAsFixed(2)}';

  Expense copyWith({
    String? id,
    String? expenseNumber,
    String? expenseCategoryId,
    String? categoryName,
    DateTime? expenseDate,
    int? amount,
    String? paymentMode,
    String? payee,
    String? description,
    String? referenceType,
    String? referenceId,
    bool? isRecurring,
    String? recurringFrequency,
    String? status,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      expenseNumber: expenseNumber ?? this.expenseNumber,
      expenseCategoryId: expenseCategoryId ?? this.expenseCategoryId,
      categoryName: categoryName ?? this.categoryName,
      expenseDate: expenseDate ?? this.expenseDate,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      payee: payee ?? this.payee,
      description: description ?? this.description,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        expenseNumber,
        expenseCategoryId,
        categoryName,
        expenseDate,
        amount,
        paymentMode,
        payee,
        description,
        referenceType,
        referenceId,
        isRecurring,
        recurringFrequency,
        status,
        createdAt,
      ];
}
