import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/supplier_entity.dart';

/// Repository interface for Supplier operations.
///
/// Defines the contract between the domain layer and data layer for
/// supplier CRUD operations. Returns [Either<Failure, T>] for functional
/// error handling.
abstract class SupplierRepository {
  Future<Either<Failure, List<SupplierEntity>>> getAll();
  Future<Either<Failure, SupplierEntity?>> getById(String id);
  Future<Either<Failure, SupplierEntity>> create(SupplierEntity supplier);
  Future<Either<Failure, SupplierEntity>> update(String id, Map<String, dynamic> data);
  Future<Either<Failure, void>> delete(String id);
  Future<Either<Failure, List<SupplierEntity>>> search(String query);
}
