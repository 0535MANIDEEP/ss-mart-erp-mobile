import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/supplier_entity.dart';
import '../repositories/supplier_repository.dart';

/// Use case for retrieving all active suppliers.
class GetSuppliersUseCase extends UseCase<List<SupplierEntity>, NoParams> {
  final SupplierRepository repository;

  GetSuppliersUseCase(this.repository);

  @override
  Future<Either<Failure, List<SupplierEntity>>> call(NoParams params) {
    return repository.getAll();
  }
}
