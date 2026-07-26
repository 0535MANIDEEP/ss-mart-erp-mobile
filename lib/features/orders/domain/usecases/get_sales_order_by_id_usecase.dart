import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/sales_order_entity.dart';
import '../repositories/order_repository.dart';

/// Use case for retrieving a single sales order by its unique identifier.
///
/// Returns the order header with all line items populated. Used by the
/// detail page and the edit form to display complete order information.
class GetSalesOrderByIdUseCase extends UseCase<SalesOrder, String> {
  final OrderRepository repository;

  GetSalesOrderByIdUseCase(this.repository);

  @override
  Future<Either<Failure, SalesOrder>> call(String id) async {
    return await repository.getSalesOrderById(id);
  }
}
