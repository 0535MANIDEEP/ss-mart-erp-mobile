part of 'sync_bloc.dart';

abstract class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object> get props => [];
}

class StartSync extends SyncEvent {
  const StartSync();
}

class CheckSyncStatus extends SyncEvent {
  const CheckSyncStatus();
}
