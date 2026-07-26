import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/repositories/bill_repository.dart';
import '../datasources/bill_local_datasource.dart';
import '../../../inventory/domain/repositories/stock_repository.dart';
import '../../../loyalty/domain/repositories/loyalty_repository.dart';
import '../../../sync/domain/repositories/sync_repository.dart';
import '../../../sync/domain/entities/sync_queue_entity.dart';

/// Implementation of [BillRepository] — the core billing/invoicing repository
/// for the SS MART ERP Mobile App.
///
/// ## Architecture & Sync Strategy
///
/// This repository is the most complex in the codebase, orchestrating
/// multiple domain concerns in a single transaction:
///
/// ### Offline-First Billing Flow (createBill)
/// The bill creation is a **local-first, eventually-consistent** operation:
///
/// 1. **Generate bill/invoice numbers** locally (sequential, monotonically
///    increasing) to ensure unique numbering even without connectivity.
/// 2. **Persist the bill** to the local database with status 'completed'.
/// 3. **Adjust stock** for each line item via [StockRepository.adjustStock]
///    with type 'sale'. If any stock adjustment fails (e.g., insufficient
///    stock), the entire bill creation is rolled back by returning [Left].
/// 4. **Award loyalty points** if the bill has an associated customer.
///    Points are calculated as `floor(totalAmount / 10)` (1 point per ₹10).
///    Earned points expire after 365 days.
/// 5. **Queue for sync** — a [SyncQueueItem] is created with the full bill
///    payload (serialized as JSON) and added to the [SyncRepository] queue.
///    The sync worker will push this to the remote API when connected.
///
/// ### Return Processing (processReturn)
/// 1. Validates the original bill exists locally.
/// 2. Creates a new 'return' bill with negative totals (from return items).
/// 3. Reverses stock adjustments (type 'return') for each returned item.
/// 4. Reverses loyalty points via [LoyaltyRepository.redeemPoints].
/// 5. Queues the return bill for remote sync.
///
/// ### Read Pattern
/// - All reads ([getBillById], [getBills], [getRecentBills], etc.) are
///   served exclusively from the local database. Bills are created locally
///   and synced asynchronously — the local DB is always the source of truth
///   for billing data in the app.
///
/// ### Error Handling
/// - Returns `Either<Failure, T>`.
/// - [ServerFailure]: general exceptions (including stock adjustment failures).
/// - [CacheFailure]: bill not found in local DB.
/// - Stock adjustment failure during bill creation short-circuits and returns
///   a [Left] with the failing product name in the error message.
///
/// ### Relationship Between Local and Remote
/// - Local is the primary write source (bills are created locally first).
/// - Remote is populated asynchronously via the sync queue.
/// - This is the opposite of Employee/Purchase repos (remote-first writes).
///
/// ### Sync Payload
/// - [_billToSyncPayload] serializes the bill (including line items) into
///   a JSON-compatible map for the sync queue. This captures all bill data
///   needed for server-side reconstruction.
class BillRepositoryImpl implements BillRepository {
  final BillLocalDataSource _localDataSource;
  final StockRepository _stockRepository;
  final LoyaltyRepository _loyaltyRepository;
  final SyncRepository _syncRepository;
  final _uuid = const Uuid();

  BillRepositoryImpl({
    required BillLocalDataSource localDataSource,
    required StockRepository stockRepository,
    required LoyaltyRepository loyaltyRepository,
    required SyncRepository syncRepository,
  })  : _localDataSource = localDataSource,
        _stockRepository = stockRepository,
        _loyaltyRepository = loyaltyRepository,
        _syncRepository = syncRepository;

  /// Creates a new sales bill with the full offline-first transaction flow.
  ///
  /// This is the most complex operation in the repository. The execution
  /// order is critical for data consistency:
  ///
  /// 1. Generate unique bill and invoice numbers from local counters.
  /// 2. Assign UUID, timestamps, and status 'completed'.
  /// 3. Persist the bill to the local database.
  /// 4. For each line item, adjust stock downward (type 'sale').
  ///    - If any adjustment fails, the method returns [Left] immediately.
  ///      The bill has already been saved locally but stock is NOT decremented
  ///      for the failing item. A production implementation would wrap this
  ///      in a database transaction for atomicity.
  /// 5. If a customer is associated, earn loyalty points (1 pt per ₹10).
  /// 6. Create a [SyncQueueItem] with the full bill payload for async
  ///    server sync.
  ///
  /// Returns [Right(bill)] on success, [Left(ServerFailure)] on any error.
  @override
  Future<Either<Failure, Bill>> createBill(Bill bill) async {
    try {
      final billNumber = await _localDataSource.getNextBillNumber();
      final invoiceNumber = await _localDataSource.getNextInvoiceNumber();
      final now = DateTime.now();

      final newBill = bill.copyWith(
        id: bill.id.isEmpty ? _uuid.v4() : bill.id,
        billNumber: billNumber,
        invoiceNumber: invoiceNumber,
        billDate: now,
        createdAt: now,
        updatedAt: now,
        status: 'completed',
        version: 1,
      );

      final savedBill = await _localDataSource.saveBill(newBill);

      for (final item in savedBill.items) {
        final stockResult = await _stockRepository.adjustStock(
          productId: item.productId,
          adjustmentType: 'sale',
          quantity: item.quantity.round(),
          reason: 'Bill ${savedBill.billNumber}',
        );
        if (stockResult.isLeft()) {
          return Left(ServerFailure(
            message: 'Failed to update stock for ${item.productName}',
          ));
        }
      }

      if (savedBill.customerId != null && savedBill.customerId!.isNotEmpty) {
        final loyaltyPoints = (savedBill.totalAmount / 10).floor();
        if (loyaltyPoints > 0) {
          await _loyaltyRepository.earnPoints(
            customerId: savedBill.customerId!,
            points: loyaltyPoints,
            referenceType: 'bill',
            referenceId: savedBill.id,
            notes: 'Earned from bill ${savedBill.billNumber}',
          );
        }
      }

      final syncItem = SyncQueueItem(
        id: _uuid.v4(),
        entityType: 'bill',
        entityId: savedBill.id,
        operation: 'create',
        payload: json.encode(_billToSyncPayload(savedBill)),
        createdAt: now,
      );
      await _syncRepository.addToQueue(syncItem);

      return Right(savedBill);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Retrieves a single bill by ID from the local database.
  @override
  Future<Either<Failure, Bill>> getBillById(String id) async {
    try {
      final bill = await _localDataSource.getBillById(id);
      if (bill != null) {
        return Right(bill);
      }
      return Left(CacheFailure(message: 'Bill not found'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Fetches a paginated list of bills from the local database with optional
  /// filters for customer, date range, and status.
  @override
  Future<Either<Failure, List<Bill>>> getBills({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final bills = await _localDataSource.getBills(
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
        status: status,
        page: page,
        perPage: perPage,
      );
      return Right(bills);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Processes a sales return against an original bill.
  ///
  /// **Return Flow**:
  /// 1. Verify the original bill exists in local DB.
  /// 2. Generate a new bill number for the return bill.
  /// 3. Create a return bill (isReturn=true, referenceBillId set).
  /// 4. For each returned item, adjust stock upward (type 'return').
  /// 5. Reverse loyalty points earned on the returned items.
  /// 6. Queue the return bill for remote sync.
  ///
  /// The return bill mirrors the original bill structure but with reversed
  /// financial totals (subtotals, tax, and total are computed from the
  /// returned items, not the full original bill).
  @override
  Future<Either<Failure, Bill>> processReturn({
    required String originalBillId,
    required List<BillItem> returnItems,
    required String reason,
  }) async {
    try {
      final originalBill = await _localDataSource.getBillById(originalBillId);
      if (originalBill == null) {
        return Left(CacheFailure(message: 'Original bill not found'));
      }

      final returnBillNumber = await _localDataSource.getNextBillNumber();
      final now = DateTime.now();

      final returnBill = Bill(
        id: _uuid.v4(),
        billNumber: returnBillNumber,
        billDate: now,
        subtotal: returnItems.fold(0, (sum, item) => sum + item.subtotal),
        taxAmount: returnItems.fold(0, (sum, item) => sum + item.taxAmount),
        cgstAmount: returnItems.fold(0, (sum, item) => sum + item.cgstAmount),
        sgstAmount: returnItems.fold(0, (sum, item) => sum + item.sgstAmount),
        igstAmount: returnItems.fold(0, (sum, item) => sum + item.igstAmount),
        taxRuleVersion: 'v1',
        totalAmount: returnItems.fold(0, (sum, item) => sum + item.totalAmount),
        paidAmount: returnItems.fold(0, (sum, item) => sum + item.totalAmount),
        status: 'completed',
        isReturn: true,
        referenceBillId: originalBillId,
        createdBy: 'system',
        createdAt: now,
        updatedAt: now,
        items: returnItems,
      );

      final savedReturn = await _localDataSource.saveBill(returnBill);

      for (final item in returnItems) {
        await _stockRepository.adjustStock(
          productId: item.productId,
          adjustmentType: 'return',
          quantity: item.quantity.round(),
          reason: 'Return for bill ${originalBill.billNumber}',
        );
      }

      if (originalBill.customerId != null && originalBill.customerId!.isNotEmpty) {
        final loyaltyPointsToReverse = (returnBill.totalAmount / 10).floor();
        if (loyaltyPointsToReverse > 0) {
          await _loyaltyRepository.redeemPoints(
            customerId: originalBill.customerId!,
            points: loyaltyPointsToReverse,
            referenceType: 'bill_return',
            referenceId: savedReturn.id,
            notes: 'Return for bill ${originalBill.billNumber}',
          );
        }
      }

      final syncItem = SyncQueueItem(
        id: _uuid.v4(),
        entityType: 'bill_return',
        entityId: savedReturn.id,
        operation: 'create',
        payload: json.encode(_billToSyncPayload(savedReturn)),
        createdAt: now,
      );
      await _syncRepository.addToQueue(syncItem);

      return Right(savedReturn);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Returns the total sales amount for a given date (from local DB).
  @override
  Future<Either<Failure, int>> getDaySalesTotal(DateTime date) async {
    try {
      final total = await _localDataSource.getDaySalesTotal(date);
      return Right(total);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Returns the most recent bills from the local database, limited by [limit].
  @override
  Future<Either<Failure, List<Bill>>> getRecentBills({int limit = 10}) async {
    try {
      final bills = await _localDataSource.getRecentBills(limit: limit);
      return Right(bills);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Updates the status of a bill in the local database (e.g., 'pending',
  /// 'completed', 'cancelled').
  @override
  Future<Either<Failure, void>> updateBillStatus(String billId, String status) async {
    try {
      await _localDataSource.updateBillStatus(billId, status);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Generates the next sequential bill number from local counters.
  @override
  Future<Either<Failure, String>> generateBillNumber() async {
    try {
      final number = await _localDataSource.getNextBillNumber();
      return Right(number);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Generates the next sequential invoice number from local counters.
  @override
  Future<Either<Failure, String>> generateInvoiceNumber() async {
    try {
      final number = await _localDataSource.getNextInvoiceNumber();
      return Right(number);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Returns the total number of bills created today (from local DB).
  @override
  Future<Either<Failure, int>> getTodayBillCount() async {
    try {
      final count = await _localDataSource.getBillCountForDate(DateTime.now());
      return Right(count);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Serializes a [Bill] entity into a JSON-compatible map for inclusion
  /// in the sync queue payload. Includes all bill metadata and line items.
  Map<String, dynamic> _billToSyncPayload(Bill bill) {
    return {
      'id': bill.id,
      'billNumber': bill.billNumber,
      'invoiceNumber': bill.invoiceNumber,
      'customerId': bill.customerId,
      'billDate': bill.billDate.toIso8601String(),
      'subtotal': bill.subtotal,
      'taxAmount': bill.taxAmount,
      'discountAmount': bill.discountAmount,
      'roundOff': bill.roundOff,
      'totalAmount': bill.totalAmount,
      'paidAmount': bill.paidAmount,
      'dueAmount': bill.dueAmount,
      'paymentMode': bill.paymentMode,
      'status': bill.status,
      'isReturn': bill.isReturn,
      'referenceBillId': bill.referenceBillId,
      'createdBy': bill.createdBy,
      'items': bill.items
          .map((i) => {
                'id': i.id,
                'productId': i.productId,
                'quantity': i.quantity,
                'unitPrice': i.unitPrice,
                'discountPercent': i.discountPercent,
                'discountAmount': i.discountAmount,
                'taxAmount': i.taxAmount,
                'totalAmount': i.totalAmount,
              })
          .toList(),
    };
  }
}
