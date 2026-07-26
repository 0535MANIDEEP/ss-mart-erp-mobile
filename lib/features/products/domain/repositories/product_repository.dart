import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product_entity.dart';

/// Abstract repository contract for product data operations.
///
/// This interface defines the data access boundary for the products feature.
/// Concrete implementations handle the offline-first strategy: local SQLite
/// reads for immediate response, with background server sync for mutations.
///
/// All methods return [Either<Failure, T>] to enable functional error handling
/// without exceptions, following the Clean Architecture data flow convention.
abstract class ProductRepository {
  /// Retrieves a paginated list of products with optional filtering.
  ///
  /// [search] filters by product name, SKU, or barcode (partial match).
  /// [categoryId] filters to a specific product category.
  /// Returns a page of products ordered by name ascending.
  Future<Either<Failure, List<Product>>> getProducts({
    String? search,
    String? categoryId,
    int page = 1,
    int perPage = 20,
  });

  /// Retrieves a single product by its unique identifier.
  /// Throws [CacheFailure] if the product is not found locally.
  Future<Either<Failure, Product>> getProductById(String id);

  /// Retrieves a product by scanning its barcode.
  /// Optimized for POS quick-scan workflow.
  Future<Either<Failure, Product>> getProductByBarcode(String barcode);

  /// Creates a new product record. Enqueues a sync item for server upload.
  Future<Either<Failure, Product>> createProduct(Product product);

  /// Updates an existing product record. Enqueues a sync item for server upload.
  Future<Either<Failure, Product>> updateProduct(Product product);

  /// Soft-deletes a product by marking it inactive.
  /// Enqueues a sync item for server propagation.
  Future<Either<Failure, void>> deleteProduct(String id);
}
