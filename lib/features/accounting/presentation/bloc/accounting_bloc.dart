import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/entities/trial_balance.dart';
import '../../domain/repositories/accounting_repository.dart';

part 'accounting_event.dart';
part 'accounting_state.dart';

/// BLoC managing the state for the Accounting (ledger / trial balance) feature.
///
/// Handles loading ledger entries, creating manual journal entries,
/// computing the trial balance, and date-range filtering. The trial balance
/// is computed on-demand from ledger entries — it is never stored as a
/// separate entity.
///
/// ## State Flow
/// - [LoadLedger] → [AccountingLoading] → [LedgerLoaded] or [AccountingError]
/// - [LoadTrialBalance] → [AccountingLoading] → [TrialBalanceLoaded] or [AccountingError]
/// - [CreateJournalEntry] → [AccountingLoading] → [JournalEntryCreated] → auto-refreshes
/// - [LoadLedgerByDateRange] → [AccountingLoading] → [LedgerLoaded] or [AccountingError]
class AccountingBloc extends Bloc<AccountingEvent, AccountingState> {
  final AccountingRepository _repository;

  AccountingBloc({required AccountingRepository repository})
      : _repository = repository,
        super(AccountingInitial()) {
    on<LoadLedger>(_onLoadLedger);
    on<LoadTrialBalance>(_onLoadTrialBalance);
    on<CreateJournalEntry>(_onCreateJournalEntry);
    on<LoadLedgerByDateRange>(_onLoadLedgerByDateRange);
  }

  Future<void> _onLoadLedger(
    LoadLedger event,
    Emitter<AccountingState> emit,
  ) async {
    emit(AccountingLoading());
    final result = await _repository.getLedgerEntries(
      entryType: event.entryType,
    );
    result.fold(
      (failure) => emit(AccountingError(message: failure.message)),
      (entries) => emit(LedgerLoaded(entries: entries)),
    );
  }

  Future<void> _onLoadTrialBalance(
    LoadTrialBalance event,
    Emitter<AccountingState> emit,
  ) async {
    emit(AccountingLoading());
    final result = await _repository.getTrialBalance(
      startDate: event.startDate,
      endDate: event.endDate,
    );
    result.fold(
      (failure) => emit(AccountingError(message: failure.message)),
      (rows) => emit(TrialBalanceLoaded(rows: rows)),
    );
  }

  Future<void> _onCreateJournalEntry(
    CreateJournalEntry event,
    Emitter<AccountingState> emit,
  ) async {
    emit(AccountingLoading());
    final result = await _repository.createJournalEntry(event.entry);
    result.fold(
      (failure) => emit(AccountingError(message: failure.message)),
      (entry) => emit(JournalEntryCreated(entry: entry)),
    );
  }

  Future<void> _onLoadLedgerByDateRange(
    LoadLedgerByDateRange event,
    Emitter<AccountingState> emit,
  ) async {
    emit(AccountingLoading());
    final result = await _repository.getLedgerEntries(
      startDate: event.startDate,
      endDate: event.endDate,
    );
    result.fold(
      (failure) => emit(AccountingError(message: failure.message)),
      (entries) => emit(LedgerLoaded(entries: entries)),
    );
  }
}
