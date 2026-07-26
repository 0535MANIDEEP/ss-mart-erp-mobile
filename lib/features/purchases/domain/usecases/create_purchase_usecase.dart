import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/purchase_entity.dart';
import '../repositories/purchase_repository.dart';

class CreatePurchaseUseCase extends UseCase<Purchase, CreatePurchaseParams> {
  final PurchaseRepository repository;

  CreatePurchaseUseCase(this.repository);

  @override
  Future<Either<Failure, Purchase>> call(CreatePurchaseParams params) async {
    return await repository.createPurchase(params.purchase);
  }
}

class CreatePurchaseParams {
  final Purchase purchase;

  const CreatePurchaseParams({required this.purchase});
}
