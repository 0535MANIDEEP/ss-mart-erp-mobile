import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

/// Use case for retrieving a customer by their phone number.
///
/// Optimized for POS quick-lookup workflow.
class GetCustomerByPhoneUseCase extends UseCase<Customer, String> {
  final CustomerRepository repository;

  /// Creates an instance of [GetCustomerByPhoneUseCase].
  GetCustomerByPhoneUseCase(this.repository);

  /// Executes the customer retrieval by phone number.
  @override
  Future<Either<Failure, Customer>> call(String phone) async {
    return await repository.getCustomerByPhone(phone);
  }
}
