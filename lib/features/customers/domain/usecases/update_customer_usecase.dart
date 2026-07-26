import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

/// Use case for updating an existing customer.
class UpdateCustomerUseCase extends UseCase<Customer, Customer> {
  final CustomerRepository repository;

  /// Creates an instance of [UpdateCustomerUseCase].
  UpdateCustomerUseCase(this.repository);

  /// Executes the customer update.
  @override
  Future<Either<Failure, Customer>> call(Customer customer) async {
    return await repository.updateCustomer(customer);
  }
}
