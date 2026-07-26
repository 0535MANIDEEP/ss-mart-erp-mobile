import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

/// Use case for retrieving a single customer by their unique identifier.
class GetCustomerByIdUseCase extends UseCase<Customer, String> {
  final CustomerRepository repository;

  /// Creates an instance of [GetCustomerByIdUseCase].
  GetCustomerByIdUseCase(this.repository);

  /// Executes the customer retrieval.
  @override
  Future<Either<Failure, Customer>> call(String id) async {
    return await repository.getCustomerById(id);
  }
}
