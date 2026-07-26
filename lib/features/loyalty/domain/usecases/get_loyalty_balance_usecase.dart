import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/loyalty_balance.dart';
import '../repositories/loyalty_repository.dart';

class GetLoyaltyBalanceUseCase extends UseCase<LoyaltyBalance, String> {
  final LoyaltyRepository repository;

  GetLoyaltyBalanceUseCase(this.repository);

  @override
  Future<Either<Failure, LoyaltyBalance>> call(String customerId) async {
    return await repository.getLoyaltyBalance(customerId);
  }
}
