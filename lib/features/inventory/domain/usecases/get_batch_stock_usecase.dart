import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/stock_entity.dart';
import '../repositories/stock_repository.dart';

class GetBatchStockUseCase extends UseCase<List<Stock>, String> {
  final StockRepository repository;
  GetBatchStockUseCase(this.repository);

  @override
  Future<Either<Failure, List<Stock>>> call(String productId) async {
    final result = await repository.getStock();
    return result.fold(
      (failure) => Left(failure),
      (stocks) {
        final batches = stocks.where((s) =>
            s.productId == productId && s.hasBatch).toList();
        batches.sort((a, b) {
          if (a.expiryDate == null) return 1;
          if (b.expiryDate == null) return -1;
          return a.expiryDate!.compareTo(b.expiryDate!);
        });
        return Right(batches);
      },
    );
  }
}
