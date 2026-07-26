import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/stock_entity.dart';
import '../repositories/stock_repository.dart';

class GetStockUseCase extends UseCase<List<Stock>, GetStockParams> {
  final StockRepository repository;

  GetStockUseCase(this.repository);

  @override
  Future<Either<Failure, List<Stock>>> call(GetStockParams params) async {
    return await repository.getStock(
      locationId: params.locationId,
      lowStockOnly: params.lowStockOnly,
      page: params.page,
      perPage: params.perPage,
    );
  }
}

class GetStockParams {
  final String? locationId;
  final bool lowStockOnly;
  final int page;
  final int perPage;

  const GetStockParams({
    this.locationId,
    this.lowStockOnly = false,
    this.page = 1,
    this.perPage = 20,
  });
}
