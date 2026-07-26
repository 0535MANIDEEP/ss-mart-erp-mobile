import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../repositories/order_repository.dart';

/// Use case for updating the status of any order (sales or purchase).
///
/// Supports both sales and purchase order status transitions. The caller
/// specifies the [orderType] ('sales' or 'purchase') and the new [status].
///
/// Valid sales order status transitions:
/// - draft → confirmed
/// - confirmed → dispatched → delivered
/// - any → cancelled
///
/// Valid purchase order status transitions:
/// - draft → confirmed
/// - confirmed → received
/// - any → cancelled
class UpdateOrderStatusUseCase extends UseCase<void, UpdateOrderStatusParams> {
  final OrderRepository repository;

  UpdateOrderStatusUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateOrderStatusParams params) async {
    if (params.orderType == 'sales') {
      return await repository.updateSalesOrderStatus(
        params.orderId,
        params.status,
      );
    } else {
      return await repository.updatePurchaseOrderStatus(
        params.orderId,
        params.status,
      );
    }
  }
}

/// Parameters for the [UpdateOrderStatusUseCase].
class UpdateOrderStatusParams {
  /// The unique identifier of the order to update.
  final String orderId;

  /// The type of order: 'sales' or 'purchase'.
  final String orderType;

  /// The new status to set on the order.
  final String status;

  const UpdateOrderStatusParams({
    required this.orderId,
    required this.orderType,
    required this.status,
  });
}
