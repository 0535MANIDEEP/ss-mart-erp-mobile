import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../repositories/customer_repository.dart';

/// Use case for soft-deleting a customer by marking them inactive.
class DeleteCustomerUseCase extends UseCase<void, String> {
  final CustomerRepository repository;

  /// Creates an instance of [DeleteCustomerUseCase].
  DeleteCustomerUseCase(this.repository);

  /// Executes the customer deletion.
  @override
  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteCustomer(id);
  }
}
