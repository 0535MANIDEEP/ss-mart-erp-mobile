import 'package:equatable/equatable.dart';

/// Domain entity representing a single ledger entry in the double-entry
/// bookkeeping system.
///
/// Each ledger entry records a financial transaction as either a debit or
/// credit against a specific account head. Entries are auto-generated from
/// business transactions (bills, purchases) and can also be created manually
/// via journal entries.
///
/// ## Account Heads
/// Account heads represent the chart of accounts categories:
/// - 'Sales Revenue' — auto-created when a bill is generated (credit)
/// - 'Cash' / 'Bank' — payment received (debit)
/// - 'Accounts Receivable' — credit sales (debit)
/// - 'Purchases' — auto-created when goods are received (debit)
/// - 'GST Payable' — tax collected (credit)
/// - 'Expenses' — manual journal entries (debit)
///
/// All monetary values are in paise (smallest currency unit), following
/// the project convention for consistent integer arithmetic.
class LedgerEntry extends Equatable {
  /// Unique identifier for this ledger entry (UUID format).
  final String id;

  /// Date of the financial transaction — determines the accounting period.
  final DateTime entryDate;

  /// Direction of the entry: 'debit' or 'credit'.
  final String entryType;

  /// The account head this entry is recorded against (e.g., 'Sales Revenue',
  /// 'Cash', 'Accounts Receivable', 'Purchases', 'GST Payable', 'Expenses').
  final String accountHead;

  /// The type of business transaction that generated this entry.
  /// Used for traceability: 'bill', 'purchase', 'journal', 'payment', 'return'.
  final String referenceType;

  /// Foreign key to the source transaction (bill ID, purchase ID, etc.).
  final String referenceId;

  /// Monetary amount in paise.
  final int amount;

  /// Human-readable description of the transaction.
  final String description;

  /// Timestamp when the ledger entry was created.
  final DateTime createdAt;

  const LedgerEntry({
    required this.id,
    required this.entryDate,
    required this.entryType,
    required this.accountHead,
    required this.referenceType,
    required this.referenceId,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  /// Whether this is a debit entry.
  bool get isDebit => entryType == 'debit';

  /// Whether this is a credit entry.
  bool get isCredit => entryType == 'credit';

  LedgerEntry copyWith({
    String? id,
    DateTime? entryDate,
    String? entryType,
    String? accountHead,
    String? referenceType,
    String? referenceId,
    int? amount,
    String? description,
    DateTime? createdAt,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      entryDate: entryDate ?? this.entryDate,
      entryType: entryType ?? this.entryType,
      accountHead: accountHead ?? this.accountHead,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        entryDate,
        entryType,
        accountHead,
        referenceType,
        referenceId,
        amount,
        description,
        createdAt,
      ];
}
