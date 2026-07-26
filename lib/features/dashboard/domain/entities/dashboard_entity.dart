import 'package:equatable/equatable.dart';

/// Aggregate domain entity containing all dashboard statistics for the ERP home screen.
///
/// DashboardStats is the primary data structure returned by [DashboardRepository.getDashboardStats].
/// It bundles sales, inventory, customer, loyalty, purchase, employee, and sync
/// metrics into a single snapshot for efficient dashboard rendering.
///
/// The [lastUpdated] timestamp indicates when the statistics were last
/// refreshed from the local database or server.
class DashboardStats extends Equatable {
  /// Today's, monthly, and yearly sales metrics.
  final SalesStats sales;

  /// Inventory health: stock levels, low-stock alerts, and near-expiry counts.
  final InventoryStats inventory;

  /// Customer acquisition and outstanding balance summary.
  final CustomerStats customers;

  /// Loyalty program participation and point flow metrics.
  final LoyaltyStats loyalty;

  /// Purchase order activity and pending supplier payments.
  final PurchaseStats purchases;

  /// Workforce attendance and top performer metrics.
  final EmployeeStats employees;

  /// Sync queue health: pending, failed items, and connectivity status.
  final SyncStats sync;

  /// Timestamp when these statistics were last computed/refreshed.
  final DateTime lastUpdated;

  const DashboardStats({
    required this.sales,
    required this.inventory,
    required this.customers,
    required this.loyalty,
    required this.purchases,
    required this.employees,
    required this.sync,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [
        sales, inventory, customers, loyalty,
        purchases, employees, sync, lastUpdated,
      ];
}

/// Sales performance metrics aggregated across daily, monthly, and yearly periods.
///
/// All monetary values are in paise. Transaction counts represent the number
/// of individual bills generated in each period.
class SalesStats extends Equatable {
  /// Total sales revenue generated today, in paise.
  final int todaySales;

  /// Number of transactions (bills) completed today.
  final int todayTransactions;

  /// Total sales revenue for the current calendar month, in paise.
  final int monthSales;

  /// Number of transactions completed in the current calendar month.
  final int monthTransactions;

  /// Total sales revenue for the current calendar year, in paise.
  final int yearSales;

  /// Number of transactions completed in the current calendar year.
  final int yearTransactions;

  /// Average transaction value in paise (totalAmount / transactionCount).
  final int averageTransactionValue;

  /// Total sales revenue for yesterday, in paise — used for day-over-day comparison.
  final int yesterdaySales;

  /// Hourly breakdown of today's sales for trend visualization.
  final List<HourlySales> hourlySales;

  const SalesStats({
    this.todaySales = 0,
    this.todayTransactions = 0,
    this.monthSales = 0,
    this.monthTransactions = 0,
    this.yearSales = 0,
    this.yearTransactions = 0,
    this.averageTransactionValue = 0,
    this.yesterdaySales = 0,
    this.hourlySales = const [],
  });

  /// Day-over-day sales growth percentage.
  /// Returns 0.0 if yesterday's sales were zero (no comparison baseline).
  double get salesGrowthPercent => yesterdaySales > 0
      ? ((todaySales - yesterdaySales) / yesterdaySales * 100)
      : 0.0;

  @override
  List<Object?> get props => [
        todaySales, todayTransactions, monthSales, monthTransactions,
        yearSales, yearTransactions, averageTransactionValue,
        yesterdaySales, hourlySales,
      ];
}

/// Hourly sales data point for intraday trend chart visualization.
class HourlySales extends Equatable {
  /// Hour of the day in 24-hour format (0-23).
  final int hour;

  /// Total sales revenue for this hour, in paise.
  final int sales;

  /// Number of transactions completed during this hour.
  final int transactions;

  const HourlySales({
    required this.hour,
    required this.sales,
    required this.transactions,
  });

  @override
  List<Object?> get props => [hour, sales, transactions];
}

/// Inventory health metrics including stock levels and expiry alerts.
class InventoryStats extends Equatable {
  /// Total number of distinct products tracked in the system.
  final int totalProducts;

  /// Number of products at or below their reorder threshold.
  final int lowStockCount;

  /// Number of products with zero or negative available stock.
  final int outOfStockCount;

  /// Total inventory valuation at cost price, in paise.
  final int totalStockValue;

  /// Number of stock additions (purchases received) today.
  final int todayAdded;

  /// Number of stock deductions (sales, adjustments, wastage) today.
  final int todayRemoved;

  /// Number of products expiring within 30 days — requires priority action.
  final int nearExpiryCount;

  /// List of products currently below their reorder level for quick restocking.
  final List<LowStockItem> lowStockItems;

  const InventoryStats({
    this.totalProducts = 0,
    this.lowStockCount = 0,
    this.outOfStockCount = 0,
    this.totalStockValue = 0,
    this.todayAdded = 0,
    this.todayRemoved = 0,
    this.nearExpiryCount = 0,
    this.lowStockItems = const [],
  });

  @override
  List<Object?> get props => [
        totalProducts, lowStockCount, outOfStockCount,
        totalStockValue, todayAdded, todayRemoved,
        nearExpiryCount, lowStockItems,
      ];
}

/// Lightweight product representation for low-stock alert display.
class LowStockItem extends Equatable {
  /// Foreign key to the [Product] that needs restocking.
  final String productId;

  /// Product name for display in the low-stock alert list.
  final String productName;

  /// Current quantity on hand that triggered the low-stock condition.
  final int currentStock;

  /// The reorder threshold for this product.
  final int reorderLevel;

  const LowStockItem({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.reorderLevel,
  });

  @override
  List<Object?> get props => [productId, productName, currentStock, reorderLevel];
}

/// Customer acquisition and financial health metrics.
class CustomerStats extends Equatable {
  /// Total number of registered customers in the system.
  final int totalCustomers;

  /// Number of new customers registered today.
  final int newCustomersToday;

  /// Number of new customers registered in the current calendar month.
  final int newCustomersMonth;

  /// Number of customers who have made at least one purchase in the last 30 days.
  final int activeCustomers;

  /// Total outstanding credit balance across all B2B customers, in paise.
  final int totalOutstanding;

  /// Number of customers classified as B2B (business accounts).
  final int b2bCustomers;

  const CustomerStats({
    this.totalCustomers = 0,
    this.newCustomersToday = 0,
    this.newCustomersMonth = 0,
    this.activeCustomers = 0,
    this.totalOutstanding = 0,
    this.b2bCustomers = 0,
  });

  @override
  List<Object?> get props => [
        totalCustomers, newCustomersToday, newCustomersMonth,
        activeCustomers, totalOutstanding, b2bCustomers,
      ];
}

/// Loyalty program health metrics for the dashboard summary card.
class LoyaltyStats extends Equatable {
  /// Total points earned by all customers (lifetime cumulative).
  final int totalPointsIssued;

  /// Total points redeemed by all customers (lifetime cumulative).
  final int totalPointsRedeemed;

  /// Points pending confirmation or awaiting bill finalization.
  final int pendingPoints;

  /// Number of customers with a non-zero loyalty balance (active participants).
  final int activeMembers;

  /// Total number of customers enrolled in the loyalty program.
  final int totalMembers;

  const LoyaltyStats({
    this.totalPointsIssued = 0,
    this.totalPointsRedeemed = 0,
    this.pendingPoints = 0,
    this.activeMembers = 0,
    this.totalMembers = 0,
  });

  @override
  List<Object?> get props => [
        totalPointsIssued, totalPointsRedeemed,
        pendingPoints, activeMembers, totalMembers,
      ];
}

/// Purchase order activity and supplier management metrics.
class PurchaseStats extends Equatable {
  /// Total purchase order value created today, in paise.
  final int todayPurchases;

  /// Total purchase order value created in the current calendar month, in paise.
  final int monthPurchases;

  /// Number of purchase orders in 'pending' status (ordered but not yet received).
  final int pendingOrders;

  /// Total number of unique suppliers in the system.
  final int totalSuppliers;

  /// Number of purchase orders with pending payment to suppliers.
  final int pendingPayments;

  const PurchaseStats({
    this.todayPurchases = 0,
    this.monthPurchases = 0,
    this.pendingOrders = 0,
    this.totalSuppliers = 0,
    this.pendingPayments = 0,
  });

  @override
  List<Object?> get props => [
        todayPurchases, monthPurchases, pendingOrders,
        totalSuppliers, pendingPayments,
      ];
}

/// Employee workforce metrics for the dashboard summary card.
class EmployeeStats extends Equatable {
  /// Total number of active employees in the system.
  final int totalEmployees;

  /// Number of employees who have clocked in at any point today.
  final int activeToday;

  /// Number of employees currently clocked in (clocked in but not yet clocked out).
  final int clockedInNow;

  /// Name of the employee with the highest sales today — used for gamification.
  final String topPerformerName;

  /// Sales amount achieved by the top performer today, in paise.
  final int topPerformerSales;

  const EmployeeStats({
    this.totalEmployees = 0,
    this.activeToday = 0,
    this.clockedInNow = 0,
    this.topPerformerName = '',
    this.topPerformerSales = 0,
  });

  @override
  List<Object?> get props => [
        totalEmployees, activeToday, clockedInNow,
        topPerformerName, topPerformerSales,
      ];
}

/// Sync queue health metrics indicating offline data synchronization status.
class SyncStats extends Equatable {
  /// Number of items queued locally but not yet uploaded to the server.
  final int pendingItems;

  /// Number of items that failed to sync after exhausting all retry attempts.
  final int failedItems;

  /// Timestamp of the last successful sync operation.
  final DateTime? lastSyncTime;

  /// Whether a sync operation is currently in progress.
  final bool isSyncing;

  /// Whether the device currently has network connectivity.
  final bool isConnected;

  const SyncStats({
    this.pendingItems = 0,
    this.failedItems = 0,
    this.lastSyncTime,
    this.isSyncing = false,
    this.isConnected = true,
  });

  @override
  List<Object?> get props => [
        pendingItems, failedItems, lastSyncTime,
        isSyncing, isConnected,
      ];
}
