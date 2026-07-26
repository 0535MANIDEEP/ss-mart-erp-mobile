part of 'challans_bloc.dart';

/// Events for the [ChallansBloc].
///
/// Each event represents a user action or system trigger that causes
/// a state transition in the challans feature.
abstract class ChallansEvent extends Equatable {
  const ChallansEvent();

  @override
  List<Object> get props => [];
}

/// Loads all challans, optionally filtered by status.
class LoadChallans extends ChallansEvent {
  /// Optional status filter: 'pending', 'dispatched', 'delivered', 'cancelled'.
  /// Null or empty returns all challans.
  final String? status;

  const LoadChallans({this.status});

  @override
  List<Object> get props => [status ?? ''];
}

/// Loads a single challan by its unique identifier.
class LoadChallanById extends ChallansEvent {
  final String challanId;

  const LoadChallanById({required this.challanId});

  @override
  List<Object> get props => [challanId];
}

/// Creates a new delivery challan.
class CreateChallan extends ChallansEvent {
  final DeliveryChallan challan;

  const CreateChallan({required this.challan});

  @override
  List<Object> get props => [challan];
}

/// Updates the status of an existing challan.
class UpdateChallanStatus extends ChallansEvent {
  final String challanId;
  final String newStatus;

  const UpdateChallanStatus({
    required this.challanId,
    required this.newStatus,
  });

  @override
  List<Object> get props => [challanId, newStatus];
}

/// Deletes a challan by its unique identifier.
class DeleteChallan extends ChallansEvent {
  final String challanId;

  const DeleteChallan({required this.challanId});

  @override
  List<Object> get props => [challanId];
}
