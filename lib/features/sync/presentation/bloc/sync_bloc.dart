import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/sync_queue_entity.dart';
import '../../domain/repositories/sync_repository.dart';

part 'sync_event.dart';
part 'sync_state.dart';

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncRepository syncRepository;

  SyncBloc({required this.syncRepository}) : super(SyncInitial()) {
    on<StartSync>(_onStartSync);
    on<CheckSyncStatus>(_onCheckSyncStatus);
  }

  Future<void> _onStartSync(StartSync event, Emitter<SyncState> emit) async {
    emit(SyncInProgress());
    final result = await syncRepository.syncPendingItems();
    result.fold(
      (failure) => emit(SyncError(message: failure.message)),
      (_) => emit(SyncCompleted()),
    );
  }

  Future<void> _onCheckSyncStatus(
    CheckSyncStatus event,
    Emitter<SyncState> emit,
  ) async {
    final pendingResult = await syncRepository.getPendingItems();
    final lastSyncResult = await syncRepository.getLastSyncTime();

    pendingResult.fold(
      (failure) => emit(SyncError(message: failure.message)),
      (pendingItems) {
        lastSyncResult.fold(
          (failure) => emit(SyncError(message: failure.message)),
          (lastSyncTime) {
            emit(SyncStatus(
              pendingItems: pendingItems.length,
              lastSyncTime: lastSyncTime,
            ));
          },
        );
      },
    );
  }
}
