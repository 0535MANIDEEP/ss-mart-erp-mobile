/// Bill Local Data Source — Local persistence layer for sales bills/invoices.
///
/// ## Architecture Role
/// Sits between [BillRepositoryImpl] and the Drift database. Abstracts all
/// details of how bills, line items, and billing counters are stored, queried,
/// and converted to/from domain entities. The repository never touches raw SQL
/// or DAO objects.
///
/// ## Responsibilities
/// - CRUD operations on the [Bills] and [BillItems] tables.
/// - Generating sequential bill/invoice numbers with date-based prefixes.
/// - Aggregating day-sales totals for the dashboard.
/// - Multi-criteria filtering: by customer, date range, status, or combination.
/// - Bidirectional mapping between domain entities ([Bill], [BillItem]) and
///   Drift row/companion objects.
///
/// ## Data Flow
/// ```
/// Repository → BillLocalDataSource → DatabaseDao (Drift) → SQLite
/// ```
///
/// ## Design Decisions
/// - Bill number generation uses a `BILL-YYYYMMDD-NNNN` format. The counter is
///   per-day, resetting at midnight, which provides human-readable, sortable IDs.
///   The 4-digit zero-padded sequence supports up to 9,999 bills per day.
/// - Invoice numbers follow the same format with an `INV-` prefix. Both are
///   generated from the same counter to keep them in sync.
/// - Save operations use delete-and-replace for line items (same pattern as
///   [PurchaseLocalDataSourceImpl]) to ensure consistency without complex diffing.
/// - Multi-criteria filtering fetches from each DAO method separately and
///   intersects the results in memory. This avoids building complex SQL queries
///   for every filter combination while keeping the code maintainable.
/// - Pagination is applied in-memory after sorting by bill date descending.
library;

import '../../../../database/app_database.dart' as db;
import '../../domain/entities/bill_entity.dart';

/// Abstract contract for local bill/invoice persistence.
///
/// The repository layer depends on this interface, not on the concrete
/// implementation, enabling unit testing with fakes/mocks.
abstract class BillLocalDataSource {
  /// Saves a bill and all its line items. Returns the saved bill.
  ///
  /// Existing line items for this bill are deleted and replaced to ensure
  /// consistency with the provided list.
  Future<Bill> saveBill(Bill bill);

  /// Returns a single bill with its line items, or `null` if not found.
  Future<Bill?> getBillById(String id);

  /// Returns a paginated list of bills, optionally filtered by [customerId],
  /// [startDate]/[endDate] range, and/or [status].
  /// Defaults to page 1 with 20 items per page, sorted newest-first.
  Future<List<Bill>> getBills({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int page = 1,
    int perPage = 20,
  });

  /// Returns the total sales amount for a given [date].
  Future<int> getDaySalesTotal(DateTime date);

  /// Returns the most recent [limit] bills (default 10) for the quick-view.
  Future<List<Bill>> getRecentBills({int limit = 10});

  /// Updates only the [status] field of a bill (e.g., "paid", "void", "returned").
  Future<void> updateBillStatus(String billId, String status);

  /// Generates the next sequential bill number for today (e.g., `BILL-20260725-0001`).
  Future<String> getNextBillNumber();

  /// Generates the next sequential invoice number for today (e.g., `INV-20260725-0001`).
  Future<String> getNextInvoiceNumber();

  /// Returns the count of bills created on the given [date].
  Future<int> getBillCountForDate(DateTime date);
}

/// Concrete implementation backed by Drift's [AppDatabase].
///
/// Handles the mapping between domain entities ([Bill], [BillItem]) and their
/// respective Drift row/companion objects. Bills are composite entities: the
/// header maps to [db.Bill] and line items map to [db.BillItem].
class BillLocalDataSourceImpl implements BillLocalDataSource {
  final db.AppDatabase _database;
  late final db.DatabaseDao _dao;

  BillLocalDataSourceImpl({required db.AppDatabase database})
      : _database = database {
    _dao = db.DatabaseDao(_database);
  }

  @override
  Future<Bill> saveBill(Bill bill) async {
    // Step 1: Upsert the bill header.
    final companion = db.BillsCompanion(
      id: db.Value(bill.id),
      billNumber: db.Value(bill.billNumber),
      invoiceNumber: db.Value(bill.invoiceNumber),
      customerId: db.Value(bill.customerId),
      customerName: db.Value(bill.customerName),
      billDate: db.Value(bill.billDate),
      subtotal: db.Value(bill.subtotal),
      taxAmount: db.Value(bill.taxAmount),
      cgstAmount: db.Value(bill.cgstAmount),
      sgstAmount: db.Value(bill.sgstAmount),
      igstAmount: db.Value(bill.igstAmount),
      taxRuleVersion: db.Value(bill.taxRuleVersion),
      discountAmount: db.Value(bill.discountAmount),
      roundOff: db.Value(bill.roundOff),
      totalAmount: db.Value(bill.totalAmount),
      paidAmount: db.Value(bill.paidAmount),
      dueAmount: db.Value(bill.dueAmount),
      paymentMode: db.Value(bill.paymentMode),
      status: db.Value(bill.status),
      isReturn: db.Value(bill.isReturn),
      referenceBillId: db.Value(bill.referenceBillId),
      createdBy: db.Value(bill.createdBy),
      createdAt: db.Value(bill.createdAt),
      updatedAt: db.Value(bill.updatedAt),
      version: db.Value(bill.version),
    );

    await _dao.insertBill(companion);

    // Step 2: Delete-and-replace all line items.
    // Ensures the DB state exactly matches the domain model.
    await _dao.deleteBillItemsByBillId(bill.id);

    // Step 3: Insert each line item with the parent bill's ID.
    for (final item in bill.items) {
      final itemCompanion = db.BillItemsCompanion(
        id: db.Value(item.id),
        billId: db.Value(bill.id),
        productId: db.Value(item.productId),
        productName: db.Value(item.productName),
        quantity: db.Value(item.quantity),
        unitPrice: db.Value(item.unitPrice),
        taxRate: db.Value(item.taxRate),
        discountPercent: db.Value(item.discountPercent),
        discountAmount: db.Value(item.discountAmount),
        taxAmount: db.Value(item.taxAmount),
        cgstAmount: db.Value(item.cgstAmount),
        sgstAmount: db.Value(item.sgstAmount),
        igstAmount: db.Value(item.igstAmount),
        taxRuleVersion: db.Value(item.taxRuleVersion),
        totalAmount: db.Value(item.totalAmount),
        batchNumber: db.Value(item.batchNumber),
      );
      await _dao.insertBillItem(itemCompanion);
    }

    return bill;
  }

  @override
  Future<Bill?> getBillById(String id) async {
    final billData = await _dao.getBillById(id);
    if (billData == null) return null;

    // Load associated line items and map them to domain entities.
    final billItemsData = await _dao.getBillItemsByBillId(id);
    final items = billItemsData.map((db.BillItem item) => _billItemFromData(item)).toList();

    return _billFromData(billData, items);
  }

  @override
  Future<List<Bill>> getBills({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    List<db.Bill> billsData;

    // Multi-criteria filtering: intersect results from separate DAO queries.
    // When multiple filters are active, we fetch from each and keep only
    // bills that appear in all result sets. This is simpler than building
    // a dynamic SQL query for every filter combination.
    if (customerId != null && startDate != null && endDate != null && status != null) {
      final byCustomer = await _dao.getBillsByCustomer(customerId);
      final byDateRange = await _dao.getBillsByDateRange(startDate, endDate);
      // Intersect by ID, then apply status filter.
      final ids = byCustomer.map((b) => b.id).toSet();
      billsData = byDateRange
          .where((b) => ids.contains(b.id) && b.status == status)
          .toList();
    } else if (customerId != null) {
      billsData = await _dao.getBillsByCustomer(customerId);
    } else if (startDate != null && endDate != null) {
      billsData = await _dao.getBillsByDateRange(startDate, endDate);
    } else if (status != null) {
      billsData = await _dao.getBillsByStatus(status);
    } else {
      billsData = await _dao.getAllBills();
    }

    // Sort newest-first for consistent display order.
    billsData.sort((a, b) => b.billDate.compareTo(a.billDate));

    // In-memory pagination.
    final start = (page - 1) * perPage;
    if (start >= billsData.length) return [];
    final end = start + perPage;
    final paged = billsData.sublist(start, end > billsData.length ? billsData.length : end);

    // Load line items for each bill (N+1 pattern, acceptable for typical bill counts).
    final bills = <Bill>[];
    for (final billData in paged) {
      final billItemsData = await _dao.getBillItemsByBillId(billData.id);
      final items = billItemsData.map((db.BillItem item) => _billItemFromData(item)).toList();
      bills.add(_billFromData(billData, items));
    }

    return bills;
  }

  @override
  Future<int> getDaySalesTotal(DateTime date) async {
    return await _dao.getDaySalesTotal(date);
  }

  @override
  Future<List<Bill>> getRecentBills({int limit = 10}) async {
    final billsData = await _dao.getRecentBills(limit: limit);
    final bills = <Bill>[];
    for (final billData in billsData) {
      final billItemsData = await _dao.getBillItemsByBillId(billData.id);
      final items = billItemsData.map((db.BillItem item) => _billItemFromData(item)).toList();
      bills.add(_billFromData(billData, items));
    }
    return bills;
  }

  @override
  Future<void> updateBillStatus(String billId, String status) async {
    await _dao.updateBillStatus(billId, status);
  }

  @override
  Future<String> getNextBillNumber() async {
    final now = DateTime.now();
    // Format date as YYYYMMDD for the bill number prefix.
    final dateKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final count = await _dao.getBillCountForDate(now);
    final nextCount = count + 1;
    // Format: BILL-YYYYMMDD-NNNN (e.g., BILL-20260725-0001).
    return 'BILL-$dateKey-${nextCount.toString().padLeft(4, '0')}';
  }

  @override
  Future<String> getNextInvoiceNumber() async {
    final now = DateTime.now();
    // Same date format and counter as bill numbers to keep them in sync.
    final dateKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final count = await _dao.getBillCountForDate(now);
    final nextCount = count + 1;
    // Format: INV-YYYYMMDD-NNNN (e.g., INV-20260725-0001).
    return 'INV-$dateKey-${nextCount.toString().padLeft(4, '0')}';
  }

  @override
  Future<int> getBillCountForDate(DateTime date) async {
    return await _dao.getBillCountForDate(date);
  }

  /// Converts a Drift [db.Bill] row and pre-mapped [BillItem] list into a
  /// domain [Bill] entity.
  ///
  /// The [items] parameter is already mapped to domain entities to avoid
  /// double-mapping when this method is called from batch-load loops.
  Bill _billFromData(db.Bill data, List<BillItem> items) {
    return Bill(
      id: data.id,
      billNumber: data.billNumber,
      invoiceNumber: data.invoiceNumber,
      customerId: data.customerId,
      customerName: data.customerName,
      billDate: data.billDate,
      subtotal: data.subtotal,
      taxAmount: data.taxAmount,
      cgstAmount: data.cgstAmount,
      sgstAmount: data.sgstAmount,
      igstAmount: data.igstAmount,
      taxRuleVersion: data.taxRuleVersion,
      discountAmount: data.discountAmount,
      roundOff: data.roundOff,
      totalAmount: data.totalAmount,
      paidAmount: data.paidAmount,
      dueAmount: data.dueAmount,
      paymentMode: data.paymentMode,
      status: data.status,
      isReturn: data.isReturn,
      referenceBillId: data.referenceBillId,
      createdBy: data.createdBy,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      version: data.version,
      items: items,
    );
  }

  /// Converts a Drift [db.BillItem] row into a domain [BillItem] entity.
  BillItem _billItemFromData(db.BillItem data) {
    return BillItem(
      id: data.id,
      productId: data.productId,
      productName: data.productName,
      quantity: data.quantity,
      unitPrice: data.unitPrice,
      taxRate: data.taxRate,
      discountPercent: data.discountPercent,
      discountAmount: data.discountAmount,
      taxAmount: data.taxAmount,
      cgstAmount: data.cgstAmount,
      sgstAmount: data.sgstAmount,
      igstAmount: data.igstAmount,
      taxRuleVersion: data.taxRuleVersion,
      totalAmount: data.totalAmount,
      batchNumber: data.batchNumber,
    );
  }
}
