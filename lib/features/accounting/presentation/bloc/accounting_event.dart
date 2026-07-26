part of 'accounting_bloc.dart';

/// Events for the [AccountingBloc].
///
/// Each event represents a user action or system trigger that causes
/// a state transition in the accounting feature.
abstract class AccountingEvent extends Equatable {
  const AccountingEvent();

  @override
  List<Object> get props => [];
}

/// Loads all ledger entries with optional entry type filter.
class LoadLedger extends AccountingEvent {
  /// Optional entry type filter: 'debit' or 'credit'. Null returns all.
  final String? entryType;

  const LoadLedger({this.entryType});

  @override
  List<Object> get props => [entryType ?? ''];
}

/// Loads the trial balance, optionally within a date range.
class LoadTrialBalance extends AccountingEvent {
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadTrialBalance({this.startDate, this.endDate});

  @override
  List<Object> get props => [startDate ?? '', endDate ?? ''];
}

/// Creates a manual journal entry in the ledger.
class CreateJournalEntry extends AccountingEvent {
  final LedgerEntry entry;

  const CreateJournalEntry({required this.entry});

  @override
  List<Object> get props => [entry];
}

/// Loads ledger entries filtered by a specific date range.
class LoadLedgerByDateRange extends AccountingEvent {
  final DateTime startDate;
  final DateTime endDate;

  const LoadLedgerByDateRange({
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object> get props => [startDate, endDate];
}
