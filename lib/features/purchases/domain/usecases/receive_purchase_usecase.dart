import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/purchase_entity.dart';
import '../repositories/purchase_repository.dart';

class ReceivePurchaseUseCase extends UseCase<Purchase, ReceivePurchaseParams> {
  final PurchaseRepository repository;

  ReceivePurchaseUseCase(this.repository);

  @override
  Future<Either<Failure, Purchase>> call(ReceivePurchaseParams params) async {
    return await repository.receivePurchase(
      purchaseId: params.purchaseId,
      receivedItems: params.receivedItems,
    );
  }
}

class ReceivePurchaseParams {
  final String purchaseId;
  final List<PurchaseItem> receivedItems;

  const ReceivePurchaseParams({
    required this.purchaseId,
    required this.receivedItems,
  });
}
