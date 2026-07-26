import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/supplier_entity.dart';
import '../repositories/supplier_repository.dart';

/// Use case for creating a new supplier.
class CreateSupplierUseCase extends UseCase<SupplierEntity, CreateSupplierParams> {
  final SupplierRepository repository;

  CreateSupplierUseCase(this.repository);

  @override
  Future<Either<Failure, SupplierEntity>> call(CreateSupplierParams params) {
    return repository.create(params.supplier);
  }
}

class CreateSupplierParams {
  final SupplierEntity supplier;

  const CreateSupplierParams({required this.supplier});
}
