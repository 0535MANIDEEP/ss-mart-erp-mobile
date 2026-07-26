import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../repositories/order_repository.dart';

/// Use case for converting a sales order into a sales bill.
///
/// Triggers the conversion workflow: creates a new [Bills] record from the
/// confirmed/delivered sales order, including all line items and financials.
/// Returns the newly created bill ID on success.
///
/// The sales order's status is updated to 'completed' after successful
/// conversion. The order must be in 'confirmed' or 'delivered' status
/// to be eligible for conversion.
class ConvertSalesOrderToBillUseCase extends UseCase<String, String> {
  final OrderRepository repository;

  ConvertSalesOrderToBillUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(String orderId) async {
    return await repository.convertSalesOrderToBill(orderId);
  }
}
