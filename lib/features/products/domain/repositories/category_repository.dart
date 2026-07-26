import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/category_entity.dart';

/// Repository interface for Category operations.
abstract class CategoryRepository {
  Future<Either<Failure, List<CategoryEntity>>> getAll();
  Future<Either<Failure, List<CategoryEntity>>> getActive();
  Future<Either<Failure, CategoryEntity?>> getById(String id);
  Future<Either<Failure, CategoryEntity>> create(CategoryEntity category);
  Future<Either<Failure, CategoryEntity>> update(String id, Map<String, dynamic> data);
  Future<Either<Failure, void>> delete(String id);
  Future<Either<Failure, List<CategoryEntity>>> search(String query);
}
