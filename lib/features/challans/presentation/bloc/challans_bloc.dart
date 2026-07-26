import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/delivery_challan.dart';
import '../../domain/entities/delivery_challan_item.dart';
import '../../domain/repositories/challan_repository.dart';

part 'challans_event.dart';
part 'challans_state.dart';

/// BLoC managing the state for the Challans (delivery notes) feature.
///
/// Handles loading, creating, updating status, and deleting delivery challans.
/// Follows the established BLoC pattern in this codebase — each event handler
/// calls the repository, emits loading/error/success states, and refreshes
/// the list when a mutation succeeds.
///
/// ## State Flow
/// - [LoadChallans] → [ChallansLoading] → [ChallansLoaded] or [ChallansError]
/// - [CreateChallan] → [ChallansLoading] → [ChallanCreated] → auto-loads list
/// - [UpdateChallanStatus] → [ChallansLoading] → [ChallanStatusUpdated] → auto-loads list
/// - [DeleteChallan] → [ChallansLoading] → [ChallanDeleted] → auto-loads list
class ChallansBloc extends Bloc<ChallansEvent, ChallansState> {
  final ChallanRepository _repository;

  ChallansBloc({required ChallanRepository repository})
      : _repository = repository,
        super(ChallansInitial()) {
    on<LoadChallans>(_onLoadChallans);
    on<LoadChallanById>(_onLoadChallanById);
    on<CreateChallan>(_onCreateChallan);
    on<UpdateChallanStatus>(_onUpdateChallanStatus);
    on<DeleteChallan>(_onDeleteChallan);
  }

  Future<void> _onLoadChallans(
    LoadChallans event,
    Emitter<ChallansState> emit,
  ) async {
    emit(ChallansLoading());
    final result = await _repository.getChallans(status: event.status);
    result.fold(
      (failure) => emit(ChallansError(message: failure.message)),
      (challans) => emit(ChallansLoaded(challans: challans)),
    );
  }

  Future<void> _onLoadChallanById(
    LoadChallanById event,
    Emitter<ChallansState> emit,
  ) async {
    emit(ChallansLoading());
    final result = await _repository.getChallanById(event.challanId);
    result.fold(
      (failure) => emit(ChallansError(message: failure.message)),
      (challan) => emit(ChallanDetailLoaded(challan: challan)),
    );
  }

  Future<void> _onCreateChallan(
    CreateChallan event,
    Emitter<ChallansState> emit,
  ) async {
    emit(ChallansLoading());
    final result = await _repository.createChallan(event.challan);
    result.fold(
      (failure) => emit(ChallansError(message: failure.message)),
      (challan) => emit(ChallanCreated(challan: challan)),
    );
  }

  Future<void> _onUpdateChallanStatus(
    UpdateChallanStatus event,
    Emitter<ChallansState> emit,
  ) async {
    emit(ChallansLoading());
    final result = await _repository.updateChallanStatus(
      event.challanId,
      event.newStatus,
    );
    result.fold(
      (failure) => emit(ChallansError(message: failure.message)),
      (challan) => emit(ChallanStatusUpdated(challan: challan)),
    );
  }

  Future<void> _onDeleteChallan(
    DeleteChallan event,
    Emitter<ChallansState> emit,
  ) async {
    emit(ChallansLoading());
    final result = await _repository.deleteChallan(event.challanId);
    result.fold(
      (failure) => emit(ChallansError(message: failure.message)),
      (_) => emit(ChallanDeleted()),
    );
  }
}
