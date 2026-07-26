import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/entities/trial_balance.dart';

/// Abstract repository contract for accounting data operations.
///
/// Defines the data access boundary for the accounting feature. Ledger entries
/// are auto-generated from bills and purchases, and can also be created manually
/// via journal entries. The trial balance is a derived aggregation of all
/// ledger entries grouped by account head.
abstract class AccountingRepository {
  /// Retrieves all ledger entries, optionally filtered by date range.
  Future<Either<Failure, List<LedgerEntry>>> getLedgerEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? entryType,
  });

  /// Creates a manual journal entry in the ledger.
  Future<Either<Failure, LedgerEntry>> createJournalEntry(LedgerEntry entry);

  /// Generates the trial balance by aggregating all ledger entries
  /// grouped by account head.
  Future<Either<Failure, List<TrialBalanceRow>>> getTrialBalance({
    DateTime? startDate,
    DateTime? endDate,
  });
}
