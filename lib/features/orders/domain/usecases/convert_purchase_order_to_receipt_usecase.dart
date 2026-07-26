import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../repositories/order_repository.dart';

/// Use case for converting a purchase order into a stock receipt.
///
/// Triggers the conversion workflow: creates a new [Purchases] record from the
/// confirmed/received purchase order, including all line items and financials.
/// Updates inventory stock levels accordingly. Returns the newly created
/// purchase ID on success.
///
/// The purchase order's status is updated to 'completed' after successful
/// conversion. The order must be in 'confirmed' or 'received' status
/// to be eligible for conversion.
class ConvertPurchaseOrderToReceiptUseCase extends UseCase<String, String> {
  final OrderRepository repository;

  ConvertPurchaseOrderToReceiptUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(String orderId) async {
    return await repository.convertPurchaseOrderToReceipt(orderId);
  }
}
