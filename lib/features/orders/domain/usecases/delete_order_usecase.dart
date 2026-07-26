import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../repositories/order_repository.dart';

/// Use case for deleting an order (sales or purchase) by its identifier.
///
/// Hard-deletes the order header and all associated line items from the
/// local database. The sync queue propagates the deletion to the server.
class DeleteOrderUseCase extends UseCase<void, DeleteOrderParams> {
  final OrderRepository repository;

  DeleteOrderUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteOrderParams params) async {
    if (params.orderType == 'sales') {
      return await repository.deleteSalesOrder(params.orderId);
    } else {
      return await repository.deletePurchaseOrder(params.orderId);
    }
  }
}

/// Parameters for the [DeleteOrderUseCase].
class DeleteOrderParams {
  /// The unique identifier of the order to delete.
  final String orderId;

  /// The type of order: 'sales' or 'purchase'.
  final String orderType;

  const DeleteOrderParams({
    required this.orderId,
    required this.orderType,
  });
}
