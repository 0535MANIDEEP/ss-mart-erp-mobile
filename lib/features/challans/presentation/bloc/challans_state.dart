part of 'challans_bloc.dart';

/// States for the [ChallansBloc].
///
/// Each state represents the UI condition at a point in time, following
/// the loading → success/error pattern used across the codebase.
abstract class ChallansState extends Equatable {
  const ChallansState();

  @override
  List<Object> get props => [];
}

/// Initial state before any event is dispatched.
class ChallansInitial extends ChallansState {
  const ChallansInitial();
}

/// Loading state while an async operation is in progress.
class ChallansLoading extends ChallansState {
  const ChallansLoading();
}

/// Successfully loaded the list of challans.
class ChallansLoaded extends ChallansState {
  final List<DeliveryChallan> challans;

  const ChallansLoaded({required this.challans});

  @override
  List<Object> get props => [challans];
}

/// Successfully loaded a single challan for detail view.
class ChallanDetailLoaded extends ChallansState {
  final DeliveryChallan challan;

  const ChallanDetailLoaded({required this.challan});

  @override
  List<Object> get props => [challan];
}

/// A new challan was created successfully.
class ChallanCreated extends ChallansState {
  final DeliveryChallan challan;

  const ChallanCreated({required this.challan});

  @override
  List<Object> get props => [challan];
}

/// A challan's status was updated successfully.
class ChallanStatusUpdated extends ChallansState {
  final DeliveryChallan challan;

  const ChallanStatusUpdated({required this.challan});

  @override
  List<Object> get props => [challan];
}

/// A challan was deleted successfully.
class ChallanDeleted extends ChallansState {
  const ChallanDeleted();
}

/// Error state with a human-readable message.
class ChallansError extends ChallansState {
  final String message;

  const ChallansError({required this.message});

  @override
  List<Object> get props => [message];
}
