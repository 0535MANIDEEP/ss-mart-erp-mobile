part of 'accounting_bloc.dart';

/// States for the [AccountingBloc].
///
/// Each state represents the UI condition at a point in time, following
/// the loading → success/error pattern used across the codebase.
abstract class AccountingState extends Equatable {
  const AccountingState();

  @override
  List<Object> get props => [];
}

/// Initial state before any event is dispatched.
class AccountingInitial extends AccountingState {
  const AccountingInitial();
}

/// Loading state while an async operation is in progress.
class AccountingLoading extends AccountingState {
  const AccountingLoading();
}

/// Successfully loaded ledger entries.
class LedgerLoaded extends AccountingState {
  final List<LedgerEntry> entries;

  const LedgerLoaded({required this.entries});

  @override
  List<Object> get props => [entries];
}

/// Successfully computed and loaded the trial balance.
class TrialBalanceLoaded extends AccountingState {
  final List<TrialBalanceRow> rows;

  const TrialBalanceLoaded({required this.rows});

  @override
  List<Object> get props => [rows];
}

/// A manual journal entry was created successfully.
class JournalEntryCreated extends AccountingState {
  final LedgerEntry entry;

  const JournalEntryCreated({required this.entry});

  @override
  List<Object> get props => [entry];
}

/// Error state with a human-readable message.
class AccountingError extends AccountingState {
  final String message;

  const AccountingError({required this.message});

  @override
  List<Object> get props => [message];
}
