import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/loyalty_entity.dart';
import '../repositories/loyalty_repository.dart';

class RedeemPointsUseCase extends UseCase<LoyaltyTransaction, RedeemPointsParams> {
  final LoyaltyRepository repository;

  RedeemPointsUseCase(this.repository);

  @override
  Future<Either<Failure, LoyaltyTransaction>> call(RedeemPointsParams params) async {
    return await repository.redeemPoints(
      customerId: params.customerId,
      points: params.points,
      referenceType: params.referenceType,
      referenceId: params.referenceId,
      notes: params.notes,
    );
  }
}

class RedeemPointsParams {
  final String customerId;
  final int points;
  final String? referenceType;
  final String? referenceId;
  final String? notes;

  const RedeemPointsParams({
    required this.customerId,
    required this.points,
    this.referenceType,
    this.referenceId,
    this.notes,
  });
}
