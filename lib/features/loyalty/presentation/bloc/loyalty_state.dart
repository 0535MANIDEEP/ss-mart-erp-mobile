part of 'loyalty_bloc.dart';

abstract class LoyaltyState extends Equatable {
  const LoyaltyState();

  @override
  List<Object> get props => [];
}

class LoyaltyInitial extends LoyaltyState {
  const LoyaltyInitial();
}

class LoyaltyLoading extends LoyaltyState {
  const LoyaltyLoading();
}

class LoyaltyBalanceLoaded extends LoyaltyState {
  final LoyaltyBalance balance;

  const LoyaltyBalanceLoaded({required this.balance});

  @override
  List<Object> get props => [balance];
}

class PointsEarned extends LoyaltyState {
  final LoyaltyTransaction transaction;

  const PointsEarned({required this.transaction});

  @override
  List<Object> get props => [transaction];
}

class PointsRedeemed extends LoyaltyState {
  final LoyaltyTransaction transaction;

  const PointsRedeemed({required this.transaction});

  @override
  List<Object> get props => [transaction];
}

class LoyaltyError extends LoyaltyState {
  final String message;

  const LoyaltyError({required this.message});

  @override
  List<Object> get props => [message];
}
