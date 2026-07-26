import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/customer_entity.dart';

/// Abstract repository contract for customer data operations.
///
/// This interface defines the data access boundary for the customers feature.
/// Supports both B2B and B2C customer types with credit account management
/// and loyalty point integration.
///
/// All methods return [Either<Failure, T>] to enable functional error handling
/// without exceptions, following the Clean Architecture data flow convention.
abstract class CustomerRepository {
  /// Retrieves a paginated list of customers with optional filtering.
  ///
  /// [search] filters by customer name or phone number (partial match).
  /// [type] filters to 'B2B' or 'B2C' customer types.
  /// Returns a page of customers ordered by name ascending.
  Future<Either<Failure, List<Customer>>> getCustomers({
    String? search,
    String? type,
    int page = 1,
    int perPage = 20,
  });

  /// Retrieves a single customer by their unique identifier.
  Future<Either<Failure, Customer>> getCustomerById(String id);

  /// Retrieves a customer by their phone number — optimized for POS lookup.
  Future<Either<Failure, Customer>> getCustomerByPhone(String phone);

  /// Creates a new customer record. Enqueues a sync item for server upload.
  Future<Either<Failure, Customer>> createCustomer(Customer customer);

  /// Updates an existing customer record. Enqueues a sync item for server upload.
  Future<Either<Failure, Customer>> updateCustomer(Customer customer);

  /// Soft-deletes a customer by marking them inactive.
  /// Enqueues a sync item for server propagation.
  Future<Either<Failure, void>> deleteCustomer(String id);

  /// Retrieves the complete transaction history for a customer.
  /// Returns a list of maps containing bill details and loyalty transactions.
  Future<Either<Failure, List<Map<String, dynamic>>>> getCustomerHistory(String customerId);
}
