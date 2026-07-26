import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/customer_local_datasource.dart';
import '../datasources/customer_remote_datasource.dart';

/// Implementation of [CustomerRepository] following the offline-first
/// (local-first) architecture pattern.
///
/// ## Architecture & Sync Strategy
///
/// Coordinates between [CustomerLocalDataSource] (local SQLite/Drift DB)
/// and [CustomerRemoteDataSource] (REST API) for customer master data.
///
/// ### Read Pattern (Dual-Mode)
/// - **getCustomers (list)**: When online, fetches from remote and caches
///   locally; on remote failure or offline, falls back to local cache.
///   Unlike the product repository, this method returns remote data directly
///   when the remote call succeeds (rather than always reading locally).
/// - **getCustomerById / getCustomerByPhone**: Local-first with remote
///   fallback — checks local DB first, then fetches from remote if online
///   and caches the result.
///
/// ### Write Pattern (Local Write → Sync Queue → Remote)
/// - Create, update, and delete are performed locally first.
///   The [SyncRepository] handles eventual server synchronization.
///
/// ### Error Handling
/// - All methods return `Either<Failure, T>` (dartz).
/// - [Right]: success; [Left]: failure.
/// - [ServerFailure]: network or general errors.
/// - [CacheFailure]: local DB lookup miss (entity not found locally).
///
/// ### Customer Types
/// - Supports both B2C (retail) and B2B (wholesale) customer types.
/// - The [type] parameter on [getCustomers] allows filtering by customer type.
///
/// ### Relationship Between Local and Remote
/// - Remote is authoritative for server-created customers.
/// - Local is the write-through cache and primary read source for offline use.
/// - Customer history is currently served from local data only.
class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerRemoteDataSource remoteDataSource;
  final CustomerLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  CustomerRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Fetches a paginated list of customers, optionally filtered by search
  /// query and customer type (B2C/B2B).
  ///
  /// **Strategy**: Online-first with local fallback.
  /// - When online: fetches from remote, maps and caches each customer
  ///   locally, then returns the remote-sourced list.
  /// - On remote failure: falls back to local cache (graceful degradation).
  /// - When offline: reads directly from local cache.
  /// This dual approach ensures the freshest data when connected, while
  /// maintaining offline availability.
  @override
  Future<Either<Failure, List<Customer>>> getCustomers({
    String? search,
    String? type,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      if (await networkInfo.isConnected) {
        try {
          final remoteCustomers = await remoteDataSource.getCustomers(
            search: search,
            type: type,
            page: page,
            perPage: perPage,
          );
          final customers = remoteCustomers.map((c) => _mapToCustomer(c)).toList();

          for (final customer in customers) {
            await localDataSource.saveCustomer(customer);
          }

          return Right(customers);
        } catch (_) {
          final localCustomers = await localDataSource.getCustomers(
            search: search,
            page: page,
            perPage: perPage,
          );
          return Right(localCustomers);
        }
      } else {
        final localCustomers = await localDataSource.getCustomers(
          search: search,
          page: page,
          perPage: perPage,
        );
        return Right(localCustomers);
      }
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Retrieves a single customer by ID.
  ///
  /// **Strategy**: Local-first with remote fallback and cache population.
  /// Returns the local copy if available for instant response. If not found
  /// locally and online, fetches from remote, caches locally, and returns.
  @override
  Future<Either<Failure, Customer>> getCustomerById(String id) async {
    try {
      final localCustomer = await localDataSource.getCustomerById(id);
      if (localCustomer != null) {
        return Right(localCustomer);
      }

      if (await networkInfo.isConnected) {
        try {
          final remoteCustomer = await remoteDataSource.getCustomerById(id);
          final customer = _mapToCustomer(remoteCustomer);
          await localDataSource.saveCustomer(customer);
          return Right(customer);
        } catch (_) {
          return Left(ServerFailure(message: 'Customer not found'));
        }
      }

      return Left(CacheFailure(message: 'Customer not found'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Retrieves a customer by their phone number.
  ///
  /// Phone-based lookup is essential for POS quick-lookup and loyalty
  /// workflows. Follows the same local-first pattern as [getCustomerById].
  @override
  Future<Either<Failure, Customer>> getCustomerByPhone(String phone) async {
    try {
      final localCustomer = await localDataSource.getCustomerByPhone(phone);
      if (localCustomer != null) {
        return Right(localCustomer);
      }

      if (await networkInfo.isConnected) {
        try {
          final remoteCustomer = await remoteDataSource.getCustomerByPhone(phone);
          final customer = _mapToCustomer(remoteCustomer);
          await localDataSource.saveCustomer(customer);
          return Right(customer);
        } catch (_) {
          return Left(ServerFailure(message: 'Customer not found'));
        }
      }

      return Left(CacheFailure(message: 'Customer not found'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Creates a new customer in the local database.
  ///
  /// **Strategy**: Local write only. The sync worker propagates to remote.
  @override
  Future<Either<Failure, Customer>> createCustomer(Customer customer) async {
    try {
      await localDataSource.saveCustomer(customer);
      return Right(customer);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Updates an existing customer in the local database (upsert).
  @override
  Future<Either<Failure, Customer>> updateCustomer(Customer customer) async {
    try {
      await localDataSource.saveCustomer(customer);
      return Right(customer);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Deletes a customer from the local database.
  ///
  /// Note: Performs a local-only delete. The sync worker will propagate
  /// this deletion to the remote server.
  @override
  Future<Either<Failure, void>> deleteCustomer(String id) async {
    try {
      await localDataSource.deleteCustomer(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Returns a simplified purchase/transaction history for a customer.
  ///
  /// Currently serves basic customer info from the local DB. In a full
  /// implementation, this would aggregate bill/purchase history for the
  /// customer across billing and purchase modules.
  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getCustomerHistory(String customerId) async {
    try {
      final localCustomer = await localDataSource.getCustomerById(customerId);
      if (localCustomer != null) {
        return Right([{
          'id': localCustomer.id,
          'name': localCustomer.name,
          'phone': localCustomer.phone,
        }]);
      }
      return const Right([]);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Converts a raw JSON map (from remote API or local DB) into a [Customer]
  /// domain entity. Handles null-safety and type coercion defensively.
  Customer _mapToCustomer(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      city: map['city'],
      state: map['state'],
      pincode: map['pincode'],
      gstin: map['gstin'],
      type: map['type'] ?? 'B2C',
      creditLimit: map['creditLimit'] ?? 0,
      currentBalance: map['currentBalance'] ?? 0,
      loyaltyPoints: map['loyaltyPoints'] ?? 0,
      loyaltyCardNumber: map['loyaltyCardNumber'],
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt']
          : DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: map['updatedAt'] is DateTime
          ? map['updatedAt']
          : DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      version: map['version'] ?? 1,
    );
  }
}
