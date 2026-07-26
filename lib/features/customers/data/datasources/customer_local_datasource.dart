/// Customer Local Data Source — Local persistence layer for customer data.
///
/// ## Architecture Role
/// Sits between [CustomerRepositoryImpl] and the Drift database. Abstracts all
/// details of how customer rows are stored, queried, and converted to/from domain
/// entities. The repository never touches raw SQL or DAO objects.
///
/// ## Responsibilities
/// - CRUD operations on the [Customers] table.
/// - Search by name/phone and filtering by customer type (walk-in, regular, wholesale, etc.).
/// - Manages loyalty-related fields (points, card number, credit) on the customer record.
/// - Bidirectional mapping between [db.Customer] (database row) and [Customer]
///   (domain entity).
///
/// ## Data Flow
/// ```
/// Repository → CustomerLocalDataSource → DatabaseDao (Drift) → SQLite
/// ```
///
/// ## Design Decisions
/// - The DAO is instantiated once in the constructor and cached as `_dao`, unlike
///   [ProductLocalDataSourceImpl] which creates a new DAO per call. Both approaches
///   are valid; here we prioritize avoiding repeated allocation since customer
///   operations are frequent (every billing interaction).
/// - Pagination is applied in-memory after sorting by `createdAt` descending.
///   This works well for typical ERP customer counts (< 50k records). For
///   larger datasets, consider cursor-based pagination at the SQL level.
/// - The `type` filter is applied post-fetch from the DAO rather than at the SQL
///   level, because the DAO's `getActiveCustomers()` doesn't accept a type
///   parameter. This is a pragmatic trade-off to avoid modifying the DAO for a
///   rarely-used filter.
library;

import '../../../../database/app_database.dart' as db;
import '../../domain/entities/customer_entity.dart';

/// Abstract contract for local customer persistence.
///
/// The repository layer depends on this interface, not on the concrete
/// implementation, enabling unit testing with fakes/mocks.
abstract class CustomerLocalDataSource {
  /// Returns a paginated list of customers, optionally filtered by [search] query
  /// or customer [type]. Defaults to page 1 with 20 items per page.
  Future<List<Customer>> getCustomers({
    String? search,
    String? type,
    int page = 1,
    int perPage = 20,
  });

  /// Returns a single customer by its unique [id], or `null` if not found.
  Future<Customer?> getCustomerById(String id);

  /// Returns the first customer matching the given [phone] number, or `null`.
  Future<Customer?> getCustomerByPhone(String phone);

  /// Upserts a customer — inserts if new, updates if the ID already exists.
  Future<void> saveCustomer(Customer customer);

  /// Soft/hard-deletes a customer by its [id].
  Future<void> deleteCustomer(String id);
}

/// Concrete implementation backed by Drift's [AppDatabase].
///
/// Handles the mapping between the domain [Customer] entity and the Drift-generated
/// [db.Customer] row object. The companion ([db.CustomersCompanion]) is used for
/// writes, while the row object is used for reads.
class CustomerLocalDataSourceImpl implements CustomerLocalDataSource {
  final db.AppDatabase _database;
  late final db.DatabaseDao _dao;

  CustomerLocalDataSourceImpl({required db.AppDatabase database})
      : _database = database {
    // DAO is created once and reused across all methods.
    _dao = db.DatabaseDao(_database);
  }

  @override
  Future<List<Customer>> getCustomers({
    String? search,
    String? type,
    int page = 1,
    int perPage = 20,
  }) async {
    List<db.Customer> customersData;

    // Determine the base dataset: search overrides type, which overrides all.
    if (search != null && search.isNotEmpty) {
      customersData = await _dao.searchCustomers(search);
    } else if (type != null) {
      // Fetch all active customers then filter by type in memory.
      // This is a deliberate trade-off: the DAO doesn't support type filtering
      // at the SQL level, and adding it would couple the DAO to business logic.
      final all = await _dao.getActiveCustomers();
      customersData = all.where((c) => c.type == type).toList();
    } else {
      customersData = await _dao.getActiveCustomers();
    }

    // Double-check: ensure only active customers are returned even if the DAO
    // query didn't filter on `isActive` (defense-in-depth).
    customersData = customersData.where((c) => c.isActive).toList();

    // Sort newest-first so the most relevant customers appear at the top.
    customersData.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // In-memory pagination — safe for typical ERP customer counts.
    final start = (page - 1) * perPage;
    if (start >= customersData.length) return [];
    final end = start + perPage;
    final paged =
        customersData.sublist(start, end > customersData.length ? customersData.length : end);

    return paged.map((data) => _customerFromData(data)).toList();
  }

  @override
  Future<Customer?> getCustomerById(String id) async {
    final data = await _dao.getCustomerById(id);
    if (data == null) return null;
    return _customerFromData(data);
  }

  @override
  Future<Customer?> getCustomerByPhone(String phone) async {
    // Reuses the search method; the phone is typically unique enough to return
    // a single result. Taking `.first` avoids adding a dedicated DAO method for
    // a lookup that's only used in one place.
    final results = await _dao.searchCustomers(phone);
    if (results.isEmpty) return null;
    return _customerFromData(results.first);
  }

  @override
  Future<void> saveCustomer(Customer customer) async {
    // Build a full companion with all fields explicitly set.
    // Using `db.Value()` for nullable fields tells Drift to set them to NULL
    // rather than leaving them at their default (which could be a previous value
    // on update).
    final companion = db.CustomersCompanion(
      id: db.Value(customer.id),
      name: db.Value(customer.name),
      phone: db.Value(customer.phone),
      email: db.Value(customer.email),
      address: db.Value(customer.address),
      city: db.Value(customer.city),
      state: db.Value(customer.state),
      pincode: db.Value(customer.pincode),
      gstin: db.Value(customer.gstin),
      type: db.Value(customer.type),
      creditLimit: db.Value(customer.creditLimit),
      currentBalance: db.Value(customer.currentBalance),
      loyaltyPoints: db.Value(customer.loyaltyPoints),
      loyaltyCardNumber: db.Value(customer.loyaltyCardNumber),
      isActive: db.Value(customer.isActive),
      createdAt: db.Value(customer.createdAt),
      updatedAt: db.Value(customer.updatedAt),
      version: db.Value(customer.version),
    );

    await _dao.insertCustomer(companion);
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await _dao.deleteCustomer(id);
  }

  /// Converts a Drift [db.Customer] row into a domain [Customer] entity.
  ///
  /// All fields are mapped 1:1. If the database schema adds columns that the
  /// domain entity doesn't model yet, they will be silently dropped here.
  Customer _customerFromData(db.Customer data) {
    return Customer(
      id: data.id,
      name: data.name,
      phone: data.phone,
      email: data.email,
      address: data.address,
      city: data.city,
      state: data.state,
      pincode: data.pincode,
      gstin: data.gstin,
      type: data.type,
      creditLimit: data.creditLimit,
      currentBalance: data.currentBalance,
      loyaltyPoints: data.loyaltyPoints,
      loyaltyCardNumber: data.loyaltyCardNumber,
      isActive: data.isActive,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      version: data.version,
    );
  }
}
