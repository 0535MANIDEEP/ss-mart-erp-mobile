import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/purchase_order_entity.dart';
import '../repositories/order_repository.dart';

/// Use case for retrieving a single purchase order by its unique identifier.
///
/// Returns the order header with all line items populated. Used by the
/// detail page and the edit form to display complete order information.
class GetPurchaseOrderByIdUseCase extends UseCase<PurchaseOrder, String> {
  final OrderRepository repository;

  GetPurchaseOrderByIdUseCase(this.repository);

  @override
  Future<Either<Failure, PurchaseOrder>> call(String id) async {
    return await repository.getPurchaseOrderById(id);
  }
}
