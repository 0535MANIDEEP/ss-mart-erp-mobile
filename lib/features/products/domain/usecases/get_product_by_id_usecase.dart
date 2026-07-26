import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

/// Use case for retrieving a single product by its unique identifier.
class GetProductByIdUseCase extends UseCase<Product, String> {
  final ProductRepository repository;

  /// Creates an instance of [GetProductByIdUseCase].
  GetProductByIdUseCase(this.repository);

  /// Executes the product retrieval.
  @override
  Future<Either<Failure, Product>> call(String id) async {
    return await repository.getProductById(id);
  }
}
