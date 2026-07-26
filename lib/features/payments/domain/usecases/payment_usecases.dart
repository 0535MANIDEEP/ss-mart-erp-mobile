import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

class GetPaymentsUseCase {
  final PaymentRepository _repository;
  const GetPaymentsUseCase(this._repository);
  Future<Either<Failure, List<Payment>>> call({
    String? paymentType, String? customerId, String? supplierId,
    DateTime? startDate, DateTime? endDate,
  }) => _repository.getPayments(
    paymentType: paymentType, customerId: customerId, supplierId: supplierId,
    startDate: startDate, endDate: endDate,
  );
}

class CreatePaymentUseCase {
  final PaymentRepository _repository;
  const CreatePaymentUseCase(this._repository);
  Future<Either<Failure, Payment>> call(Payment payment) =>
      _repository.createPayment(payment);
}

class GetOutstandingUseCase {
  final PaymentRepository _repository;
  const GetOutstandingUseCase(this._repository);
  Future<Either<Failure, Map<String, dynamic>>> call() =>
      _repository.getOutstanding();
}

class GetPaymentSummaryUseCase {
  final PaymentRepository _repository;
  const GetPaymentSummaryUseCase(this._repository);
  Future<Either<Failure, Map<String, dynamic>>> call({
    DateTime? startDate, DateTime? endDate,
  }) => _repository.getPaymentSummary(startDate: startDate, endDate: endDate);
}
