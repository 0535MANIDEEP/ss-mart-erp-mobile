import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

/// Use case for creating a new customer in the system.
///
/// Validates that the customer name is not empty before delegating to the repository.
class CreateCustomerUseCase extends UseCase<Customer, CreateCustomerParams> {
  final CustomerRepository repository;

  /// Creates an instance of [CreateCustomerUseCase].
  CreateCustomerUseCase(this.repository);

  /// Executes the customer creation with validation.
  ///
  /// Returns [ValidationFailure] if customer name is empty.
  @override
  Future<Either<Failure, Customer>> call(CreateCustomerParams params) async {
    if (params.customer.name.isEmpty) {
      return const Left(ValidationFailure(message: 'Customer name cannot be empty'));
    }
    return await repository.createCustomer(params.customer);
  }
}

/// Parameters for creating a new customer.
class CreateCustomerParams {
  /// The customer to create.
  final Customer customer;

  /// Creates [CreateCustomerParams] with the given customer.
  const CreateCustomerParams({required this.customer});
}
