import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../repositories/supplier_repository.dart';

/// Use case for soft-deleting a supplier.
class DeleteSupplierUseCase extends UseCase<void, DeleteSupplierParams> {
  final SupplierRepository repository;

  DeleteSupplierUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteSupplierParams params) {
    return repository.delete(params.id);
  }
}

class DeleteSupplierParams {
  final String id;

  const DeleteSupplierParams({required this.id});
}
