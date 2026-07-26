import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

/// Use case for updating an existing product.
class UpdateProductUseCase extends UseCase<Product, Product> {
  final ProductRepository repository;

  /// Creates an instance of [UpdateProductUseCase].
  UpdateProductUseCase(this.repository);

  /// Executes the product update.
  @override
  Future<Either<Failure, Product>> call(Product product) async {
    return await repository.updateProduct(product);
  }
}
