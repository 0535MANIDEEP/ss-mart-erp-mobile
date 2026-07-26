part of 'sync_bloc.dart';

abstract class SyncState extends Equatable {
  const SyncState();

  @override
  List<Object> get props => [];
}

class SyncInitial extends SyncState {
  const SyncInitial();
}

class SyncInProgress extends SyncState {
  const SyncInProgress();
}

class SyncCompleted extends SyncState {
  const SyncCompleted();
}

class SyncStatus extends SyncState {
  final int pendingItems;
  final DateTime? lastSyncTime;

  const SyncStatus({
    required this.pendingItems,
    this.lastSyncTime,
  });

  @override
  List<Object> get props => [pendingItems, lastSyncTime ?? ''];
}

class SyncError extends SyncState {
  final String message;

  const SyncError({required this.message});

  @override
  List<Object> get props => [message];
}
