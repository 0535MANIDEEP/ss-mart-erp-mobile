import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../repositories/product_repository.dart';

/// Use case for soft-deleting a product by marking it inactive.
class DeleteProductUseCase extends UseCase<void, String> {
  final ProductRepository repository;

  /// Creates an instance of [DeleteProductUseCase].
  DeleteProductUseCase(this.repository);

  /// Executes the product deletion.
  @override
  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteProduct(id);
  }
}
