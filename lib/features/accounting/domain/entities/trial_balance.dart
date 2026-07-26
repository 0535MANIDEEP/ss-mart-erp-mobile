import 'package:equatable/equatable.dart';

/// Domain entity representing a trial balance row for a single account head.
///
/// The trial balance is a financial report that lists all account heads
/// with their total debit and credit balances. It is used to verify that
/// the double-entry bookkeeping system is in balance — total debits must
/// equal total credits across all accounts.
///
/// ## Balance Calculation
/// For each account head:
///   [balance] = [totalDebit] - [totalCredit]
///
/// - **Positive balance**: Normal for asset and expense accounts (debit nature).
/// - **Negative balance**: Normal for liability, equity, and revenue accounts
///   (credit nature).
///
/// The [netBalance] across ALL account heads should be zero when books are
/// balanced. Any non-zero total indicates a bookkeeping error.
///
/// All monetary values are in paise (smallest currency unit).
class TrialBalanceRow extends Equatable {
  /// The account head name (e.g., 'Sales Revenue', 'Cash', 'Purchases').
  final String accountHead;

  /// Sum of all debit entries against this account head, in paise.
  final int totalDebit;

  /// Sum of all credit entries against this account head, in paise.
  final int totalCredit;

  /// Net balance: [totalDebit] - [totalCredit], in paise.
  /// Positive indicates a debit balance; negative indicates a credit balance.
  final int balance;

  const TrialBalanceRow({
    required this.accountHead,
    required this.totalDebit,
    required this.totalCredit,
    required this.balance,
  });

  /// Whether this account has a debit balance (asset/expense nature).
  bool get isDebitBalance => balance > 0;

  /// Whether this account has a credit balance (liability/revenue nature).
  bool get isCreditBalance => balance < 0;

  /// Whether this account is fully settled (zero balance).
  bool get isBalanced => balance == 0;

  TrialBalanceRow copyWith({
    String? accountHead,
    int? totalDebit,
    int? totalCredit,
    int? balance,
  }) {
    return TrialBalanceRow(
      accountHead: accountHead ?? this.accountHead,
      totalDebit: totalDebit ?? this.totalDebit,
      totalCredit: totalCredit ?? this.totalCredit,
      balance: balance ?? this.balance,
    );
  }

  @override
  List<Object?> get props => [accountHead, totalDebit, totalCredit, balance];
}
