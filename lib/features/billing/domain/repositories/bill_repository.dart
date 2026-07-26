import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/bill_entity.dart';

/// Abstract repository contract for sales bill (invoice) data operations.
///
/// This interface defines the data access boundary for the billing feature.
/// Bill creation is the primary revenue-generating operation — it atomically
/// creates the bill, deducts stock, accrues loyalty points, and enqueues
/// a sync item (when online is available).
///
/// All methods return [Either<Failure, T>] to enable functional error handling
/// without exceptions, following the Clean Architecture data flow convention.
abstract class BillRepository {
  /// Creates a new sales bill with all line items.
  /// Atomically deducts stock and accrues loyalty points for the customer.
  /// Enqueues a sync item for server upload.
  Future<Either<Failure, Bill>> createBill(Bill bill);

  /// Retrieves a single bill by its unique identifier.
  Future<Either<Failure, Bill>> getBillById(String id);

  /// Retrieves a paginated list of bills with optional filtering.
  ///
  /// [customerId] filters bills for a specific customer.
  /// [startDate] / [endDate] filter bills within a date range.
  /// [status] filters by bill status ('completed', 'pending', 'cancelled').
  Future<Either<Failure, List<Bill>>> getBills({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int page = 1,
    int perPage = 20,
  });

  /// Processes a return (refund) against an original bill.
  /// Restocks returned items and reverses loyalty point accruals.
  Future<Either<Failure, Bill>> processReturn({
    required String originalBillId,
    required List<BillItem> returnItems,
    required String reason,
  });

  /// Calculates the total sales amount for a specific date.
  /// Used by the dashboard for daily sales reporting.
  Future<Either<Failure, int>> getDaySalesTotal(DateTime date);

  /// Retrieves the most recent bills for the quick-access dashboard widget.
  Future<Either<Failure, List<Bill>>> getRecentBills({int limit = 10});

  /// Updates the status of an existing bill (e.g., 'cancelled', 'returned').
  Future<Either<Failure, void>> updateBillStatus(String billId, String status);

  /// Generates the next sequential bill number (e.g., "BILL-000123").
  /// Thread-safe: uses a database transaction to prevent duplicate numbers.
  Future<Either<Failure, String>> generateBillNumber();

  /// Generates a GST-compliant invoice number for tax reporting.
  Future<Either<Failure, String>> generateInvoiceNumber();

  /// Returns the count of bills created today — used for daily summary.
  Future<Either<Failure, int>> getTodayBillCount();
}
