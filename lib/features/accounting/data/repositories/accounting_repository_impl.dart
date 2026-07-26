import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/entities/trial_balance.dart';
import '../../domain/repositories/accounting_repository.dart';

/// In-memory implementation of [AccountingRepository].
///
/// Stores all ledger entries in a local list. On initialization, seeds
/// sample ledger entries that would normally be auto-generated from bills
/// and purchases in a production system. Manual journal entries are appended
/// to the same list.
///
/// The trial balance is computed dynamically by grouping and aggregating
/// ledger entries by account head — it is never stored independently.
///
/// This implementation is suitable for prototyping. A production version
/// would use a Drift/SQLite backing store and auto-generate ledger entries
/// within the billing and purchases repositories.
class AccountingRepositoryImpl implements AccountingRepository {
  final List<LedgerEntry> _entries = [];
  final _uuid = const Uuid();

  AccountingRepositoryImpl() {
    _seedSampleEntries();
  }

  /// Seeds the ledger with representative entries that mirror what would
  /// be auto-generated from real bills and purchases. This provides a
  /// realistic dataset for the trial balance and ledger views.
  void _seedSampleEntries() {
    final now = DateTime.now();

    _entries.addAll([
      LedgerEntry(
        id: _uuid.v4(),
        entryDate: now.subtract(const Duration(days: 5)),
        entryType: 'credit',
        accountHead: 'Sales Revenue',
        referenceType: 'bill',
        referenceId: 'bill-sample-1',
        amount: 1500000,
        description: 'Sales Bill BILL-0001 — Walk-in Customer',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      LedgerEntry(
        id: _uuid.v4(),
        entryDate: now.subtract(const Duration(days: 5)),
        entryType: 'debit',
        accountHead: 'Cash',
        referenceType: 'bill',
        referenceId: 'bill-sample-1',
        amount: 1500000,
        description: 'Payment received for BILL-0001 (CASH)',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      LedgerEntry(
        id: _uuid.v4(),
        entryDate: now.subtract(const Duration(days: 4)),
        entryType: 'credit',
        accountHead: 'Sales Revenue',
        referenceType: 'bill',
        referenceId: 'bill-sample-2',
        amount: 2750000,
        description: 'Sales Bill BILL-0002 — Rajesh Kumar',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      LedgerEntry(
        id: _uuid.v4(),
        entryDate: now.subtract(const Duration(days: 4)),
        entryType: 'debit',
        accountHead: 'Accounts Receivable',
        referenceType: 'bill',
        referenceId: 'bill-sample-2',
        amount: 2750000,
        description: 'Credit sale for BILL-0002 — Rajesh Kumar',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      LedgerEntry(
        id: _uuid.v4(),
        entryDate: now.subtract(const Duration(days: 3)),
        entryType: 'debit',
        accountHead: 'Purchases',
        referenceType: 'purchase',
        referenceId: 'purchase-sample-1',
        amount: 5200000,
        description: 'Purchase Order PO-0001 — Distributor Supplies',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      LedgerEntry(
        id: _uuid.v4(),
        entryDate: now.subtract(const Duration(days: 3)),
        entryType: 'credit',
        accountHead: 'Accounts Payable',
        referenceType: 'purchase',
        referenceId: 'purchase-sample-1',
        amount: 5200000,
        description: 'Purchase on credit — Distributor Supplies',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      LedgerEntry(
        id: _uuid.v4(),
        entryDate: now.subtract(const Duration(days: 2)),
        entryType: 'credit',
        accountHead: 'Sales Revenue',
        referenceType: 'bill',
        referenceId: 'bill-sample-3',
        amount: 875000,
        description: 'Sales Bill BILL-0003 — Priya Traders',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      LedgerEntry(
        id: _uuid.v4(),
        entryDate: now.subtract(const Duration(days: 2)),
        entryType: 'debit',
        accountHead: 'Cash',
        referenceType: 'bill',
        referenceId: 'bill-sample-3',
        amount: 875000,
        description: 'Payment received for BILL-0003 (UPI)',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      LedgerEntry(
        id: _uuid.v4(),
        entryDate: now.subtract(const Duration(days: 1)),
        entryType: 'debit',
        accountHead: 'Expenses',
        referenceType: 'journal',
        referenceId: 'journal-sample-1',
        amount: 35000,
        description: 'Electricity bill payment — January',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      LedgerEntry(
        id: _uuid.v4(),
        entryDate: now.subtract(const Duration(days: 1)),
        entryType: 'credit',
        accountHead: 'Cash',
        referenceType: 'journal',
        referenceId: 'journal-sample-1',
        amount: 35000,
        description: 'Cash payment for electricity bill',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  @override
  Future<Either<Failure, List<LedgerEntry>>> getLedgerEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? entryType,
  }) async {
    try {
      var result = List<LedgerEntry>.from(_entries)
        ..sort((a, b) => b.entryDate.compareTo(a.entryDate));

      if (startDate != null) {
        result = result
            .where((e) => e.entryDate.isAfter(startDate.subtract(const Duration(days: 1))))
            .toList();
      }
      if (endDate != null) {
        result = result
            .where((e) => e.entryDate.isBefore(endDate.add(const Duration(days: 1))))
            .toList();
      }
      if (entryType != null && entryType.isNotEmpty) {
        result = result.where((e) => e.entryType == entryType).toList();
      }

      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, LedgerEntry>> createJournalEntry(
    LedgerEntry entry,
  ) async {
    try {
      final now = DateTime.now();
      final newEntry = entry.copyWith(
        id: entry.id.isEmpty ? _uuid.v4() : entry.id,
        createdAt: now,
      );
      _entries.add(newEntry);
      return Right(newEntry);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TrialBalanceRow>>> getTrialBalance({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var filtered = List<LedgerEntry>.from(_entries);

      if (startDate != null) {
        filtered = filtered
            .where((e) => e.entryDate.isAfter(startDate.subtract(const Duration(days: 1))))
            .toList();
      }
      if (endDate != null) {
        filtered = filtered
            .where((e) => e.entryDate.isBefore(endDate.add(const Duration(days: 1))))
            .toList();
      }

      final Map<String, int> debitTotals = {};
      final Map<String, int> creditTotals = {};

      for (final entry in filtered) {
        if (entry.entryType == 'debit') {
          debitTotals[entry.accountHead] =
              (debitTotals[entry.accountHead] ?? 0) + entry.amount;
        } else {
          creditTotals[entry.accountHead] =
              (creditTotals[entry.accountHead] ?? 0) + entry.amount;
        }
      }

      final allHeads = <String>{...debitTotals.keys, ...creditTotals.keys};
      final rows = allHeads.map((head) {
        final debit = debitTotals[head] ?? 0;
        final credit = creditTotals[head] ?? 0;
        return TrialBalanceRow(
          accountHead: head,
          totalDebit: debit,
          totalCredit: credit,
          balance: debit - credit,
        );
      }).toList()
        ..sort((a, b) => a.accountHead.compareTo(b.accountHead));

      return Right(rows);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
