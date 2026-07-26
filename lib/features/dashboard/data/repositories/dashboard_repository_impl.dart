import 'package:dartz/dartz.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../database/app_database.dart' as db;
import '../../../../core/error/failures.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';

/// Implementation of [DashboardRepository] providing aggregated business
/// intelligence statistics for the main dashboard screen.
///
/// ## Architecture
///
/// This repository is **purely local-first** — all data is read directly
/// from the local Drift (SQLite) database via [DatabaseDao]. There is no
/// remote data source interaction, as the dashboard aggregates data that
/// has already been synced and cached locally by other repositories.
///
/// ### Data Sources
/// All dashboard stats are derived from local database tables:
/// - **Sales**: Bills table (today, month, year totals and counts)
/// - **Inventory**: Products and Stock tables (stock levels, low stock alerts)
/// - **Customers**: Customers table (counts, outstanding balances, B2B split)
/// - **Employees**: Employees table (counts, active status)
/// - **Purchases**: Purchases table (today/month totals, pending orders)
/// - **Sync**: Sync queue table (pending/failed item counts)
///
/// ### Computed Metrics
/// - **Average Transaction Value**: todaySales / todayTransactions
/// - **Low Stock Items**: Products where 0 < currentStock <= reorderLevel
/// - **Total Outstanding**: Sum of currentBalance across all customers
/// - **Top Products**: Aggregated from bill items across all bills, sorted
///   by revenue (quantity × sellingPrice)
/// - **Day-over-Day Comparison**: todaySales vs yesterdaySales
///
/// ### Error Handling
/// - Returns `Either<Failure, DashboardStats>`.
/// - [ServerFailure] is used for any exception (misnomer — this is a local
///   operation, but the codebase uses ServerFailure as the general failure type).
///
/// ### Performance Considerations
/// - The [getDashboardStats] method issues many sequential DB queries.
///   In a production system, these could be parallelized or replaced with
///   a single aggregated SQL query / materialized view.
/// - [getTopProducts] performs an N+1 query pattern (fetches all bills, then
///   bill items per bill). This could be optimized with a JOIN query.
class DashboardRepositoryImpl implements DashboardRepository {
  final db.DatabaseDao _dao;
  final Connectivity _connectivity;

  DashboardRepositoryImpl({required db.DatabaseDao dao, Connectivity? connectivity})
      : _dao = dao,
        _connectivity = connectivity ?? Connectivity();

  /// Aggregates all dashboard statistics from the local database.
  ///
  /// Computes and returns a comprehensive [DashboardStats] object containing:
  /// - **SalesStats**: today/month/year sales totals, transaction counts,
  ///   average transaction value, and yesterday's sales for comparison.
  /// - **InventoryStats**: total products, low stock count, out of stock
  ///   count, total stock value, and list of low-stock items with details.
  /// - **CustomerStats**: total/active/B2B customer counts and total
  ///   outstanding balance across all customers.
  /// - **LoyaltyStats**: (placeholder — not yet implemented).
  /// - **PurchaseStats**: today/month purchase totals, pending orders,
  ///   total suppliers count.
  /// - **EmployeeStats**: total/active employee counts.
  /// - **SyncStats**: pending/failed sync items and last sync timestamp.
  ///
  /// All computations are performed against the local Drift database.
  /// Date ranges are computed relative to [DateTime.now()].
  @override
  Future<Either<Failure, DashboardStats>> getDashboardStats() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 1);
      final startOfYear = DateTime(now.year, 1, 1);

      final todaySales = await _dao.getDaySalesTotal(now);
      final todayTransactions = await _dao.getBillCountForDate(now);

      final monthBills = await _dao.getBillsByDateRange(startOfMonth, endOfMonth);
      final monthSales = monthBills.fold<int>(0, (int sum, db.Bill b) => sum + b.totalAmount);
      final monthTransactions = monthBills.length;

      final yearBills = await _dao.getBillsByDateRange(startOfYear, endOfDay);
      final yearSales = yearBills.fold<int>(0, (int sum, db.Bill b) => sum + b.totalAmount);
      final yearTransactions = yearBills.length;

      final yesterdaySales = await _dao.getDaySalesTotal(
        now.subtract(const Duration(days: 1)),
      );

      final averageTransactionValue = todayTransactions > 0
          ? (todaySales / todayTransactions).round()
          : 0;

      final allProducts = await _dao.getAllProducts();
      final stock = await _dao.getAllStock();
      final lowStockItems = allProducts
          .where((db.Product p) => p.currentStock > 0 && p.currentStock <= p.reorderLevel)
          .map((db.Product p) => LowStockItem(
                productId: p.id,
                productName: p.name,
                currentStock: p.currentStock,
                reorderLevel: p.reorderLevel,
              ))
          .toList();

      final allCustomers = await _dao.getAllCustomers();
      final activeCustomers = await _dao.getActiveCustomers();
      final totalOutstanding = allCustomers.fold<int>(
        0,
        (int sum, db.Customer c) => sum + c.currentBalance,
      );
      final b2bCustomers = allCustomers.where((db.Customer c) => c.type == 'B2B').length;

      final todayAdded = allProducts
          .where((db.Product p) =>
              p.createdAt.isAfter(startOfDay) && p.createdAt.isBefore(endOfDay))
          .length;

      final nearExpiryCount = stock
          .where((db.StockData s) =>
              s.expiryDate != null &&
              s.expiryDate!.isAfter(now) &&
              s.expiryDate!.difference(now).inDays <= 30)
          .length;

      final newCustomersToday = allCustomers
          .where((db.Customer c) =>
              c.createdAt.isAfter(startOfDay) && c.createdAt.isBefore(endOfDay))
          .length;

      final newCustomersMonth = allCustomers
          .where((db.Customer c) =>
              c.createdAt.isAfter(startOfMonth) && c.createdAt.isBefore(endOfMonth))
          .length;

      final allEmployees = await _dao.getAllEmployees();
      final activeEmployees = await _dao.getActiveEmployees();

      final todayAttendance = await _dao.getAttendanceByDate(startOfDay);
      final clockedInNow = todayAttendance
          .where((db.AttendanceData a) =>
              a.clockIn != null && a.clockOut == null)
          .length;

      final allBills = await _dao.getAllBills();
      final pendingPayments = allBills
          .where((db.Bill b) => b.dueAmount > 0)
          .length;

      final todayBills = allBills
          .where((db.Bill b) =>
              !b.isReturn &&
              b.billDate.isAfter(startOfDay) &&
              b.billDate.isBefore(endOfDay))
          .toList();
      final employeeSales = <String, int>{};
      for (final db.Bill b in todayBills) {
        employeeSales[b.createdBy] =
            (employeeSales[b.createdBy] ?? 0) + b.totalAmount;
      }
      String topPerformerName = '';
      int topPerformerSales = 0;
      if (employeeSales.isNotEmpty) {
        final topEntry = (employeeSales.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;
        topPerformerSales = topEntry.value;
        final topEmployee = allEmployees
            .where((db.Employee e) => e.id == topEntry.key)
            .toList();
        topPerformerName =
            topEmployee.isNotEmpty ? topEmployee.first.name : topEntry.key;
      }

      bool isConnected = true;
      try {
        final result = await _connectivity.checkConnectivity();
        isConnected = result != ConnectivityResult.none;
      } catch (_) {
        isConnected = true;
      }

      final allPurchases = await _dao.getAllPurchases();
      final todayPurchases = allPurchases
          .where((db.Purchase p) =>
              p.createdAt.isAfter(startOfDay) &&
              p.createdAt.isBefore(endOfDay))
          .fold<int>(0, (int sum, db.Purchase p) => sum + p.totalAmount);
      final monthPurchases = allPurchases
          .where((db.Purchase p) =>
              p.createdAt.isAfter(startOfMonth) &&
              p.createdAt.isBefore(endOfMonth))
          .fold<int>(0, (int sum, db.Purchase p) => sum + p.totalAmount);
      final pendingOrders = allPurchases
          .where((db.Purchase p) => p.status == 'pending')
          .length;

      final suppliers = await _dao.getAllSuppliers();

      final syncItems = await _dao.getAllSyncItems();
      final pendingSyncItems = syncItems
          .where((db.SyncQueueData s) => s.status == 'pending')
          .length;
      final failedSyncItems = syncItems
          .where((db.SyncQueueData s) => s.status == 'failed')
          .length;

      final loyaltyTransactions = await _dao.getAllLoyaltyTransactions();
      final totalPointsIssued = loyaltyTransactions
          .where((t) => t.transactionType == 'earn')
          .fold<int>(0, (int sum, t) => sum + t.points);
      final totalPointsRedeemed = loyaltyTransactions
          .where((t) => t.transactionType == 'redeem')
          .fold<int>(0, (int sum, t) => sum + t.points);
      final customersWithLoyalty = allCustomers.where((c) => c.loyaltyPoints > 0).length;

      final stats = DashboardStats(
        sales: SalesStats(
          todaySales: todaySales,
          todayTransactions: todayTransactions,
          monthSales: monthSales,
          monthTransactions: monthTransactions,
          yearSales: yearSales,
          yearTransactions: yearTransactions,
          averageTransactionValue: averageTransactionValue,
          yesterdaySales: yesterdaySales,
        ),
        inventory: InventoryStats(
          totalProducts: allProducts.length,
          lowStockCount: lowStockItems.length,
          outOfStockCount: allProducts.where((db.Product p) => p.currentStock == 0).length,
          totalStockValue: stock.fold<int>(0, (int sum, db.StockData s) => sum + (s.quantity)),
          todayAdded: todayAdded,
          todayRemoved: 0,
          nearExpiryCount: nearExpiryCount,
          lowStockItems: lowStockItems,
        ),
        customers: CustomerStats(
          totalCustomers: allCustomers.length,
          newCustomersToday: newCustomersToday,
          newCustomersMonth: newCustomersMonth,
          activeCustomers: activeCustomers.length,
          totalOutstanding: totalOutstanding,
          b2bCustomers: b2bCustomers,
        ),
        loyalty: LoyaltyStats(
          totalPointsIssued: totalPointsIssued,
          totalPointsRedeemed: totalPointsRedeemed,
          activeMembers: customersWithLoyalty,
          totalMembers: allCustomers.length,
        ),
        purchases: PurchaseStats(
          todayPurchases: todayPurchases,
          monthPurchases: monthPurchases,
          pendingOrders: pendingOrders,
          totalSuppliers: suppliers.length,
          pendingPayments: pendingPayments,
        ),
        employees: EmployeeStats(
          totalEmployees: allEmployees.length,
          activeToday: activeEmployees.length,
          clockedInNow: clockedInNow,
          topPerformerName: topPerformerName,
          topPerformerSales: topPerformerSales,
        ),
        sync: SyncStats(
          pendingItems: pendingSyncItems,
          failedItems: failedSyncItems,
          lastSyncTime: DateTime.now(),
          isSyncing: false,
          isConnected: isConnected,
        ),
        lastUpdated: DateTime.now(),
      );

      return Right(stats);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Returns the most recent sales (bills) for display on the dashboard.
  ///
  /// Maps [Bill] database objects to [RecentSale] dashboard entities with
  /// simplified fields (bill number, customer name, amount, timestamp).
  @override
  Future<Either<Failure, List<RecentSale>>> getRecentSales({int limit = 10}) async {
    try {
      final bills = await _dao.getRecentBills(limit: limit);
      final sales = bills
          .map((db.Bill b) => RecentSale(
                id: b.id,
                billNumber: b.billNumber,
                customerName: b.customerName ?? '',
                amount: b.totalAmount,
                createdAt: b.createdAt,
              ))
          .toList();
      return Right(sales);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Returns the top-selling products ranked by total revenue.
  ///
  /// Aggregates quantity sold across all bill items, then multiplies by
  /// each product's selling price to compute revenue. Results are sorted
  /// in descending order by revenue and limited to [limit] entries.
  ///
  /// Note: This uses an N+1 query pattern (fetches all bills, then items
  /// per bill). A production optimization would use a single SQL JOIN query.
  @override
  Future<Either<Failure, List<TopProduct>>> getTopProducts({int limit = 5}) async {
    try {
      final allProducts = await _dao.getAllProducts();
      final allBills = await _dao.getAllBills();

      final productSales = <String, int>{};
      for (final db.Bill bill in allBills) {
        final items = await _dao.getBillItemsByBillId(bill.id);
        for (final db.BillItem item in items) {
          productSales[item.productId] =
              (productSales[item.productId] ?? 0) + item.quantity.round();
        }
      }

      final products = productSales.entries.map((entry) {
        final product = allProducts.firstWhere(
          (db.Product p) => p.id == entry.key,
          orElse: () => allProducts.first,
        );
        return TopProduct(
          productId: entry.key,
          productName: product.name,
          quantitySold: entry.value,
          revenue: entry.value * product.sellingPrice,
        );
      }).toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      return Right(products.take(limit).toList());
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Returns a list of actionable alert items for the dashboard.
  ///
  /// Currently generates two alert types:
  /// - **low_stock**: Triggered when any product has stock between 1 and
  ///   its reorder level (inclusive).
  /// - **sync**: Triggered when there are pending items in the sync queue.
  ///
  /// Alert IDs are generated sequentially (a1, a2, ...) for each dashboard
  /// refresh session.
  @override
  Future<Either<Failure, List<AlertItem>>> getAlerts() async {
    try {
      final alerts = <AlertItem>[];
      var id = 0;

      final allProducts = await _dao.getAllProducts();
      final lowStock = allProducts
          .where((db.Product p) => p.currentStock > 0 && p.currentStock <= p.reorderLevel)
          .length;
      if (lowStock > 0) {
        alerts.add(AlertItem(
          id: 'a${++id}',
          type: 'low_stock',
          title: 'Low Stock Alert',
          message: '$lowStock products are below reorder level',
          createdAt: DateTime.now(),
        ));
      }

      final syncItems = await _dao.getPendingSyncItems();
      if (syncItems.isNotEmpty) {
        alerts.add(AlertItem(
          id: 'a${++id}',
          type: 'sync',
          title: 'Sync Pending',
          message: '${syncItems.length} items waiting to sync',
          createdAt: DateTime.now(),
        ));
      }

      return Right(alerts);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
