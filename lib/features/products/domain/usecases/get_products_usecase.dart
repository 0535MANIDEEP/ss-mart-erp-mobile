import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class GetProductsUseCase extends UseCase<List<Product>, GetProductsParams> {
  final ProductRepository repository;

  GetProductsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Product>>> call(GetProductsParams params) async {
    return await repository.getProducts(
      search: params.search,
      categoryId: params.categoryId,
      page: params.page,
      perPage: params.perPage,
    );
  }
}

class GetProductsParams {
  final String? search;
  final String? categoryId;
  final int page;
  final int perPage;

  const GetProductsParams({
    this.search,
    this.categoryId,
    this.page = 1,
    this.perPage = 20,
  });
}
