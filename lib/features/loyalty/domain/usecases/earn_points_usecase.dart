import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/loyalty_entity.dart';
import '../repositories/loyalty_repository.dart';

class EarnPointsUseCase extends UseCase<LoyaltyTransaction, EarnPointsParams> {
  final LoyaltyRepository repository;

  EarnPointsUseCase(this.repository);

  @override
  Future<Either<Failure, LoyaltyTransaction>> call(EarnPointsParams params) async {
    return await repository.earnPoints(
      customerId: params.customerId,
      points: params.points,
      referenceType: params.referenceType,
      referenceId: params.referenceId,
      notes: params.notes,
    );
  }
}

class EarnPointsParams {
  final String customerId;
  final int points;
  final String? referenceType;
  final String? referenceId;
  final String? notes;

  const EarnPointsParams({
    required this.customerId,
    required this.points,
    this.referenceType,
    this.referenceId,
    this.notes,
  });
}
