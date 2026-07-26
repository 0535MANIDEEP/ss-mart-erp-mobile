import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/stock_entity.dart';
import '../repositories/stock_repository.dart';

class SearchStockUseCase extends UseCase<List<Stock>, String> {
  final StockRepository repository;

  SearchStockUseCase(this.repository);

  @override
  Future<Either<Failure, List<Stock>>> call(String query) async {
    return await repository.getStock();
  }
}
