import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/supplier_entity.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../datasources/supplier_local_datasource.dart';
import '../datasources/supplier_remote_datasource.dart';

/// Repository implementation for Supplier operations.
///
/// Follows the offline-first pattern: reads from local database,
/// writes to local first then queues for sync. Remote calls are
/// attempted when online and fallback gracefully to local on failure.
class SupplierRepositoryImpl implements SupplierRepository {
  final SupplierLocalDataSource localDataSource;
  final SupplierRemoteDataSource remoteDataSource;

  SupplierRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, List<SupplierEntity>>> getAll() async {
    try {
      final suppliers = await localDataSource.getAll();
      return Right(suppliers.map((s) => SupplierEntity.fromDatabase(s)).toList());
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to load suppliers: $e'));
    }
  }

  @override
  Future<Either<Failure, SupplierEntity?>> getById(String id) async {
    try {
      final supplier = await localDataSource.getById(id);
      return Right(supplier != null ? SupplierEntity.fromDatabase(supplier) : null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to load supplier: $e'));
    }
  }

  @override
  Future<Either<Failure, SupplierEntity>> create(SupplierEntity supplier) async {
    try {
      final created = await localDataSource.create(supplier.toMap());
      try { await remoteDataSource.create(supplier.toMap()); } catch (_) {}
      return Right(SupplierEntity.fromDatabase(created));
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to create supplier: $e'));
    }
  }

  @override
  Future<Either<Failure, SupplierEntity>> update(String id, Map<String, dynamic> data) async {
    try {
      await localDataSource.update(id, data);
      try { await remoteDataSource.update(id, data); } catch (_) {}
      final updated = await localDataSource.getById(id);
      return Right(SupplierEntity.fromDatabase(updated!));
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to update supplier: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> delete(String id) async {
    try {
      await localDataSource.delete(id);
      try { await remoteDataSource.delete(id); } catch (_) {}
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to delete supplier: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SupplierEntity>>> search(String query) async {
    try {
      final suppliers = await localDataSource.search(query);
      return Right(suppliers.map((s) => SupplierEntity.fromDatabase(s)).toList());
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to search suppliers: $e'));
    }
  }
}
