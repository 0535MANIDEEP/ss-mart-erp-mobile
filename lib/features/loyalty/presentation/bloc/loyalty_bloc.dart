import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/loyalty_balance.dart';
import '../../domain/entities/loyalty_entity.dart';
import '../../domain/usecases/get_loyalty_balance_usecase.dart';
import '../../domain/usecases/earn_points_usecase.dart';
import '../../domain/usecases/redeem_points_usecase.dart';

part 'loyalty_event.dart';
part 'loyalty_state.dart';

class LoyaltyBloc extends Bloc<LoyaltyEvent, LoyaltyState> {
  final GetLoyaltyBalanceUseCase getLoyaltyBalanceUseCase;
  final EarnPointsUseCase earnPointsUseCase;
  final RedeemPointsUseCase redeemPointsUseCase;

  LoyaltyBloc({
    required this.getLoyaltyBalanceUseCase,
    required this.earnPointsUseCase,
    required this.redeemPointsUseCase,
  }) : super(LoyaltyInitial()) {
    on<LoadLoyaltyBalance>(_onLoadBalance);
    on<EarnPointsRequested>(_onEarnPoints);
    on<RedeemPointsRequested>(_onRedeemPoints);
  }

  Future<void> _onLoadBalance(
    LoadLoyaltyBalance event,
    Emitter<LoyaltyState> emit,
  ) async {
    emit(LoyaltyLoading());
    final result = await getLoyaltyBalanceUseCase(event.customerId);
    result.fold(
      (failure) => emit(LoyaltyError(message: failure.message)),
      (balance) => emit(LoyaltyBalanceLoaded(balance: balance)),
    );
  }

  Future<void> _onEarnPoints(
    EarnPointsRequested event,
    Emitter<LoyaltyState> emit,
  ) async {
    emit(LoyaltyLoading());
    final result = await earnPointsUseCase(
      EarnPointsParams(
        customerId: event.customerId,
        points: event.points,
        referenceType: event.referenceType,
        referenceId: event.referenceId,
      ),
    );
    result.fold(
      (failure) => emit(LoyaltyError(message: failure.message)),
      (transaction) => emit(PointsEarned(transaction: transaction)),
    );
  }

  Future<void> _onRedeemPoints(
    RedeemPointsRequested event,
    Emitter<LoyaltyState> emit,
  ) async {
    emit(LoyaltyLoading());
    final result = await redeemPointsUseCase(
      RedeemPointsParams(
        customerId: event.customerId,
        points: event.points,
        referenceType: event.referenceType,
        referenceId: event.referenceId,
      ),
    );
    result.fold(
      (failure) => emit(LoyaltyError(message: failure.message)),
      (transaction) => emit(PointsRedeemed(transaction: transaction)),
    );
  }
}
