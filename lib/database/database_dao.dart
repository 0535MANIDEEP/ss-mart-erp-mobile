/// Data Access Object (DAO) layer for the SS Mart ERP application.
///
/// This file consolidates all database read/write operations into a single
/// [DatabaseDao] class. It follows the DAO pattern provided by Drift:
/// a dedicated class that encapsulates query logic, keeping the database
/// schema (tables) separate from business logic (repositories/services).
///
/// ## Design Decisions
///
/// - **Single DAO for all tables**: Given the app's moderate schema size,
///   one monolithic DAO is simpler than splitting into per-table DAOs.
///   The methods are grouped by domain (see section headers below).
/// - **InsertMode.insertOrReplace**: Most insert methods use this mode
///   instead of a plain insert. This means if a row with the same primary
///   key already exists, it is silently replaced. This is intentional for
///   the offline-first sync engine: when the server pushes a downsync of
///   an entity that already exists locally, we just overwrite it rather
///   than failing with a unique constraint violation. It also simplifies
///   retry logic — retrying a failed insert never causes duplicate errors.
/// - **Custom SQL for aggregation queries**: Methods like
///   [getDaySalesTotal] and [getCustomerLoyaltyPoints] use raw SQL via
///   `customSelect` for performance and clarity, since Drift's query
///   builder would be more verbose for aggregate math.
/// - **Soft deletes are NOT used**: Entities are hard-deleted locally.
///   The sync engine queues a 'delete' operation in [SyncQueue] so the
///   server can propagate the deletion to other devices.
///
/// ## Usage
///
/// Inject [DatabaseDao] into repository or service classes:
/// ```dart
/// final dao = DatabaseDao(AppDatabase());
/// final products = await dao.getAllProducts();
/// ```
library;

import 'package:drift/drift.dart';
import 'app_database.dart';

part 'database_dao.g.dart';

/// Drift accessor that provides all data access methods.
///
/// Extends [DatabaseAccessor] to get access to the table references
/// (e.g., [products], [customers], [bills]) and uses the generated
/// mixin for type-safe query construction.
@DriftAccessor(tables: [
  Products,
  Customers,
  Bills,
  BillItems,
  Stock,
  LoyaltyTransactions,
  Employees,
  Attendance,
  Suppliers,
  Purchases,
  PurchaseItems,
  SyncQueue,
  AuditLogs,
  AuthSessions,
  UserProfiles,
  AppSettings,
  BusinessProfiles,
  ImportLogs,
  Categories,
  Shifts,
  ShiftSchedules,
  CustomerGroups,
  CustomerGroupMembers,
  CustomerTags,
  CustomerTagMembers,
  CommunicationHistory,
  PhysicalCounts,
  PhysicalCountItems,
  StockAuditTrail,
  LoyaltyCards,
  NumberingConfig,
  ProductImages,
  ProductRates,
  PartyRates,
  DiscountRules,
  SchemeRules,
  BundlePacks,
  BundlePackItems,
  InvoiceFormats,
  BarcodeLabelTemplates,
  Challans,
  ChallanItems,
  SalesOrders,
  SalesOrderItems,
  PurchaseOrders,
  PurchaseOrderItems,
  PurchaseDealHistory,
])
class DatabaseDao extends DatabaseAccessor<AppDatabase>
    with _$DatabaseDaoMixin {
  DatabaseDao(AppDatabase db) : super(db);

  // ---------------------------------------------------------------------------
  // Products
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a product. Uses [InsertMode.insertOrReplace] so
  /// that syncing from the server can safely overwrite local data without
  /// unique constraint violations.
  Future<int> insertProduct(ProductsCompanion entry) =>
      into(products).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates an existing product row. Returns true if the row existed.
  Future<bool> updateProduct(ProductsCompanion entry) =>
      update(products).replace(entry);

  /// Hard-deletes a product by its UUID. The deletion is queued in SyncQueue
  /// for server propagation — no soft-delete is used.
  Future<int> deleteProduct(String id) =>
      (delete(products)..where((t) => t.id.equals(id))).go();

  /// Fetches a single product by primary key, or null if not found.
  Future<Product?> getProductById(String id) =>
      (select(products)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Fetches a single product by its barcode, or null if not found.
  /// Used by the POS scanner input handler.
  Future<Product?> getProductByBarcode(String barcode) =>
      (select(products)..where((t) => t.barcode.equals(barcode))).getSingleOrNull();

  /// Returns all products (active and inactive). Use [getActiveProducts]
  /// for POS-facing lists.
  Future<List<Product>> getAllProducts() => select(products).get();

  /// Fuzzy-searches products by name, barcode, SKU, or HSN code using
  /// SQL LIKE with wildcards on both sides. Results are capped at [limit].
  Future<List<Product>> searchProducts(String query, {int limit = 50}) {
    final q = '%$query%';
    return (select(products)
          ..where((t) =>
              t.name.like(q) |
              t.barcode.like(q) |
              t.sku.like(q) |
              t.hsnCode.like(q))
          ..limit(limit))
        .get();
  }

  /// Returns all products belonging to a specific category.
  Future<List<Product>> getProductsByCategory(String categoryId) =>
      (select(products)..where((t) => t.categoryId.equals(categoryId))).get();

  /// Returns only active products (isActive = true). This is the primary
  /// method for populating product selection lists in the POS UI.
  Future<List<Product>> getActiveProducts() =>
      (select(products)..where((t) => t.isActive.equals(true))).get();

  /// Directly overwrites the [currentStock] column for a product.
  /// Note: the canonical per-location stock lives in the [Stock] table;
  /// this denormalized update keeps the product row in sync.
  Future<int> updateProductStock(String productId, int newStock) =>
      (update(products)..where((t) => t.id.equals(productId)))
          .write(ProductsCompanion(currentStock: Value(newStock)));

  /// Returns the total count of all products (including inactive).
  Future<int> getProductsCount() =>
      customSelect('SELECT COUNT(*) as c FROM products', readsFrom: {products})
          .getSingle()
          .then((r) => r.data['c'] as int);

  // ---------------------------------------------------------------------------
  // Customers
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a customer record.
  Future<int> insertCustomer(CustomersCompanion entry) =>
      into(customers).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates an existing customer. Returns true if the row existed.
  Future<bool> updateCustomer(CustomersCompanion entry) =>
      update(customers).replace(entry);

  /// Hard-deletes a customer by UUID.
  Future<int> deleteCustomer(String id) =>
      (delete(customers)..where((t) => t.id.equals(id))).go();

  /// Fetches a single customer by primary key, or null.
  Future<Customer?> getCustomerById(String id) =>
      (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Returns all customers (active and inactive).
  Future<List<Customer>> getAllCustomers() => select(customers).get();

  /// Searches customers by name or phone number. Results capped at [limit].
  Future<List<Customer>> searchCustomers(String query, {int limit = 50}) {
    final q = '%$query%';
    return (select(customers)
          ..where((t) => t.name.like(q) | t.phone.like(q))
          ..limit(limit))
        .get();
  }

  /// Returns only active customers for selection dropdowns.
  Future<List<Customer>> getActiveCustomers() =>
      (select(customers)..where((t) => t.isActive.equals(true))).get();

  /// Overwrites the loyalty points balance for a customer.
  /// Typically called after earning or redeeming points via
  /// [LoyaltyTransactions].
  Future<int> updateCustomerLoyaltyPoints(String customerId, int points) =>
      (update(customers)..where((t) => t.id.equals(customerId)))
          .write(CustomersCompanion(loyaltyPoints: Value(points)));

  /// Overwrites the credit balance for a customer.
  /// Positive values mean the customer owes money; zero means settled.
  Future<int> updateCustomerBalance(String customerId, int balance) =>
      (update(customers)..where((t) => t.id.equals(customerId)))
          .write(CustomersCompanion(currentBalance: Value(balance)));

  // ---------------------------------------------------------------------------
  // Bills (Sales Invoices)
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a sales bill header.
  Future<int> insertBill(BillsCompanion entry) =>
      into(bills).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates an existing bill. Returns true if the row existed.
  Future<bool> updateBill(BillsCompanion entry) =>
      update(bills).replace(entry);

  /// Hard-deletes a bill by UUID.
  Future<int> deleteBill(String id) =>
      (delete(bills)..where((t) => t.id.equals(id))).go();

  /// Fetches a single bill by primary key, or null.
  Future<Bill?> getBillById(String id) =>
      (select(bills)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Returns all bills (completed, pending, cancelled, and returns).
  Future<List<Bill>> getAllBills() => select(bills).get();

  /// Returns the most recent bills ordered by creation time descending.
  /// Used on the dashboard / home screen.
  Future<List<Bill>> getRecentBills({int limit = 10}) =>
      (select(bills)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();

  /// Returns all bills for a specific customer.
  Future<List<Bill>> getBillsByCustomer(String customerId) =>
      (select(bills)..where((t) => t.customerId.equals(customerId))).get();

  /// Returns bills within a date range [start] to [end] (inclusive on both
  /// ends). Used for daily/weekly/monthly sales reports.
  Future<List<Bill>> getBillsByDateRange(DateTime start, DateTime end) =>
      (select(bills)
            ..where((t) =>
                t.billDate.isBiggerOrEqualValue(start) &
                t.billDate.isSmallerOrEqualValue(end)))
          .get();

  /// Returns bills filtered by status ('completed', 'pending', 'cancelled').
  Future<List<Bill>> getBillsByStatus(String status) =>
      (select(bills)..where((t) => t.status.equals(status))).get();

  /// Computes the total sales revenue for a given calendar day.
  ///
  /// This query:
  /// 1. Calculates start-of-day and end-of-day boundaries from [date].
  /// 2. Sums [Bills.totalAmount] for all non-return, completed bills
  ///    within that window.
  /// 3. Returns 0 (via COALESCE) if no sales exist for the day.
  ///
  /// Returns the amount in integer paise (divide by 100 for display).
  Future<int> getDaySalesTotal(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final result = await customSelect(
      'SELECT COALESCE(SUM(total_amount), 0) as total FROM bills WHERE bill_date >= ? AND bill_date < ? AND is_return = 0 AND status = ?',
      variables: [
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
        Variable.withString('completed'),
      ],
      readsFrom: {bills},
    ).getSingle();
    return result.data['total'] as int;
  }

  /// Counts the total number of bills created on a given calendar day.
  ///
  /// Uses the same start/end-of-day boundary logic as [getDaySalesTotal].
  /// This counts ALL bills regardless of status (completed, pending, etc.).
  Future<int> getBillCountForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final result = await customSelect(
      'SELECT COUNT(*) as c FROM bills WHERE bill_date >= ? AND bill_date < ?',
      variables: [
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
      ],
      readsFrom: {bills},
    ).getSingle();
    return result.data['c'] as int;
  }

  /// Updates only the status field of a bill (e.g., 'completed' → 'cancelled').
  Future<int> updateBillStatus(String billId, String status) =>
      (update(bills)..where((t) => t.id.equals(billId)))
          .write(BillsCompanion(status: Value(status)));

  /// Updates only the sync status field of a bill ('pending' → 'in_sync').
  Future<int> updateBillSyncStatus(String billId, String syncStatus) =>
      (update(bills)..where((t) => t.id.equals(billId)))
          .write(BillsCompanion(syncStatus: Value(syncStatus)));

  // ---------------------------------------------------------------------------
  // Bill Items (Line Items)
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a bill line item.
  Future<int> insertBillItem(BillItemsCompanion entry) =>
      into(billItems).insert(entry, mode: InsertMode.insertOrReplace);

  /// Returns all line items for a given bill, ordered by insertion.
  Future<List<BillItem>> getBillItemsByBillId(String billId) =>
      (select(billItems)..where((t) => t.billId.equals(billId))).get();

  /// Deletes all line items for a bill (used before re-inserting updated items
  /// or when the bill itself is deleted).
  Future<int> deleteBillItemsByBillId(String billId) =>
      (delete(billItems)..where((t) => t.billId.equals(billId))).go();

  // ---------------------------------------------------------------------------
  // Stock (Per-Location Inventory)
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a stock record.
  Future<int> insertStock(StockCompanion entry) =>
      into(stock).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates an existing stock record. Returns true if the row existed.
  Future<bool> updateStock(StockCompanion entry) =>
      update(stock).replace(entry);

  /// Hard-deletes a stock record by UUID.
  Future<int> deleteStock(String id) =>
      (delete(stock)..where((t) => t.id.equals(id))).go();

  /// Returns the stock record for a product (at its default location), or null.
  Future<StockData?> getStockByProductId(String productId) =>
      (select(stock)..where((t) => t.productId.equals(productId)))
          .getSingleOrNull();

  /// Returns all stock records across all products and locations.
  Future<List<StockData>> getAllStock() => select(stock).get();

  /// Returns all stock records for a specific warehouse/store location.
  Future<List<StockData>> getStockByLocation(String locationId) =>
      (select(stock)..where((t) => t.locationId.equals(locationId))).get();

  // ---------------------------------------------------------------------------
  // Loyalty Transactions
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a loyalty transaction (earn or redeem event).
  Future<int> insertLoyaltyTransaction(LoyaltyTransactionsCompanion entry) =>
      into(loyaltyTransactions).insert(entry, mode: InsertMode.insertOrReplace);

  /// Returns all loyalty transactions for a customer, most recent first.
  /// Used to display the points history / ledger in the customer detail screen.
  Future<List<LoyaltyTransaction>> getLoyaltyTransactionsByCustomer(
          String customerId) =>
      (select(loyaltyTransactions)
            ..where((t) => t.customerId.equals(customerId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Returns all loyalty transactions, most recent first.
  Future<List<LoyaltyTransaction>> getAllLoyaltyTransactions() =>
      (select(loyaltyTransactions)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Computes the net available loyalty points for a customer.
  ///
  /// This executes two separate aggregate queries:
  /// 1. SUM of all 'earn' transactions for the customer.
  /// 2. SUM of all 'redeem' transactions for the customer.
  /// Returns: earned_points - redeemed_points.
  ///
  /// The result is the customer's current spendable loyalty balance.
  /// This is intentionally computed from the ledger rather than reading
  /// the denormalized [Customers.loyaltyPoints] column, providing an
  /// authoritative cross-check.
  Future<int> getCustomerLoyaltyPoints(String customerId) async {
    final earnResult = await customSelect(
      'SELECT COALESCE(SUM(points), 0) as total FROM loyalty_transactions WHERE customer_id = ? AND transaction_type = ?',
      variables: [
        Variable.withString(customerId),
        Variable.withString('earn'),
      ],
      readsFrom: {loyaltyTransactions},
    ).getSingle();
    final redeemResult = await customSelect(
      'SELECT COALESCE(SUM(points), 0) as total FROM loyalty_transactions WHERE customer_id = ? AND transaction_type = ?',
      variables: [
        Variable.withString(customerId),
        Variable.withString('redeem'),
      ],
      readsFrom: {loyaltyTransactions},
    ).getSingle();
    return (earnResult.data['total'] as int) -
        (redeemResult.data['total'] as int);
  }

  // ---------------------------------------------------------------------------
  // Employees
  // ---------------------------------------------------------------------------

  /// Inserts or replaces an employee record.
  Future<int> insertEmployee(EmployeesCompanion entry) =>
      into(employees).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates an existing employee. Returns true if the row existed.
  Future<bool> updateEmployee(EmployeesCompanion entry) =>
      update(employees).replace(entry);

  /// Hard-deletes an employee by UUID.
  Future<int> deleteEmployee(String id) =>
      (delete(employees)..where((t) => t.id.equals(id))).go();

  /// Fetches a single employee by primary key, or null.
  Future<Employee?> getEmployeeById(String id) =>
      (select(employees)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Returns all employees (active and inactive).
  Future<List<Employee>> getAllEmployees() => select(employees).get();

  /// Returns only active employees for dropdowns and PIN-login screens.
  Future<List<Employee>> getActiveEmployees() =>
      (select(employees)..where((t) => t.isActive.equals(true))).get();

  // ---------------------------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------------------------

  /// Inserts or replaces an attendance record.
  Future<int> insertAttendance(AttendanceCompanion entry) =>
      into(attendance).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates an existing attendance record (e.g., to add clock-out time).
  Future<bool> updateAttendance(AttendanceCompanion entry) =>
      update(attendance).replace(entry);

  /// Returns attendance records for a specific employee on a specific date.
  /// Typically returns 0 or 1 rows; the list API allows for edge cases
  /// where duplicate entries might exist.
  Future<List<AttendanceData>> getAttendanceByEmployee(
          String employeeId, DateTime date) =>
      (select(attendance)
            ..where((t) =>
                t.employeeId.equals(employeeId) &
                t.attendanceDate.equals(date)))
          .get();

  /// Returns all attendance records for a given date across all employees.
  /// Used by the manager's daily attendance summary screen.
  Future<List<AttendanceData>> getAttendanceByDate(DateTime date) =>
      (select(attendance)..where((t) => t.attendanceDate.equals(date))).get();

  // ---------------------------------------------------------------------------
  // Suppliers
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a supplier record.
  Future<int> insertSupplier(SuppliersCompanion entry) =>
      into(suppliers).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates an existing supplier. Returns true if the row existed.
  Future<bool> updateSupplier(SuppliersCompanion entry) =>
      update(suppliers).replace(entry);

  /// Hard-deletes a supplier by UUID.
  Future<int> deleteSupplier(String id) =>
      (delete(suppliers)..where((t) => t.id.equals(id))).go();

  /// Fetches a single supplier by primary key, or null.
  Future<Supplier?> getSupplierById(String id) =>
      (select(suppliers)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Returns all suppliers (active and inactive).
  Future<List<Supplier>> getAllSuppliers() => select(suppliers).get();

  // ---------------------------------------------------------------------------
  // Purchases (Supplier Orders)
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a purchase order header.
  Future<int> insertPurchase(PurchasesCompanion entry) =>
      into(purchases).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates an existing purchase order. Returns true if the row existed.
  Future<bool> updatePurchase(PurchasesCompanion entry) =>
      update(purchases).replace(entry);

  /// Fetches a single purchase order by primary key, or null.
  Future<Purchase?> getPurchaseById(String id) =>
      (select(purchases)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Returns all purchase orders.
  Future<List<Purchase>> getAllPurchases() => select(purchases).get();

  /// Returns the most recent purchase orders ordered by creation time descending.
  Future<List<Purchase>> getRecentPurchases({int limit = 10}) =>
      (select(purchases)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();

  // ---------------------------------------------------------------------------
  // Purchase Items (Line Items)
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a purchase order line item.
  Future<int> insertPurchaseItem(PurchaseItemsCompanion entry) =>
      into(purchaseItems).insert(entry, mode: InsertMode.insertOrReplace);

  /// Returns all line items for a given purchase order.
  Future<List<PurchaseItem>> getPurchaseItemsByPurchaseId(String purchaseId) =>
      (select(purchaseItems)..where((t) => t.purchaseId.equals(purchaseId)))
          .get();

  /// Deletes all line items for a purchase order (used before re-inserting
  /// or when the purchase order itself is deleted).
  Future<int> deletePurchaseItemsByPurchaseId(String purchaseId) =>
      (delete(purchaseItems)..where((t) => t.purchaseId.equals(purchaseId)))
          .go();

  // ---------------------------------------------------------------------------
  // Sync Queue
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a sync queue item. This is called by the local
  /// mutation interceptor whenever a create/update/delete occurs on any
  /// mutable entity.
  Future<int> insertSyncItem(SyncQueueCompanion entry) =>
      into(syncQueue).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates a sync queue item (typically to change status from 'pending'
  /// to 'syncing' or 'completed').
  Future<bool> updateSyncItem(SyncQueueCompanion entry) =>
      update(syncQueue).replace(entry);

  /// Removes a sync queue item (called after successful server sync or
  /// when max retries are exhausted and the item is discarded).
  Future<int> deleteSyncItem(String id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();

  /// Fetches a single sync queue item by primary key, or null.
  Future<SyncQueueData?> getSyncItemById(String id) =>
      (select(syncQueue)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Returns all pending sync items in FIFO order (oldest first).
  /// The sync engine processes these sequentially to maintain causality.
  Future<List<SyncQueueData>> getPendingSyncItems() =>
      (select(syncQueue)
            ..where((t) => t.status.equals('pending'))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// Returns all sync queue items regardless of status (for debugging).
  Future<List<SyncQueueData>> getAllSyncItems() => select(syncQueue).get();

  // ---------------------------------------------------------------------------
  // Audit Logs
  // ---------------------------------------------------------------------------

  /// Appends an audit log entry. This is an insert-only operation — audit
  /// logs are immutable and never updated or deleted.
  Future<int> insertAuditLog(AuditLogsCompanion entry) =>
      into(auditLogs).insert(entry);

  // ---------------------------------------------------------------------------
  // Auth Sessions
  // ---------------------------------------------------------------------------

  /// Inserts or replaces an authentication session (JWT token pair).
  Future<int> insertAuthSession(AuthSessionsCompanion entry) =>
      into(authSessions).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates an existing auth session (e.g., after token refresh).
  Future<bool> updateAuthSession(AuthSessionsCompanion entry) =>
      update(authSessions).replace(entry);

  /// Deletes a specific auth session by UUID (logout).
  Future<int> deleteAuthSession(String id) =>
      (delete(authSessions)..where((t) => t.id.equals(id))).go();

  /// Fetches a single auth session by primary key, or null.
  Future<AuthSession?> getAuthSessionById(String id) =>
      (select(authSessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Returns the currently active session, or null if no session exists.
  /// The app checks this on startup to determine if re-login is needed.
  Future<AuthSession?> getActiveSession() =>
      (select(authSessions)..where((t) => t.status.equals('active')))
          .getSingleOrNull();

  /// Returns all auth sessions (for session management UI).
  Future<List<AuthSession>> getAllAuthSessions() => select(authSessions).get();

  /// Sets all active sessions to 'inactive'. Called on logout, password
  /// change, or when the server invalidates all tokens.
  Future<int> deactivateAllSessions() =>
      (update(authSessions)..where((t) => t.status.equals('active')))
          .write(AuthSessionsCompanion(status: Value('inactive')));

  // ---------------------------------------------------------------------------
  // User Profiles
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a user profile (typically from server sync).
  Future<int> insertUserProfile(UserProfilesCompanion entry) =>
      into(userProfiles).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates an existing user profile. Returns true if the row existed.
  Future<bool> updateUserProfile(UserProfilesCompanion entry) =>
      update(userProfiles).replace(entry);

  /// Hard-deletes a user profile by UUID.
  Future<int> deleteUserProfile(String id) =>
      (delete(userProfiles)..where((t) => t.id.equals(id))).go();

  /// Fetches a single user profile by primary key, or null.
  Future<UserProfile?> getUserProfileById(String id) =>
      (select(userProfiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Returns all user profiles (for admin user management screens).
  Future<List<UserProfile>> getAllUserProfiles() => select(userProfiles).get();

  // ---------------------------------------------------------------------------
  // App Settings
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a key-value setting. Uses insertOrReplace so that
  /// calling this method is always safe regardless of whether the key exists.
  Future<int> insertOrUpdateSetting(AppSettingsCompanion entry) =>
      into(appSettings).insert(entry, mode: InsertMode.insertOrReplace);

  /// Returns the value for a setting key, or null if not found.
  Future<String?> getSettingValue(String key) async {
    final result = await (select(appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return result?.value;
  }

  /// Returns all settings as a list.
  Future<List<AppSetting>> getAllSettings() => select(appSettings).get();

  /// Deletes a setting by key.
  Future<int> deleteSetting(String key) =>
      (delete(appSettings)..where((t) => t.key.equals(key))).go();

  /// Returns all settings as a key-value map. Useful for bulk-loading
  /// configuration at app startup.
  Future<Map<String, String>> getSettingsAsMap() async {
    final settings = await select(appSettings).get();
    return {for (var s in settings) s.key: s.value};
  }

  // ---------------------------------------------------------------------------
  // Business Profiles
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a business entity profile.
  Future<int> insertBusinessProfile(BusinessProfilesCompanion entry) =>
      into(businessProfiles).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates an existing business profile. Returns true if the row existed.
  Future<bool> updateBusinessProfile(BusinessProfilesCompanion entry) =>
      update(businessProfiles).replace(entry);

  /// Hard-deletes a business profile by UUID.
  Future<int> deleteBusinessProfile(String id) =>
      (delete(businessProfiles)..where((t) => t.id.equals(id))).go();

  /// Fetches a single business profile by primary key, or null.
  Future<BusinessProfile?> getBusinessProfileById(String id) =>
      (select(businessProfiles)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Returns the currently active business profile (used for invoice headers
  /// and GST filing). Returns null if no profile is configured.
  Future<BusinessProfile?> getActiveBusinessProfile() =>
      (select(businessProfiles)..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  /// Returns all business profiles (for multi-business switching in settings).
  Future<List<BusinessProfile>> getAllBusinessProfiles() =>
      select(businessProfiles).get();

  // ---------------------------------------------------------------------------
  // Import Logs
  // ---------------------------------------------------------------------------

  /// Inserts or replaces an import log entry. Called when a bulk import
  /// job starts or completes.
  Future<int> insertImportLog(ImportLogsCompanion entry) =>
      into(importLogs).insert(entry, mode: InsertMode.insertOrReplace);

  /// Updates an import log (e.g., to set [completedAt] and [canRollback]).
  Future<bool> updateImportLog(ImportLogsCompanion entry) =>
      update(importLogs).replace(entry);

  /// Hard-deletes an import log by UUID.
  Future<int> deleteImportLog(String id) =>
      (delete(importLogs)..where((t) => t.id.equals(id))).go();

  /// Fetches a single import log by primary key, or null.
  Future<ImportLog?> getImportLogById(String id) =>
      (select(importLogs)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Returns import logs filtered by entity type (e.g., 'products',
  /// 'customers'), most recent first.
  Future<List<ImportLog>> getImportLogsByEntityType(String entityType) =>
      (select(importLogs)
            ..where((t) => t.entityType.equals(entityType))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Returns the most recent import logs, capped at [limit].
  Future<List<ImportLog>> getAllImportLogs({int limit = 50}) =>
      (select(importLogs)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  Future<int> insertCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateCategory(CategoriesCompanion entry) =>
      update(categories).replace(entry);

  Future<int> deleteCategory(String id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();

  Future<Category?> getCategoryById(String id) =>
      (select(categories)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Category>> getAllCategories() =>
      (select(categories)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  Future<List<Category>> getActiveCategories() =>
      (select(categories)..where((t) => t.isActive.equals(true))..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  Future<List<Category>> searchCategories(String query) =>
      (select(categories)..where((t) => t.name.like('%$query%'))).get();

  // ---------------------------------------------------------------------------
  // Shifts
  // ---------------------------------------------------------------------------

  Future<int> insertShift(ShiftsCompanion entry) =>
      into(shifts).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateShift(ShiftsCompanion entry) =>
      update(shifts).replace(entry);

  Future<int> deleteShift(String id) =>
      (delete(shifts)..where((t) => t.id.equals(id))).go();

  Future<Shift?> getShiftById(String id) =>
      (select(shifts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Shift>> getAllShifts() =>
      (select(shifts)..where((t) => t.isActive.equals(true))).get();

  // ---------------------------------------------------------------------------
  // ShiftSchedules
  // ---------------------------------------------------------------------------

  Future<int> insertShiftSchedule(ShiftSchedulesCompanion entry) =>
      into(shiftSchedules).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateShiftSchedule(ShiftSchedulesCompanion entry) =>
      update(shiftSchedules).replace(entry);

  Future<int> deleteShiftSchedule(String id) =>
      (delete(shiftSchedules)..where((t) => t.id.equals(id))).go();

  Future<List<ShiftSchedule>> getShiftSchedulesByDate(DateTime date) =>
      (select(shiftSchedules)..where((t) => t.scheduleDate.equals(date))).get();

  Future<List<ShiftSchedule>> getShiftSchedulesByEmployee(String employeeId) =>
      (select(shiftSchedules)..where((t) => t.employeeId.equals(employeeId))).get();

  Future<List<ShiftSchedule>> getShiftSchedulesByDateRange(DateTime start, DateTime end) =>
      (select(shiftSchedules)..where((t) => t.scheduleDate.isBetweenValues(start, end))).get();

  // ---------------------------------------------------------------------------
  // CustomerGroups
  // ---------------------------------------------------------------------------

  Future<int> insertCustomerGroup(CustomerGroupsCompanion entry) =>
      into(customerGroups).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateCustomerGroup(CustomerGroupsCompanion entry) =>
      update(customerGroups).replace(entry);

  Future<int> deleteCustomerGroup(String id) =>
      (delete(customerGroups)..where((t) => t.id.equals(id))).go();

  Future<CustomerGroup?> getCustomerGroupById(String id) =>
      (select(customerGroups)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<CustomerGroup>> getAllCustomerGroups() =>
      (select(customerGroups)..where((t) => t.isActive.equals(true))).get();

  // CustomerGroupMembers

  Future<int> insertCustomerGroupMember(CustomerGroupMembersCompanion entry) =>
      into(customerGroupMembers).insert(entry, mode: InsertMode.insertOrReplace);

  Future<int> deleteCustomerGroupMember(String customerId, String groupId) =>
      (delete(customerGroupMembers)
            ..where((t) => t.customerId.equals(customerId))
            ..where((t) => t.groupId.equals(groupId)))
          .go();

  Future<List<CustomerGroupMember>> getCustomerGroupMembers(String groupId) =>
      (select(customerGroupMembers)..where((t) => t.groupId.equals(groupId))).get();

  Future<List<String>> getCustomerGroupIds(String customerId) =>
      (select(customerGroupMembers)..where((t) => t.customerId.equals(customerId)))
          .map((t) => t.groupId)
          .get();

  // ---------------------------------------------------------------------------
  // CustomerTags
  // ---------------------------------------------------------------------------

  Future<int> insertCustomerTag(CustomerTagsCompanion entry) =>
      into(customerTags).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateCustomerTag(CustomerTagsCompanion entry) =>
      update(customerTags).replace(entry);

  Future<int> deleteCustomerTag(String id) =>
      (delete(customerTags)..where((t) => t.id.equals(id))).go();

  Future<List<CustomerTag>> getAllCustomerTags() =>
      select(customerTags).get();

  // CustomerTagMembers

  Future<int> insertCustomerTagMember(CustomerTagMembersCompanion entry) =>
      into(customerTagMembers).insert(entry, mode: InsertMode.insertOrReplace);

  Future<int> deleteCustomerTagMember(String customerId, String tagId) =>
      (delete(customerTagMembers)
            ..where((t) => t.customerId.equals(customerId))
            ..where((t) => t.tagId.equals(tagId)))
          .go();

  Future<List<String>> getCustomerTagIds(String customerId) =>
      (select(customerTagMembers)..where((t) => t.customerId.equals(customerId)))
          .map((t) => t.tagId)
          .get();

  // ---------------------------------------------------------------------------
  // CommunicationHistory
  // ---------------------------------------------------------------------------

  Future<int> insertCommunication(CommunicationHistoryCompanion entry) =>
      into(communicationHistory).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<CommunicationHistoryData>> getCommunicationsByCustomer(String customerId) =>
      (select(communicationHistory)
            ..where((t) => t.customerId.equals(customerId))
            ..orderBy([(t) => OrderingTerm.desc(t.communicationDate)]))
          .get();

  Future<List<CommunicationHistoryData>> getAllCommunications() =>
      (select(communicationHistory)
            ..orderBy([(t) => OrderingTerm.desc(t.communicationDate)]))
          .get();

  // ---------------------------------------------------------------------------
  // PhysicalCounts
  // ---------------------------------------------------------------------------

  Future<int> insertPhysicalCount(PhysicalCountsCompanion entry) =>
      into(physicalCounts).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updatePhysicalCount(PhysicalCountsCompanion entry) =>
      update(physicalCounts).replace(entry);

  Future<int> deletePhysicalCount(String id) =>
      (delete(physicalCounts)..where((t) => t.id.equals(id))).go();

  Future<PhysicalCount?> getPhysicalCountById(String id) =>
      (select(physicalCounts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<PhysicalCount>> getAllPhysicalCounts() =>
      (select(physicalCounts)..orderBy([(t) => OrderingTerm.desc(t.countDate)])).get();

  // PhysicalCountItems

  Future<int> insertPhysicalCountItem(PhysicalCountItemsCompanion entry) =>
      into(physicalCountItems).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<PhysicalCountItem>> getPhysicalCountItems(String physicalCountId) =>
      (select(physicalCountItems)..where((t) => t.physicalCountId.equals(physicalCountId))).get();

  // ---------------------------------------------------------------------------
  // StockAuditTrail
  // ---------------------------------------------------------------------------

  Future<int> insertStockAuditEntry(StockAuditTrailCompanion entry) =>
      into(stockAuditTrail).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<StockAuditTrailData>> getStockAuditByProduct(String productId) =>
      (select(stockAuditTrail)
            ..where((t) => t.productId.equals(productId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<List<StockAuditTrailData>> getAllStockAuditTrail() =>
      (select(stockAuditTrail)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  // ---------------------------------------------------------------------------
  // LoyaltyCards
  // ---------------------------------------------------------------------------

  Future<int> insertLoyaltyCard(LoyaltyCardsCompanion entry) =>
      into(loyaltyCards).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateLoyaltyCard(LoyaltyCardsCompanion entry) =>
      update(loyaltyCards).replace(entry);

  Future<int> deleteLoyaltyCard(String id) =>
      (delete(loyaltyCards)..where((t) => t.id.equals(id))).go();

  Future<LoyaltyCard?> getLoyaltyCardById(String id) =>
      (select(loyaltyCards)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<LoyaltyCard?> getLoyaltyCardByNumber(String cardNumber) =>
      (select(loyaltyCards)..where((t) => t.cardNumber.equals(cardNumber))).getSingleOrNull();

  Future<List<LoyaltyCard>> getAllLoyaltyCards() =>
      select(loyaltyCards).get();

  Future<List<LoyaltyCard>> getLoyaltyCardsByCustomer(String customerId) =>
      (select(loyaltyCards)..where((t) => t.customerId.equals(customerId))).get();

  // ---------------------------------------------------------------------------
  // NumberingConfig
  // ---------------------------------------------------------------------------

  Future<int> insertNumberingConfig(NumberingConfigCompanion entry) =>
      into(numberingConfig).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateNumberingConfig(NumberingConfigCompanion entry) =>
      update(numberingConfig).replace(entry);

  Future<NumberingConfigData?> getNumberingConfig(String documentType) =>
      (select(numberingConfig)..where((t) => t.documentType.equals(documentType))).getSingleOrNull();

  Future<List<NumberingConfigData>> getAllNumberingConfigs() =>
      select(numberingConfig).get();

  // ---------------------------------------------------------------------------
  // ProductImages
  // ---------------------------------------------------------------------------

  Future<int> insertProductImage(ProductImagesCompanion entry) =>
      into(productImages).insert(entry, mode: InsertMode.insertOrReplace);

  Future<int> deleteProductImage(String id) =>
      (delete(productImages)..where((t) => t.id.equals(id))).go();

  Future<List<ProductImage>> getProductImages(String productId) =>
      (select(productImages)
            ..where((t) => t.productId.equals(productId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<ProductImage?> getPrimaryProductImage(String productId) =>
      (select(productImages)
            ..where((t) => t.productId.equals(productId))
            ..where((t) => t.isPrimary.equals(true)))
          .getSingleOrNull();

  // ---------------------------------------------------------------------------
  // ProductRates
  // ---------------------------------------------------------------------------

  Future<int> insertProductRate(ProductRatesCompanion entry) =>
      into(productRates).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateProductRate(ProductRatesCompanion entry) =>
      update(productRates).replace(entry);

  Future<int> deleteProductRate(String id) =>
      (delete(productRates)..where((t) => t.id.equals(id))).go();

  Future<List<ProductRate>> getProductRatesByProduct(String productId) =>
      (select(productRates)..where((t) => t.productId.equals(productId))).get();

  Future<ProductRate?> getProductRateById(String id) =>
      (select(productRates)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<ProductRate>> getActiveProductRates() =>
      (select(productRates)..where((t) => t.isActive.equals(true))).get();

  Future<ProductRate?> getRateForProductAndType(String productId, String rateType) =>
      (select(productRates)
            ..where((t) => t.productId.equals(productId) & t.rateType.equals(rateType))
            ..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  // ---------------------------------------------------------------------------
  // PartyRates
  // ---------------------------------------------------------------------------

  Future<int> insertPartyRate(PartyRatesCompanion entry) =>
      into(partyRates).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updatePartyRate(PartyRatesCompanion entry) =>
      update(partyRates).replace(entry);

  Future<int> deletePartyRate(String id) =>
      (delete(partyRates)..where((t) => t.id.equals(id))).go();

  Future<List<PartyRate>> getPartyRatesByCustomer(String customerId) =>
      (select(partyRates)..where((t) => t.customerId.equals(customerId))).get();

  Future<List<PartyRate>> getPartyRatesByProduct(String productId) =>
      (select(partyRates)..where((t) => t.productId.equals(productId))).get();

  Future<PartyRate?> getPartyRateForProduct(String customerId, String productId) =>
      (select(partyRates)
            ..where((t) => t.customerId.equals(customerId) & t.productId.equals(productId))
            ..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  // ---------------------------------------------------------------------------
  // DiscountRules
  // ---------------------------------------------------------------------------

  Future<int> insertDiscountRule(DiscountRulesCompanion entry) =>
      into(discountRules).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateDiscountRule(DiscountRulesCompanion entry) =>
      update(discountRules).replace(entry);

  Future<int> deleteDiscountRule(String id) =>
      (delete(discountRules)..where((t) => t.id.equals(id))).go();

  Future<DiscountRule?> getDiscountRuleById(String id) =>
      (select(discountRules)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<DiscountRule>> getAllActiveDiscountRules() =>
      (select(discountRules)..where((t) => t.isActive.equals(true))).get();

  Future<List<DiscountRule>> getDiscountRulesForProduct(String productId) =>
      (select(discountRules)
            ..where((t) => t.productId.equals(productId) & t.isActive.equals(true)))
          .get();

  Future<List<DiscountRule>> getDiscountRulesForCategory(String categoryId) =>
      (select(discountRules)
            ..where((t) => t.categoryId.equals(categoryId) & t.isActive.equals(true)))
          .get();

  Future<List<DiscountRule>> getDiscountRulesForParty(String partyId) =>
      (select(discountRules)
            ..where((t) => t.partyId.equals(partyId) & t.isActive.equals(true)))
          .get();

  // ---------------------------------------------------------------------------
  // SchemeRules
  // ---------------------------------------------------------------------------

  Future<int> insertSchemeRule(SchemeRulesCompanion entry) =>
      into(schemeRules).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateSchemeRule(SchemeRulesCompanion entry) =>
      update(schemeRules).replace(entry);

  Future<int> deleteSchemeRule(String id) =>
      (delete(schemeRules)..where((t) => t.id.equals(id))).go();

  Future<SchemeRule?> getSchemeRuleById(String id) =>
      (select(schemeRules)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<SchemeRule>> getAllActiveSchemeRules() =>
      (select(schemeRules)..where((t) => t.isActive.equals(true))).get();

  Future<List<SchemeRule>> getSchemesForProduct(String productId) =>
      (select(schemeRules)
            ..where((t) => t.productId.equals(productId) & t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.priority)]))
          .get();

  Future<List<SchemeRule>> getSchemesForCategory(String categoryId) =>
      (select(schemeRules)
            ..where((t) => t.categoryId.equals(categoryId) & t.isActive.equals(true)))
          .get();

  // ---------------------------------------------------------------------------
  // BundlePacks
  // ---------------------------------------------------------------------------

  Future<int> insertBundlePack(BundlePacksCompanion entry) =>
      into(bundlePacks).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateBundlePack(BundlePacksCompanion entry) =>
      update(bundlePacks).replace(entry);

  Future<int> deleteBundlePack(String id) =>
      (delete(bundlePacks)..where((t) => t.id.equals(id))).go();

  Future<BundlePack?> getBundlePackById(String id) =>
      (select(bundlePacks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<BundlePack>> getAllActiveBundlePacks() =>
      (select(bundlePacks)..where((t) => t.isActive.equals(true))).get();

  Future<List<BundlePack>> searchBundlePacks(String query) {
    final q = '%$query%';
    return (select(bundlePacks)
          ..where((t) => t.name.like(q) & t.isActive.equals(true)))
        .get();
  }

  // ---------------------------------------------------------------------------
  // BundlePackItems
  // ---------------------------------------------------------------------------

  Future<int> insertBundlePackItem(BundlePackItemsCompanion entry) =>
      into(bundlePackItems).insert(entry, mode: InsertMode.insertOrReplace);

  Future<int> deleteBundlePackItems(String bundleId) =>
      (delete(bundlePackItems)..where((t) => t.bundleId.equals(bundleId))).go();

  Future<List<BundlePackItem>> getBundlePackItems(String bundleId) =>
      (select(bundlePackItems)..where((t) => t.bundleId.equals(bundleId))).get();

  // ---------------------------------------------------------------------------
  // InvoiceFormats
  // ---------------------------------------------------------------------------

  Future<int> insertInvoiceFormat(InvoiceFormatsCompanion entry) =>
      into(invoiceFormats).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateInvoiceFormat(InvoiceFormatsCompanion entry) =>
      update(invoiceFormats).replace(entry);

  Future<int> deleteInvoiceFormat(String id) =>
      (delete(invoiceFormats)..where((t) => t.id.equals(id))).go();

  Future<InvoiceFormat?> getInvoiceFormatById(String id) =>
      (select(invoiceFormats)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<InvoiceFormat>> getInvoiceFormatsByType(String documentType) =>
      (select(invoiceFormats)
            ..where((t) => t.documentType.equals(documentType) & t.isActive.equals(true)))
          .get();

  Future<InvoiceFormat?> getDefaultInvoiceFormat(String documentType) =>
      (select(invoiceFormats)
            ..where((t) => t.documentType.equals(documentType) & t.isDefault.equals(true)))
          .getSingleOrNull();

  // ---------------------------------------------------------------------------
  // BarcodeLabelTemplates
  // ---------------------------------------------------------------------------

  Future<int> insertBarcodeLabelTemplate(BarcodeLabelTemplatesCompanion entry) =>
      into(barcodeLabelTemplates).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateBarcodeLabelTemplate(BarcodeLabelTemplatesCompanion entry) =>
      update(barcodeLabelTemplates).replace(entry);

  Future<int> deleteBarcodeLabelTemplate(String id) =>
      (delete(barcodeLabelTemplates)..where((t) => t.id.equals(id))).go();

  Future<BarcodeLabelTemplate?> getBarcodeLabelTemplateById(String id) =>
      (select(barcodeLabelTemplates)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<BarcodeLabelTemplate>> getAllBarcodeLabelTemplates() =>
      (select(barcodeLabelTemplates)..where((t) => t.isActive.equals(true))).get();

  Future<BarcodeLabelTemplate?> getDefaultBarcodeLabelTemplate() =>
      (select(barcodeLabelTemplates)..where((t) => t.isDefault.equals(true))).getSingleOrNull();

  // ---------------------------------------------------------------------------
  // Challans
  // ---------------------------------------------------------------------------

  Future<int> insertChallan(ChallansCompanion entry) =>
      into(challans).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateChallan(ChallansCompanion entry) =>
      update(challans).replace(entry);

  Future<int> deleteChallan(String id) =>
      (delete(challans)..where((t) => t.id.equals(id))).go();

  Future<Challan?> getChallanById(String id) =>
      (select(challans)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Challan>> getAllChallans() =>
      (select(challans)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<List<Challan>> getPendingChallans() =>
      (select(challans)..where((t) => t.status.equals('pending'))).get();

  Future<List<Challan>> getChallansByCustomer(String customerId) =>
      (select(challans)..where((t) => t.customerId.equals(customerId))).get();

  // ---------------------------------------------------------------------------
  // ChallanItems
  // ---------------------------------------------------------------------------

  Future<int> insertChallanItem(ChallanItemsCompanion entry) =>
      into(challanItems).insert(entry, mode: InsertMode.insertOrReplace);

  Future<int> deleteChallanItems(String challanId) =>
      (delete(challanItems)..where((t) => t.challanId.equals(challanId))).go();

  Future<List<ChallanItem>> getChallanItems(String challanId) =>
      (select(challanItems)..where((t) => t.challanId.equals(challanId))).get();

  // ---------------------------------------------------------------------------
  // SalesOrders
  // ---------------------------------------------------------------------------

  Future<int> insertSalesOrder(SalesOrdersCompanion entry) =>
      into(salesOrders).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updateSalesOrder(SalesOrdersCompanion entry) =>
      update(salesOrders).replace(entry);

  Future<int> deleteSalesOrder(String id) =>
      (delete(salesOrders)..where((t) => t.id.equals(id))).go();

  Future<SalesOrder?> getSalesOrderById(String id) =>
      (select(salesOrders)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<SalesOrder>> getAllSalesOrders() =>
      (select(salesOrders)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<List<SalesOrder>> getPendingSalesOrders() =>
      (select(salesOrders)..where((t) => t.status.equals('pending'))).get();

  Future<List<SalesOrder>> getSalesOrdersByCustomer(String customerId) =>
      (select(salesOrders)..where((t) => t.customerId.equals(customerId))).get();

  // ---------------------------------------------------------------------------
  // SalesOrderItems
  // ---------------------------------------------------------------------------

  Future<int> insertSalesOrderItem(SalesOrderItemsCompanion entry) =>
      into(salesOrderItems).insert(entry, mode: InsertMode.insertOrReplace);

  Future<int> deleteSalesOrderItems(String orderId) =>
      (delete(salesOrderItems)..where((t) => t.orderId.equals(orderId))).go();

  Future<List<SalesOrderItem>> getSalesOrderItems(String orderId) =>
      (select(salesOrderItems)..where((t) => t.orderId.equals(orderId))).get();

  // ---------------------------------------------------------------------------
  // PurchaseOrders
  // ---------------------------------------------------------------------------

  Future<int> insertPurchaseOrder(PurchaseOrdersCompanion entry) =>
      into(purchaseOrders).insert(entry, mode: InsertMode.insertOrReplace);

  Future<bool> updatePurchaseOrder(PurchaseOrdersCompanion entry) =>
      update(purchaseOrders).replace(entry);

  Future<int> deletePurchaseOrder(String id) =>
      (delete(purchaseOrders)..where((t) => t.id.equals(id))).go();

  Future<PurchaseOrder?> getPurchaseOrderById(String id) =>
      (select(purchaseOrders)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<PurchaseOrder>> getAllPurchaseOrders() =>
      (select(purchaseOrders)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<List<PurchaseOrder>> getPendingPurchaseOrders() =>
      (select(purchaseOrders)..where((t) => t.status.equals('pending'))).get();

  Future<List<PurchaseOrder>> getPurchaseOrdersBySupplier(String supplierId) =>
      (select(purchaseOrders)..where((t) => t.supplierId.equals(supplierId))).get();

  // ---------------------------------------------------------------------------
  // PurchaseOrderItems
  // ---------------------------------------------------------------------------

  Future<int> insertPurchaseOrderItem(PurchaseOrderItemsCompanion entry) =>
      into(purchaseOrderItems).insert(entry, mode: InsertMode.insertOrReplace);

  Future<int> deletePurchaseOrderItems(String orderId) =>
      (delete(purchaseOrderItems)..where((t) => t.orderId.equals(orderId))).go();

  Future<List<PurchaseOrderItem>> getPurchaseOrderItems(String orderId) =>
      (select(purchaseOrderItems)..where((t) => t.orderId.equals(orderId))).get();

  // ---------------------------------------------------------------------------
  // PurchaseDealHistory
  // ---------------------------------------------------------------------------

  Future<int> insertPurchaseDeal(PurchaseDealHistoryCompanion entry) =>
      into(purchaseDealHistory).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<PurchaseDealHistoryData>> getDealHistoryForProduct(String productId, {int limit = 4}) =>
      (select(purchaseDealHistory)
            ..where((t) => t.productId.equals(productId))
            ..orderBy([(t) => OrderingTerm.desc(t.dealDate)])
            ..limit(limit))
          .get();

  Future<List<PurchaseDealHistoryData>> getDealHistoryForSupplier(String supplierId) =>
      (select(purchaseDealHistory)
            ..where((t) => t.supplierId.equals(supplierId))
            ..orderBy([(t) => OrderingTerm.desc(t.dealDate)]))
          .get();

  Future<List<PurchaseDealHistoryData>> getDealHistoryForProductSupplier(
          String productId, String supplierId, {int limit = 4}) =>
      (select(purchaseDealHistory)
            ..where((t) => t.productId.equals(productId) & t.supplierId.equals(supplierId))
            ..orderBy([(t) => OrderingTerm.desc(t.dealDate)])
            ..limit(limit))
          .get();
}
