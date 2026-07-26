import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/error/failures.dart';
import '../../../../database/app_database.dart' as db;
import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  final db.DatabaseDao _dao;

  ReportRepositoryImpl({required db.DatabaseDao dao}) : _dao = dao;

  @override
  Future<Either<Failure, ReportData>> getReport(
    ReportType type, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, now.day);
      final end = endDate ?? now;

      final data = await _generateReport(type, start, end);
      return Right(data);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  Future<ReportData> _generateReport(
    ReportType type,
    DateTime start,
    DateTime end,
  ) async {
    switch (type) {
      case ReportType.dailySales:
        return _dailySalesReport(start, end);
      case ReportType.monthlySales:
        return _monthlySalesReport(start, end);
      case ReportType.salesByProduct:
        return _salesByProductReport(start, end);
      case ReportType.salesByCategory:
        return _salesByCategoryReport(start, end);
      case ReportType.stockSummary:
        return _stockSummaryReport();
      case ReportType.lowStockAlert:
        return _lowStockAlertReport();
      case ReportType.stockMovement:
        return _stockMovementReport();
      case ReportType.expiryReport:
        return _expiryReport();
      case ReportType.topCustomers:
        return _topCustomersReport(start, end);
      case ReportType.customerBalance:
        return _customerBalanceReport();
      case ReportType.loyaltySummary:
        return _loyaltySummaryReport();
      case ReportType.profitLoss:
        return _profitLossReport(start, end);
      case ReportType.gstReport:
        return _gstReport(start, end);
      case ReportType.expenseReport:
        return _expenseReport();
      case ReportType.attendanceReport:
        return _attendanceReport(start, end);
      case ReportType.salesByEmployee:
        return _salesByEmployeeReport(start, end);
      case ReportType.purchaseSummary:
        return _purchaseSummaryReport(start, end);
      case ReportType.supplierWise:
        return _supplierWiseReport(start, end);
      case ReportType.purchaseVsSales:
        return _purchaseVsSalesReport(start, end);
      case ReportType.hsnGstSummary:
        return _hsnGstSummaryReport(start, end);
    }
  }

  // ---------------------------------------------------------------------------
  // Sales Reports
  // ---------------------------------------------------------------------------

  Future<ReportData> _dailySalesReport(DateTime start, DateTime end) async {
    final bills = await _dao.getBillsByDateRange(start, end);
    final completedBills = bills
        .where((b) => b.status == 'completed' && !b.isReturn)
        .toList();

    final columns = ['Bill Number', 'Customer', 'Amount', 'CGST', 'SGST', 'IGST', 'Payment', 'Date'];
    final rows = completedBills
        .map((b) => {
              'Bill Number': b.billNumber,
              'Customer': b.customerName ?? 'Walk-in',
              'Amount': (b.totalAmount / 100).toStringAsFixed(2),
              'CGST': b.cgstAmount > 0 ? (b.cgstAmount / 100).toStringAsFixed(2) : '-',
              'SGST': b.sgstAmount > 0 ? (b.sgstAmount / 100).toStringAsFixed(2) : '-',
              'IGST': b.igstAmount > 0 ? (b.igstAmount / 100).toStringAsFixed(2) : '-',
              'Payment': b.paymentMode,
              'Date': DateFormat('dd MMM yyyy HH:mm').format(b.billDate),
            })
        .toList();

    final totalSales =
        completedBills.fold<int>(0, (sum, b) => sum + b.totalAmount);
    final totalTax =
        completedBills.fold<int>(0, (sum, b) => sum + b.taxAmount);
    final totalCgst =
        completedBills.fold<int>(0, (sum, b) => sum + b.cgstAmount);
    final totalSgst =
        completedBills.fold<int>(0, (sum, b) => sum + b.sgstAmount);
    final totalIgst =
        completedBills.fold<int>(0, (sum, b) => sum + b.igstAmount);
    final totalDiscount =
        completedBills.fold<int>(0, (sum, b) => sum + b.discountAmount);

    final summary = {
      'Total Bills': completedBills.length,
      'Total Sales': '₹${(totalSales / 100).toStringAsFixed(2)}',
      'Total Tax': '₹${(totalTax / 100).toStringAsFixed(2)}',
      'CGST': '₹${(totalCgst / 100).toStringAsFixed(2)}',
      'SGST': '₹${(totalSgst / 100).toStringAsFixed(2)}',
      'IGST': '₹${(totalIgst / 100).toStringAsFixed(2)}',
      'Total Discount': '₹${(totalDiscount / 100).toStringAsFixed(2)}',
      'Net Sales': '₹${((totalSales - totalDiscount) / 100).toStringAsFixed(2)}',
    };

    return ReportData(
      type: ReportType.dailySales,
      title: 'Daily Sales Report',
      description:
          'Sales from ${DateFormat('dd MMM yyyy').format(start)} to ${DateFormat('dd MMM yyyy').format(end)}',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: summary,
    );
  }

  Future<ReportData> _monthlySalesReport(DateTime start, DateTime end) async {
    final bills = await _dao.getBillsByDateRange(start, end);
    final completedBills = bills
        .where((b) => b.status == 'completed' && !b.isReturn)
        .toList();

    final monthlyData = <String, int>{};
    for (final bill in completedBills) {
      final key = DateFormat('MMM yyyy').format(bill.billDate);
      monthlyData[key] = (monthlyData[key] ?? 0) + bill.totalAmount;
    }

    final columns = ['Month', 'Sales Amount', 'Transaction Count'];
    final rows = monthlyData.entries
        .map((e) => {
              'Month': e.key,
              'Sales Amount': '₹${(e.value / 100).toStringAsFixed(2)}',
              'Transaction Count': completedBills
                  .where((b) =>
                      DateFormat('MMM yyyy').format(b.billDate) == e.key)
                  .length
                  .toString(),
            })
        .toList();

    final totalSales =
        completedBills.fold<int>(0, (sum, b) => sum + b.totalAmount);

    final summary = {
      'Total Sales': '₹${(totalSales / 100).toStringAsFixed(2)}',
      'Total Transactions': completedBills.length,
    };

    return ReportData(
      type: ReportType.monthlySales,
      title: 'Monthly Sales Report',
      description:
          'Sales from ${DateFormat('dd MMM yyyy').format(start)} to ${DateFormat('dd MMM yyyy').format(end)}',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: summary,
    );
  }

  Future<ReportData> _salesByProductReport(DateTime start, DateTime end) async {
    final bills = await _dao.getBillsByDateRange(start, end);
    final completedBills =
        bills.where((b) => b.status == 'completed' && !b.isReturn).toList();

    final productSales = <String, Map<String, dynamic>>{};
    for (final bill in completedBills) {
      final items = await _dao.getBillItemsByBillId(bill.id);
      for (final item in items) {
        if (!productSales.containsKey(item.productId)) {
          productSales[item.productId] = {
            'Product': item.productName,
            'Quantity': 0.0,
            'Revenue': 0,
          };
        }
        productSales[item.productId]!['Quantity'] =
            (productSales[item.productId]!['Quantity'] as double) +
                item.quantity;
        productSales[item.productId]!['Revenue'] =
            (productSales[item.productId]!['Revenue'] as int) +
                item.totalAmount;
      }
    }

    final sortedEntries = productSales.entries.toList()
      ..sort((a, b) =>
          (b.value['Revenue'] as int).compareTo(a.value['Revenue'] as int));

    final columns = ['Product', 'Quantity Sold', 'Revenue'];
    final rows = sortedEntries
        .map((e) => {
              'Product': e.value['Product'],
              'Quantity Sold': (e.value['Quantity'] as double).toStringAsFixed(2),
              'Revenue': '₹${((e.value['Revenue'] as int) / 100).toStringAsFixed(2)}',
            })
        .toList();

    final totalRevenue =
        sortedEntries.fold<int>(0, (sum, e) => sum + (e.value['Revenue'] as int));
    final totalQty = sortedEntries.fold<double>(
        0, (sum, e) => sum + (e.value['Quantity'] as double));

    final summary = {
      'Total Products': sortedEntries.length,
      'Total Quantity Sold': totalQty.toStringAsFixed(2),
      'Total Revenue': '₹${(totalRevenue / 100).toStringAsFixed(2)}',
    };

    return ReportData(
      type: ReportType.salesByProduct,
      title: 'Sales by Product Report',
      description: 'Product-wise sales breakdown',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: summary,
    );
  }

  Future<ReportData> _salesByCategoryReport(
      DateTime start, DateTime end) async {
    final allProducts = await _dao.getAllProducts();
    final bills = await _dao.getBillsByDateRange(start, end);
    final completedBills =
        bills.where((b) => b.status == 'completed' && !b.isReturn).toList();

    final categorySales = <String, int>{};
    for (final bill in completedBills) {
      final items = await _dao.getBillItemsByBillId(bill.id);
      for (final item in items) {
        final product = allProducts
            .where((p) => p.id == item.productId)
            .firstOrNull;
        final categoryId = product?.categoryId ?? 'Uncategorized';
        categorySales[categoryId] = (categorySales[categoryId] ?? 0) + item.totalAmount;
      }
    }

    final columns = ['Category', 'Revenue'];
    final rows = categorySales.entries
        .map((e) => {
              'Category': e.key,
              'Revenue': '₹${(e.value / 100).toStringAsFixed(2)}',
            })
        .toList();

    final totalRevenue =
        categorySales.values.fold<int>(0, (sum, v) => sum + v);

    return ReportData(
      type: ReportType.salesByCategory,
      title: 'Sales by Category Report',
      description: 'Category-wise sales breakdown',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Revenue': '₹${(totalRevenue / 100).toStringAsFixed(2)}',
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Inventory Reports
  // ---------------------------------------------------------------------------

  Future<ReportData> _stockSummaryReport() async {
    final products = await _dao.getAllProducts();

    final columns = ['Product', 'SKU', 'Current Stock', 'Reorder Level', 'Value'];
    final rows = products
        .map((p) => {
              'Product': p.name,
              'SKU': p.sku ?? '',
              'Current Stock': p.currentStock.toString(),
              'Reorder Level': p.reorderLevel.toString(),
              'Value':
                  '₹${((p.currentStock * p.sellingPrice) / 100).toStringAsFixed(2)}',
            })
        .toList();

    final totalValue = products.fold<int>(
        0, (sum, p) => sum + (p.currentStock * p.sellingPrice));
    final totalStock = products.fold<int>(0, (sum, p) => sum + p.currentStock);

    return ReportData(
      type: ReportType.stockSummary,
      title: 'Stock Summary Report',
      description: 'Current inventory levels',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Products': products.length,
        'Total Stock Units': totalStock,
        'Total Stock Value': '₹${(totalValue / 100).toStringAsFixed(2)}',
      },
    );
  }

  Future<ReportData> _lowStockAlertReport() async {
    final products = await _dao.getAllProducts();
    final lowStockProducts = products
        .where((p) => p.currentStock > 0 && p.currentStock <= p.reorderLevel)
        .toList();

    final columns = ['Product', 'SKU', 'Current Stock', 'Reorder Level', 'Deficit'];
    final rows = lowStockProducts
        .map((p) => {
              'Product': p.name,
              'SKU': p.sku ?? '',
              'Current Stock': p.currentStock.toString(),
              'Reorder Level': p.reorderLevel.toString(),
              'Deficit': (p.reorderLevel - p.currentStock).toString(),
            })
        .toList();

    return ReportData(
      type: ReportType.lowStockAlert,
      title: 'Low Stock Alert Report',
      description: 'Products at or below reorder level',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Low Stock Items': lowStockProducts.length,
      },
    );
  }

  Future<ReportData> _stockMovementReport() async {
    final stockRecords = await _dao.getAllStock();

    final columns = [
      'Product',
      'Location',
      'Quantity',
      'Reserved',
      'Available',
      'Batch',
      'Expiry',
    ];
    final rows = stockRecords
        .map((s) => {
              'Product': s.productName,
              'Location': s.locationId,
              'Quantity': s.quantity.toString(),
              'Reserved': s.reservedQuantity.toString(),
              'Available': (s.quantity - s.reservedQuantity).toString(),
              'Batch': s.batchNumber ?? '',
              'Expiry': s.expiryDate != null
                  ? DateFormat('dd MMM yyyy').format(s.expiryDate!)
                  : '',
            })
        .toList();

    return ReportData(
      type: ReportType.stockMovement,
      title: 'Stock Movement Report',
      description: 'Current stock records across locations',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Stock Records': stockRecords.length,
      },
    );
  }

  Future<ReportData> _expiryReport() async {
    final stockRecords = await _dao.getAllStock();
    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));

    final nearExpiry = stockRecords
        .where((s) =>
            s.expiryDate != null &&
            s.expiryDate!.isAfter(now) &&
            s.expiryDate!.isBefore(thirtyDaysFromNow))
        .toList();

    final columns = ['Product', 'Batch', 'Quantity', 'Expiry Date', 'Days Left'];
    final rows = nearExpiry
        .map((s) => {
              'Product': s.productName,
              'Batch': s.batchNumber ?? '',
              'Quantity': s.quantity.toString(),
              'Expiry Date': DateFormat('dd MMM yyyy').format(s.expiryDate!),
              'Days Left': s.expiryDate!.difference(now).inDays.toString(),
            })
        .toList();

    return ReportData(
      type: ReportType.expiryReport,
      title: 'Expiry Report',
      description: 'Items expiring within 30 days',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Near Expiry Items': nearExpiry.length,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Customer Reports
  // ---------------------------------------------------------------------------

  Future<ReportData> _topCustomersReport(DateTime start, DateTime end) async {
    final allCustomers = await _dao.getAllCustomers();
    final bills = await _dao.getBillsByDateRange(start, end);
    final completedBills = bills
        .where((b) =>
            b.status == 'completed' && !b.isReturn && b.customerId != null)
        .toList();

    final customerTotals = <String, int>{};
    final customerCounts = <String, int>{};
    for (final bill in completedBills) {
      final cid = bill.customerId!;
      customerTotals[cid] = (customerTotals[cid] ?? 0) + bill.totalAmount;
      customerCounts[cid] = (customerCounts[cid] ?? 0) + 1;
    }

    final sorted = customerTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final columns = ['Customer', 'Total Spent', 'Transactions'];
    final rows = sorted
        .map((e) {
          final customer =
              allCustomers.where((c) => c.id == e.key).firstOrNull;
          return {
            'Customer': customer?.name ?? 'Unknown',
            'Total Spent': '₹${(e.value / 100).toStringAsFixed(2)}',
            'Transactions': customerCounts[e.key].toString(),
          };
        })
        .toList();

    final totalRevenue = sorted.fold<int>(0, (sum, e) => sum + e.value);

    return ReportData(
      type: ReportType.topCustomers,
      title: 'Top Customers Report',
      description: 'Customers ranked by purchase amount',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Customers': sorted.length,
        'Total Revenue': '₹${(totalRevenue / 100).toStringAsFixed(2)}',
      },
    );
  }

  Future<ReportData> _customerBalanceReport() async {
    final allCustomers = await _dao.getAllCustomers();
    final withBalance =
        allCustomers.where((c) => c.currentBalance > 0).toList();
    withBalance.sort((a, b) => b.currentBalance.compareTo(a.currentBalance));

    final columns = ['Customer', 'Phone', 'Outstanding', 'Credit Limit'];
    final rows = withBalance
        .map((c) => {
              'Customer': c.name,
              'Phone': c.phone ?? '',
              'Outstanding': '₹${(c.currentBalance / 100).toStringAsFixed(2)}',
              'Credit Limit': '₹${(c.creditLimit / 100).toStringAsFixed(2)}',
            })
        .toList();

    final totalOutstanding =
        withBalance.fold<int>(0, (sum, c) => sum + c.currentBalance);

    return ReportData(
      type: ReportType.customerBalance,
      title: 'Customer Balance Report',
      description: 'Outstanding customer dues',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Customers with Dues': withBalance.length,
        'Total Outstanding': '₹${(totalOutstanding / 100).toStringAsFixed(2)}',
      },
    );
  }

  Future<ReportData> _loyaltySummaryReport() async {
    final transactions = await _dao.getAllLoyaltyTransactions();
    final allCustomers = await _dao.getAllCustomers();

    final customerLoyalty = <String, Map<String, dynamic>>{};
    for (final txn in transactions) {
      if (!customerLoyalty.containsKey(txn.customerId)) {
        customerLoyalty[txn.customerId] = {
          'Customer': txn.customerName.isNotEmpty
              ? txn.customerName
              : allCustomers
                      .where((c) => c.id == txn.customerId)
                      .firstOrNull
                      ?.name ??
                  'Unknown',
          'Earned': 0,
          'Redeemed': 0,
          'Balance': 0,
        };
      }
      if (txn.transactionType == 'earn') {
        customerLoyalty[txn.customerId]!['Earned'] =
            (customerLoyalty[txn.customerId]!['Earned'] as int) +
                txn.points;
      } else {
        customerLoyalty[txn.customerId]!['Redeemed'] =
            (customerLoyalty[txn.customerId]!['Redeemed'] as int) +
                txn.points;
      }
      customerLoyalty[txn.customerId]!['Balance'] =
          (customerLoyalty[txn.customerId]!['Earned'] as int) -
              (customerLoyalty[txn.customerId]!['Redeemed'] as int);
    }

    final columns = ['Customer', 'Earned', 'Redeemed', 'Balance'];
    final rows = customerLoyalty.values
        .map((e) => {
              'Customer': e['Customer'],
              'Earned': e['Earned'].toString(),
              'Redeemed': e['Redeemed'].toString(),
              'Balance': e['Balance'].toString(),
            })
        .toList();

    final totalEarned = customerLoyalty.values
        .fold<int>(0, (sum, e) => sum + (e['Earned'] as int));
    final totalRedeemed = customerLoyalty.values
        .fold<int>(0, (sum, e) => sum + (e['Redeemed'] as int));

    return ReportData(
      type: ReportType.loyaltySummary,
      title: 'Loyalty Summary Report',
      description: 'Loyalty points earned and redeemed',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Members': customerLoyalty.length,
        'Total Points Earned': totalEarned,
        'Total Points Redeemed': totalRedeemed,
        'Net Points Outstanding': totalEarned - totalRedeemed,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Financial Reports
  // ---------------------------------------------------------------------------

  Future<ReportData> _profitLossReport(DateTime start, DateTime end) async {
    final bills = await _dao.getBillsByDateRange(start, end);
    final purchases = await _dao.getAllPurchases();

    final completedBills = bills
        .where((b) => b.status == 'completed' && !b.isReturn)
        .toList();

    final totalRevenue =
        completedBills.fold<int>(0, (sum, b) => sum + b.totalAmount);
    final totalTax =
        completedBills.fold<int>(0, (sum, b) => sum + b.taxAmount);

    final periodPurchases = purchases
        .where((p) =>
            p.purchaseDate.isAfter(start) && p.purchaseDate.isBefore(end))
        .toList();
    final totalPurchases =
        periodPurchases.fold<int>(0, (sum, p) => sum + p.totalAmount);
    final purchaseTax =
        periodPurchases.fold<int>(0, (sum, p) => sum + p.taxAmount);

    final grossProfit = totalRevenue - totalPurchases;
    final columns = ['Item', 'Amount'];
    final rows = [
      {'Item': 'Revenue (Sales)', 'Amount': '₹${(totalRevenue / 100).toStringAsFixed(2)}'},
      {'Item': 'Cost (Purchases)', 'Amount': '₹${(totalPurchases / 100).toStringAsFixed(2)}'},
      {'Item': 'Gross Profit', 'Amount': '₹${(grossProfit / 100).toStringAsFixed(2)}'},
      {'Item': 'Tax Collected', 'Amount': '₹${(totalTax / 100).toStringAsFixed(2)}'},
      {'Item': 'Tax Paid on Purchases', 'Amount': '₹${(purchaseTax / 100).toStringAsFixed(2)}'},
      {'Item': 'Net Tax Liability', 'Amount': '₹${((totalTax - purchaseTax) / 100).toStringAsFixed(2)}'},
    ];

    return ReportData(
      type: ReportType.profitLoss,
      title: 'Profit & Loss Report',
      description:
          'P&L from ${DateFormat('dd MMM yyyy').format(start)} to ${DateFormat('dd MMM yyyy').format(end)}',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Revenue': '₹${(totalRevenue / 100).toStringAsFixed(2)}',
        'Total Purchases': '₹${(totalPurchases / 100).toStringAsFixed(2)}',
        'Gross Profit': '₹${(grossProfit / 100).toStringAsFixed(2)}',
      },
    );
  }

  Future<ReportData> _gstReport(DateTime start, DateTime end) async {
    final bills = await _dao.getBillsByDateRange(start, end);
    final completedBills =
        bills.where((b) => b.status == 'completed' && !b.isReturn).toList();

    final totalCgst = completedBills.fold<int>(0, (sum, b) => sum + b.cgstAmount);
    final totalSgst = completedBills.fold<int>(0, (sum, b) => sum + b.sgstAmount);
    final totalIgst = completedBills.fold<int>(0, (sum, b) => sum + b.igstAmount);
    final totalTax = completedBills.fold<int>(0, (sum, b) => sum + b.taxAmount);
    final totalTaxable = completedBills.fold<int>(0, (sum, b) => sum + b.subtotal);

    final preMigrationCount = completedBills
        .where((b) => b.taxRuleVersion == 'pre-migration')
        .length;
    final v1Count = completedBills
        .where((b) => b.taxRuleVersion == 'v1')
        .length;

    final columns = [
      'Bill Number',
      'Customer',
      'Taxable',
      'CGST',
      'SGST',
      'IGST',
      'Total Tax',
      'Version',
    ];
    final rows = completedBills
        .map((b) => {
              'Bill Number': b.billNumber,
              'Customer': b.customerName ?? 'Walk-in',
              'Taxable': '₹${(b.subtotal / 100).toStringAsFixed(2)}',
              'CGST': b.cgstAmount > 0 ? '₹${(b.cgstAmount / 100).toStringAsFixed(2)}' : '-',
              'SGST': b.sgstAmount > 0 ? '₹${(b.sgstAmount / 100).toStringAsFixed(2)}' : '-',
              'IGST': b.igstAmount > 0 ? '₹${(b.igstAmount / 100).toStringAsFixed(2)}' : '-',
              'Total Tax': '₹${(b.taxAmount / 100).toStringAsFixed(2)}',
              'Version': b.taxRuleVersion == 'pre-migration' ? 'PRE' : 'v1',
            })
        .toList();

    return ReportData(
      type: ReportType.gstReport,
      title: 'GST Report',
      description: 'Tax collected from ${DateFormat('dd MMM yyyy').format(start)} to ${DateFormat('dd MMM yyyy').format(end)}',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Taxable Amount': '₹${(totalTaxable / 100).toStringAsFixed(2)}',
        'Total CGST': '₹${(totalCgst / 100).toStringAsFixed(2)}',
        'Total SGST': '₹${(totalSgst / 100).toStringAsFixed(2)}',
        'Total IGST': '₹${(totalIgst / 100).toStringAsFixed(2)}',
        'Total Tax Collected': '₹${(totalTax / 100).toStringAsFixed(2)}',
        'Total Bills': completedBills.length,
        'Pre-migration Bills': preMigrationCount,
        'V1 Bills': v1Count,
      },
    );
  }

  Future<ReportData> _expenseReport() async {
    final columns = ['Category', 'Amount', 'Notes'];
    return ReportData(
      type: ReportType.expenseReport,
      title: 'Expense Report',
      description: 'Expense tracking (module under development)',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: const [],
      summary: const {'Message': 'Expense tracking module is under development. Data will appear here once implemented.'},
    );
  }

  // ---------------------------------------------------------------------------
  // Employee Reports
  // ---------------------------------------------------------------------------

  Future<ReportData> _attendanceReport(DateTime start, DateTime end) async {
    final employees = await _dao.getAllEmployees();

    final columns = [
      'Employee',
      'Date',
      'Clock In',
      'Clock Out',
      'Status',
    ];
    final rows = <Map<String, dynamic>>[];

    for (final emp in employees) {
      DateTime day = start;
      while (day.isBefore(end) || day.isAtSameMomentAs(end)) {
        final records = await _dao.getAttendanceByEmployee(emp.id, day);
        for (final rec in records) {
          rows.add({
            'Employee': emp.name,
            'Date': DateFormat('dd MMM yyyy').format(rec.attendanceDate),
            'Clock In':
                rec.clockIn != null ? DateFormat('HH:mm').format(rec.clockIn!) : '-',
            'Clock Out':
                rec.clockOut != null ? DateFormat('HH:mm').format(rec.clockOut!) : '-',
            'Status': rec.status,
          });
        }
        day = day.add(const Duration(days: 1));
      }
    }

    final presentCount = rows.where((r) => r['Status'] == 'present').length;

    return ReportData(
      type: ReportType.attendanceReport,
      title: 'Attendance Report',
      description:
          'Attendance from ${DateFormat('dd MMM yyyy').format(start)} to ${DateFormat('dd MMM yyyy').format(end)}',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Records': rows.length,
        'Present Days': presentCount,
        'Employees': employees.length,
      },
    );
  }

  Future<ReportData> _salesByEmployeeReport(
      DateTime start, DateTime end) async {
    final employees = await _dao.getAllEmployees();
    final bills = await _dao.getBillsByDateRange(start, end);
    final completedBills =
        bills.where((b) => b.status == 'completed' && !b.isReturn).toList();

    final empSales = <String, Map<String, dynamic>>{};
    for (final bill in completedBills) {
      final creator = bill.createdBy;
      if (!empSales.containsKey(creator)) {
        empSales[creator] = {
          'Employee': employees
                  .where((e) => e.id == creator)
                  .firstOrNull
                  ?.name ??
              creator,
          'Bills': 0,
          'Revenue': 0,
        };
      }
      empSales[creator]!['Bills'] = (empSales[creator]!['Bills'] as int) + 1;
      empSales[creator]!['Revenue'] =
          (empSales[creator]!['Revenue'] as int) + bill.totalAmount;
    }

    final sorted = empSales.entries.toList()
      ..sort((a, b) =>
          (b.value['Revenue'] as int).compareTo(a.value['Revenue'] as int));

    final columns = ['Employee', 'Bills Created', 'Total Revenue'];
    final rows = sorted
        .map((e) => {
              'Employee': e.value['Employee'],
              'Bills Created': (e.value['Bills'] as int).toString(),
              'Total Revenue':
                  '₹${((e.value['Revenue'] as int) / 100).toStringAsFixed(2)}',
            })
        .toList();

    final totalRevenue = sorted.fold<int>(
        0, (sum, e) => sum + (e.value['Revenue'] as int));

    return ReportData(
      type: ReportType.salesByEmployee,
      title: 'Sales by Employee Report',
      description: 'Employee-wise sales performance',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Employees': sorted.length,
        'Total Revenue': '₹${(totalRevenue / 100).toStringAsFixed(2)}',
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Purchase Reports
  // ---------------------------------------------------------------------------

  Future<ReportData> _purchaseSummaryReport(
      DateTime start, DateTime end) async {
    final allPurchases = await _dao.getAllPurchases();
    final periodPurchases = allPurchases
        .where((p) =>
            p.purchaseDate.isAfter(start) && p.purchaseDate.isBefore(end))
        .toList();

    final columns = [
      'Purchase Number',
      'Supplier',
      'Amount',
      'Status',
      'Date',
    ];
    final rows = periodPurchases
        .map((p) => {
              'Purchase Number': p.purchaseNumber,
              'Supplier': p.supplierName ?? '',
              'Amount': '₹${(p.totalAmount / 100).toStringAsFixed(2)}',
              'Status': p.status,
              'Date': DateFormat('dd MMM yyyy').format(p.purchaseDate),
            })
        .toList();

    final totalPurchases =
        periodPurchases.fold<int>(0, (sum, p) => sum + p.totalAmount);
    final pendingCount =
        periodPurchases.where((p) => p.status == 'pending').length;

    return ReportData(
      type: ReportType.purchaseSummary,
      title: 'Purchase Summary Report',
      description:
          'Purchases from ${DateFormat('dd MMM yyyy').format(start)} to ${DateFormat('dd MMM yyyy').format(end)}',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Purchases': periodPurchases.length,
        'Total Amount': '₹${(totalPurchases / 100).toStringAsFixed(2)}',
        'Pending Orders': pendingCount,
      },
    );
  }

  Future<ReportData> _supplierWiseReport(DateTime start, DateTime end) async {
    final allPurchases = await _dao.getAllPurchases();
    final suppliers = await _dao.getAllSuppliers();

    final periodPurchases = allPurchases
        .where((p) =>
            p.purchaseDate.isAfter(start) && p.purchaseDate.isBefore(end))
        .toList();

    final supplierData = <String, Map<String, dynamic>>{};
    for (final purchase in periodPurchases) {
      final sid = purchase.supplierId ?? 'unknown';
      if (!supplierData.containsKey(sid)) {
        final supplier =
            suppliers.where((s) => s.id == sid).firstOrNull;
        supplierData[sid] = {
          'Supplier': supplier?.name ?? 'Unknown',
          'Orders': 0,
          'Total Amount': 0,
        };
      }
      supplierData[sid]!['Orders'] =
          (supplierData[sid]!['Orders'] as int) + 1;
      supplierData[sid]!['Total Amount'] =
          (supplierData[sid]!['Total Amount'] as int) +
              purchase.totalAmount;
    }

    final sorted = supplierData.entries.toList()
      ..sort((a, b) => (b.value['Total Amount'] as int)
          .compareTo(a.value['Total Amount'] as int));

    final columns = ['Supplier', 'Orders', 'Total Amount'];
    final rows = sorted
        .map((e) => {
              'Supplier': e.value['Supplier'],
              'Orders': (e.value['Orders'] as int).toString(),
              'Total Amount':
                  '₹${((e.value['Total Amount'] as int) / 100).toStringAsFixed(2)}',
            })
        .toList();

    final totalAmount = sorted.fold<int>(
        0, (sum, e) => sum + (e.value['Total Amount'] as int));

    return ReportData(
      type: ReportType.supplierWise,
      title: 'Supplier-wise Purchase Report',
      description: 'Purchases grouped by supplier',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Suppliers': sorted.length,
        'Total Purchase Amount': '₹${(totalAmount / 100).toStringAsFixed(2)}',
      },
    );
  }

  Future<ReportData> _purchaseVsSalesReport(
      DateTime start, DateTime end) async {
    final bills = await _dao.getBillsByDateRange(start, end);
    final allPurchases = await _dao.getAllPurchases();

    final completedBills =
        bills.where((b) => b.status == 'completed' && !b.isReturn).toList();

    final totalSales =
        completedBills.fold<int>(0, (sum, b) => sum + b.totalAmount);

    final periodPurchases = allPurchases
        .where((p) =>
            p.purchaseDate.isAfter(start) && p.purchaseDate.isBefore(end))
        .toList();
    final totalPurchases =
        periodPurchases.fold<int>(0, (sum, p) => sum + p.totalAmount);

    final margin = totalSales - totalPurchases;
    final marginPercent =
        totalSales > 0 ? (margin / totalSales * 100).toStringAsFixed(1) : '0.0';

    final columns = ['Metric', 'Amount'];
    final rows = [
      {'Metric': 'Total Sales', 'Amount': '₹${(totalSales / 100).toStringAsFixed(2)}'},
      {'Metric': 'Total Purchases', 'Amount': '₹${(totalPurchases / 100).toStringAsFixed(2)}'},
      {'Metric': 'Gross Margin', 'Amount': '₹${(margin / 100).toStringAsFixed(2)}'},
      {'Metric': 'Margin Percentage', 'Amount': '$marginPercent%'},
      {'Metric': 'Sales Transactions', 'Amount': completedBills.length.toString()},
      {'Metric': 'Purchase Transactions', 'Amount': periodPurchases.length.toString()},
    ];

    return ReportData(
      type: ReportType.purchaseVsSales,
      title: 'Purchase vs Sales Report',
      description:
          'Comparison from ${DateFormat('dd MMM yyyy').format(start)} to ${DateFormat('dd MMM yyyy').format(end)}',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total Sales': '₹${(totalSales / 100).toStringAsFixed(2)}',
        'Total Purchases': '₹${(totalPurchases / 100).toStringAsFixed(2)}',
        'Margin': '$marginPercent%',
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HSN-wise GST Summary
  // ---------------------------------------------------------------------------

  Future<ReportData> _hsnGstSummaryReport(
      DateTime start, DateTime end) async {
    final bills = await _dao.getBillsByDateRange(start, end);
    final completedBills =
        bills.where((b) => b.status == 'completed' && !b.isReturn).toList();
    final allProducts = await _dao.getAllProducts();
    final productMap = {for (final p in allProducts) p.id: p};

    final hsnData = <String, Map<String, dynamic>>{};
    for (final bill in completedBills) {
      final items = await _dao.getBillItemsByBillId(bill.id);
      for (final item in items) {
        final product = productMap[item.productId];
        final hsnCode = product?.hsnCode ?? 'UNKNOWN';
        final taxRate = product?.taxRate ?? 0.0;
        final key = '${hsnCode}_${taxRate}';

        if (!hsnData.containsKey(key)) {
          hsnData[key] = {
            'HSN Code': hsnCode,
            'Tax Rate': '${taxRate.toStringAsFixed(1)}%',
            'Quantity': 0.0,
            'Taxable Amount': 0,
            'CGST': 0,
            'SGST': 0,
            'IGST': 0,
            'Total Tax': 0,
            'Total Amount': 0,
            'Items': 0,
          };
        }
        hsnData[key]!['Quantity'] =
            (hsnData[key]!['Quantity'] as double) + item.quantity;
        hsnData[key]!['Taxable Amount'] =
            (hsnData[key]!['Taxable Amount'] as int) + item.totalAmount;
        hsnData[key]!['CGST'] =
            (hsnData[key]!['CGST'] as int) + item.cgstAmount;
        hsnData[key]!['SGST'] =
            (hsnData[key]!['SGST'] as int) + item.sgstAmount;
        hsnData[key]!['IGST'] =
            (hsnData[key]!['IGST'] as int) + item.igstAmount;
        hsnData[key]!['Total Tax'] =
            (hsnData[key]!['Total Tax'] as int) + item.taxAmount;
        hsnData[key]!['Total Amount'] =
            (hsnData[key]!['Total Amount'] as int) + item.totalAmount;
        hsnData[key]!['Items'] = (hsnData[key]!['Items'] as int) + 1;
      }
    }

    final sortedEntries = hsnData.entries.toList()
      ..sort((a, b) => (a.value['HSN Code'] as String)
          .compareTo(b.value['HSN Code'] as String));

    final columns = [
      'HSN Code',
      'Tax Rate',
      'Quantity',
      'Taxable Amount',
      'CGST',
      'SGST',
      'IGST',
      'Total Tax',
      'Total Amount',
    ];
    final rows = sortedEntries
        .map((e) => {
              'HSN Code': e.value['HSN Code'],
              'Tax Rate': e.value['Tax Rate'],
              'Quantity': (e.value['Quantity'] as double).toStringAsFixed(2),
              'Taxable Amount':
                  '₹${((e.value['Taxable Amount'] as int) / 100).toStringAsFixed(2)}',
              'CGST':
                  '₹${((e.value['CGST'] as int) / 100).toStringAsFixed(2)}',
              'SGST':
                  '₹${((e.value['SGST'] as int) / 100).toStringAsFixed(2)}',
              'IGST':
                  '₹${((e.value['IGST'] as int) / 100).toStringAsFixed(2)}',
              'Total Tax':
                  '₹${((e.value['Total Tax'] as int) / 100).toStringAsFixed(2)}',
              'Total Amount':
                  '₹${((e.value['Total Amount'] as int) / 100).toStringAsFixed(2)}',
            })
        .toList();

    final totalTaxable = sortedEntries.fold<int>(
        0, (sum, e) => sum + (e.value['Taxable Amount'] as int));
    final totalCgst = sortedEntries.fold<int>(
        0, (sum, e) => sum + (e.value['CGST'] as int));
    final totalSgst = sortedEntries.fold<int>(
        0, (sum, e) => sum + (e.value['SGST'] as int));
    final totalIgst = sortedEntries.fold<int>(
        0, (sum, e) => sum + (e.value['IGST'] as int));
    final totalTax = sortedEntries.fold<int>(
        0, (sum, e) => sum + (e.value['Total Tax'] as int));
    final totalAmount = sortedEntries.fold<int>(
        0, (sum, e) => sum + (e.value['Total Amount'] as int));

    return ReportData(
      type: ReportType.hsnGstSummary,
      title: 'HSN-wise GST Summary',
      description:
          'HSN-wise tax breakdown from ${DateFormat('dd MMM yyyy').format(start)} to ${DateFormat('dd MMM yyyy').format(end)}',
      generatedAt: DateTime.now(),
      columns: columns,
      rows: rows,
      summary: {
        'Total HSN Codes': sortedEntries.length,
        'Taxable Amount': '₹${(totalTaxable / 100).toStringAsFixed(2)}',
        'Total CGST': '₹${(totalCgst / 100).toStringAsFixed(2)}',
        'Total SGST': '₹${(totalSgst / 100).toStringAsFixed(2)}',
        'Total IGST': '₹${(totalIgst / 100).toStringAsFixed(2)}',
        'Total Tax Collected': '₹${(totalTax / 100).toStringAsFixed(2)}',
        'Grand Total': '₹${(totalAmount / 100).toStringAsFixed(2)}',
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, String>> exportToPdf(ReportData data) async {
    try {
      final pdf = pw.Document();
      final font = pw.Font.helvetica();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(data.title,
                  style: pw.TextStyle(font: font, fontSize: 20)),
            ),
            pw.Text(data.description,
                style: pw.TextStyle(font: font, fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(data.generatedAt)}',
                style: pw.TextStyle(font: font, fontSize: 10)),
            pw.SizedBox(height: 16),
            if (data.summary != null) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: data.summary!.entries
                      .map((e) => pw.Text('${e.key}: ${e.value}',
                          style: pw.TextStyle(font: font, fontSize: 10)))
                      .toList(),
                ),
              ),
              pw.SizedBox(height: 16),
            ],
            if (data.rows.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(font: font, fontSize: 9),
                cellStyle: pw.TextStyle(font: font, fontSize: 8),
                headers: data.columns,
                data: data.rows
                    .map((row) =>
                        data.columns.map((col) => '${row[col] ?? ''}').toList())
                    .toList(),
              )
            else
              pw.Text('No data available',
                  style: pw.TextStyle(font: font, fontSize: 10)),
          ],
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/${data.title.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
      await file.writeAsBytes(await pdf.save());

      return Right(file.path);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> exportToExcel(ReportData data) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln(data.columns.join(','));
      for (final row in data.rows) {
        final values = data.columns
            .map((col) => '"${(row[col] ?? '').toString().replaceAll('"', '""')}"')
            .toList();
        buffer.writeln(values.join(','));
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/${data.title.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv');
      await file.writeAsString(buffer.toString());

      return Right(file.path);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
