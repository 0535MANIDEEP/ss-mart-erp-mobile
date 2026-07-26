part of 'loyalty_bloc.dart';

abstract class LoyaltyEvent extends Equatable {
  const LoyaltyEvent();

  @override
  List<Object> get props => [];
}

class LoadLoyaltyBalance extends LoyaltyEvent {
  final String customerId;

  const LoadLoyaltyBalance({required this.customerId});

  @override
  List<Object> get props => [customerId];
}

class EarnPointsRequested extends LoyaltyEvent {
  final String customerId;
  final int points;
  final String? referenceType;
  final String? referenceId;

  const EarnPointsRequested({
    required this.customerId,
    required this.points,
    this.referenceType,
    this.referenceId,
  });

  @override
  List<Object> get props => [customerId, points, referenceType ?? '', referenceId ?? ''];
}

class RedeemPointsRequested extends LoyaltyEvent {
  final String customerId;
  final int points;
  final String? referenceType;
  final String? referenceId;

  const RedeemPointsRequested({
    required this.customerId,
    required this.points,
    this.referenceType,
    this.referenceId,
  });

  @override
  List<Object> get props => [customerId, points, referenceType ?? '', referenceId ?? ''];
}
