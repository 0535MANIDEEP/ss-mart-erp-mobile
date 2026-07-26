import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_local_datasource.dart';

/// Repository implementation for Category operations (offline-first).
class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryLocalDataSource localDataSource;

  CategoryRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<CategoryEntity>>> getAll() async {
    try {
      final categories = await localDataSource.getAll();
      return Right(categories.map((c) => CategoryEntity.fromDatabase(c)).toList());
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to load categories: $e'));
    }
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> getActive() async {
    try {
      final categories = await localDataSource.getActive();
      return Right(categories.map((c) => CategoryEntity.fromDatabase(c)).toList());
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to load categories: $e'));
    }
  }

  @override
  Future<Either<Failure, CategoryEntity?>> getById(String id) async {
    try {
      final category = await localDataSource.getById(id);
      return Right(category != null ? CategoryEntity.fromDatabase(category) : null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to load category: $e'));
    }
  }

  @override
  Future<Either<Failure, CategoryEntity>> create(CategoryEntity category) async {
    try {
      final created = await localDataSource.create(category.toMap());
      return Right(CategoryEntity.fromDatabase(created));
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to create category: $e'));
    }
  }

  @override
  Future<Either<Failure, CategoryEntity>> update(String id, Map<String, dynamic> data) async {
    try {
      await localDataSource.update(id, data);
      final updated = await localDataSource.getById(id);
      return Right(CategoryEntity.fromDatabase(updated!));
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to update category: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> delete(String id) async {
    try {
      await localDataSource.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to delete category: $e'));
    }
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> search(String query) async {
    try {
      final categories = await localDataSource.search(query);
      return Right(categories.map((c) => CategoryEntity.fromDatabase(c)).toList());
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to search categories: $e'));
    }
  }
}
