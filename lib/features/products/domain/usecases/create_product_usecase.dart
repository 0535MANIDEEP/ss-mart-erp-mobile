import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

/// Use case for creating a new product in the system.
///
/// Validates that product name is not empty, MRP > 0, and selling price > 0
/// before delegating to the repository.
class CreateProductUseCase extends UseCase<Product, CreateProductParams> {
  final ProductRepository repository;

  /// Creates an instance of [CreateProductUseCase].
  CreateProductUseCase(this.repository);

  /// Executes the product creation with validation.
  ///
  /// Returns [ValidationFailure] if name is empty, MRP <= 0, or selling price <= 0.
  @override
  Future<Either<Failure, Product>> call(CreateProductParams params) async {
    if (params.product.name.isEmpty) {
      return const Left(ValidationFailure(message: 'Product name cannot be empty'));
    }
    if (params.product.mrp <= 0) {
      return const Left(ValidationFailure(message: 'MRP must be greater than zero'));
    }
    if (params.product.sellingPrice <= 0) {
      return const Left(ValidationFailure(message: 'Selling price must be greater than zero'));
    }
    return await repository.createProduct(params.product);
  }
}

/// Parameters for creating a new product.
class CreateProductParams {
  /// The product to create.
  final Product product;

  /// Creates [CreateProductParams] with the given product.
  const CreateProductParams({required this.product});
}
