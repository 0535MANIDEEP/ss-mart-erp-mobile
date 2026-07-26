import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/purchase_entity.dart';
import '../repositories/purchase_repository.dart';

class GetPurchasesUseCase extends UseCase<List<Purchase>, GetPurchasesParams> {
  final PurchaseRepository repository;

  GetPurchasesUseCase(this.repository);

  @override
  Future<Either<Failure, List<Purchase>>> call(GetPurchasesParams params) async {
    return await repository.getPurchases(
      supplierId: params.supplierId,
      startDate: params.startDate,
      endDate: params.endDate,
      page: params.page,
      perPage: params.perPage,
    );
  }
}

class GetPurchasesParams {
  final String? supplierId;
  final String? startDate;
  final String? endDate;
  final int page;
  final int perPage;

  const GetPurchasesParams({
    this.supplierId,
    this.startDate,
    this.endDate,
    this.page = 1,
    this.perPage = 20,
  });
}
