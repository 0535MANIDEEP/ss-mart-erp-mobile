import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/payment.dart';

abstract class PaymentRepository {
  Future<Either<Failure, List<Payment>>> getPayments({
    String? paymentType,
    String? customerId,
    String? supplierId,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Either<Failure, Payment>> getPaymentById(String id);

  Future<Either<Failure, Payment>> createPayment(Payment payment);

  Future<Either<Failure, Map<String, dynamic>>> getOutstanding();

  Future<Either<Failure, Map<String, dynamic>>> getPaymentSummary({
    DateTime? startDate,
    DateTime? endDate,
  });
}
