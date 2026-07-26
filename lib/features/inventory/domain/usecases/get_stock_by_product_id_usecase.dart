import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/stock_entity.dart';
import '../repositories/stock_repository.dart';

/// Use case for retrieving the stock record for a specific product.
class GetStockByProductIdUseCase extends UseCase<Stock, String> {
  final StockRepository repository;

  /// Creates an instance of [GetStockByProductIdUseCase].
  GetStockByProductIdUseCase(this.repository);

  /// Executes the stock retrieval by product ID.
  @override
  Future<Either<Failure, Stock>> call(String productId) async {
    return await repository.getStockByProductId(productId);
  }
}
