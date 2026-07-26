import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';

/// In-memory implementation of [PaymentRepository].
///
/// Stores payments in a local list with sample data for development.
/// Tracks received payments from customers and made payments to suppliers
/// with outstanding balance computation.
class PaymentRepositoryImpl implements PaymentRepository {
  final List<Payment> _payments = [];
  final _uuid = const Uuid();

  PaymentRepositoryImpl() {
    _seedData();
  }

  void _seedData() {
    final now = DateTime.now();
    _payments.addAll([
      Payment(id: _uuid.v4(), paymentNumber: 'PAY-0001', paymentType: 'receive', customerId: 'cust-2', customerName: 'Priya Sharma', paymentDate: now.subtract(const Duration(days: 25)), amount: 50000, paymentMode: 'CASH', description: 'Cash payment for BILL-0001', createdAt: now.subtract(const Duration(days: 25))),
      Payment(id: _uuid.v4(), paymentNumber: 'PAY-0002', paymentType: 'receive', customerId: 'cust-6', customerName: 'Walk-in Customer', paymentDate: now.subtract(const Duration(days: 20)), amount: 16200, paymentMode: 'UPI', description: 'UPI payment for BILL-0002', createdAt: now.subtract(const Duration(days: 20))),
      Payment(id: _uuid.v4(), paymentNumber: 'PAY-0003', paymentType: 'receive', customerId: 'cust-3', customerName: 'Amit Patel', paymentDate: now.subtract(const Duration(days: 15)), amount: 100000, paymentMode: 'BANK', isAdvance: true, description: 'Advance payment from Amit Patel', createdAt: now.subtract(const Duration(days: 15))),
      Payment(id: _uuid.v4(), paymentNumber: 'PAY-0004', paymentType: 'make', supplierId: 'sup-1', supplierName: 'HUL Distributor', paymentDate: now.subtract(const Duration(days: 10)), amount: 500000, paymentMode: 'BANK', description: 'Partial payment to HUL Distributor', createdAt: now.subtract(const Duration(days: 10))),
      Payment(id: _uuid.v4(), paymentNumber: 'PAY-0005', paymentType: 'make', supplierId: 'sup-2', supplierName: 'ITC Foods Distributor', paymentDate: now.subtract(const Duration(days: 5)), amount: 250000, paymentMode: 'CHEQUE', referenceNumber: 'CHQ-0042', description: 'Cheque payment to ITC Foods', createdAt: now.subtract(const Duration(days: 5))),
      Payment(id: _uuid.v4(), paymentNumber: 'PAY-0006', paymentType: 'receive', customerId: 'cust-7', customerName: 'Suresh Traders', paymentDate: now.subtract(const Duration(days: 3)), amount: 200000, paymentMode: 'BANK', description: 'Bank transfer from Suresh Traders', createdAt: now.subtract(const Duration(days: 3))),
    ]);
  }

  @override
  Future<Either<Failure, List<Payment>>> getPayments({
    String? paymentType, String? customerId, String? supplierId,
    DateTime? startDate, DateTime? endDate,
  }) async {
    try {
      var result = List<Payment>.from(_payments)
        ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

      if (paymentType != null) result = result.where((p) => p.paymentType == paymentType).toList();
      if (customerId != null) result = result.where((p) => p.customerId == customerId).toList();
      if (supplierId != null) result = result.where((p) => p.supplierId == supplierId).toList();
      if (startDate != null) result = result.where((p) => p.paymentDate.isAfter(startDate.subtract(const Duration(days: 1)))).toList();
      if (endDate != null) result = result.where((p) => p.paymentDate.isBefore(endDate.add(const Duration(days: 1)))).toList();

      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Payment>> getPaymentById(String id) async {
    try {
      final payment = _payments.firstWhere((p) => p.id == id);
      return Right(payment);
    } catch (e) {
      return Left(ServerFailure(message: 'Payment not found'));
    }
  }

  @override
  Future<Either<Failure, Payment>> createPayment(Payment payment) async {
    try {
      final count = _payments.length;
      final newPayment = payment.copyWith(
        id: payment.id.isEmpty ? _uuid.v4() : payment.id,
        paymentNumber: 'PAY-${(count + 1).toString().padLeft(4, '0')}',
        createdAt: DateTime.now(),
      );
      _payments.add(newPayment);
      return Right(newPayment);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getOutstanding() async {
    try {
      final receivables = _payments
          .where((p) => p.paymentType == 'receive')
          .fold<int>(0, (sum, p) => sum + p.amount);
      final payables = _payments
          .where((p) => p.paymentType == 'make')
          .fold<int>(0, (sum, p) => sum + p.amount);

      return Right({
        'totalReceivable': receivables,
        'totalPayable': payables,
        'netPosition': receivables - payables,
      });
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getPaymentSummary({
    DateTime? startDate, DateTime? endDate,
  }) async {
    try {
      var filtered = List<Payment>.from(_payments);
      if (startDate != null) filtered = filtered.where((p) => p.paymentDate.isAfter(startDate.subtract(const Duration(days: 1)))).toList();
      if (endDate != null) filtered = filtered.where((p) => p.paymentDate.isBefore(endDate.add(const Duration(days: 1)))).toList();

      final totalReceived = filtered.where((p) => p.isReceive).fold<int>(0, (sum, p) => sum + p.amount);
      final totalMade = filtered.where((p) => p.isMake).fold<int>(0, (sum, p) => sum + p.amount);

      return Right({
        'totalReceived': totalReceived,
        'totalMade': totalMade,
        'netCashFlow': totalReceived - totalMade,
        'totalTransactions': filtered.length,
      });
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
