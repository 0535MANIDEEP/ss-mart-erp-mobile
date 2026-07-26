import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/stock_entity.dart';
import '../repositories/stock_repository.dart';

class GetExpiringProductsUseCase extends UseCase<List<Stock>, ExpiringProductsParams> {
  final StockRepository repository;
  GetExpiringProductsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Stock>>> call(ExpiringProductsParams params) async {
    final result = await repository.getStock();
    return result.fold(
      (failure) => Left(failure),
      (stocks) {
        final now = DateTime.now();
        final threshold = now.add(Duration(days: params.daysThreshold));
        final expiring = stocks.where((s) =>
            s.expiryDate != null &&
            s.expiryDate!.isAfter(now) &&
            s.expiryDate!.isBefore(threshold)).toList();
        expiring.sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
        return Right(expiring);
      },
    );
  }
}

class ExpiringProductsParams {
  final int daysThreshold;
  const ExpiringProductsParams({this.daysThreshold = 30});
}
