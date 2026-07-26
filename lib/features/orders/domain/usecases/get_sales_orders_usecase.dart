import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/sales_order_entity.dart';
import '../repositories/order_repository.dart';

/// Use case for retrieving all sales orders with optional filtering.
///
/// Supports filtering by search query (order number or customer name)
/// and by order status (draft, confirmed, delivered, etc.).
class GetSalesOrdersUseCase
    extends UseCase<List<SalesOrder>, GetSalesOrdersParams> {
  final OrderRepository repository;

  GetSalesOrdersUseCase(this.repository);

  @override
  Future<Either<Failure, List<SalesOrder>>> call(
    GetSalesOrdersParams params,
  ) async {
    return await repository.getSalesOrders(
      search: params.search,
      status: params.status,
    );
  }
}

/// Parameters for the [GetSalesOrdersUseCase].
class GetSalesOrdersParams {
  /// Optional search term to filter by order number or customer name.
  final String? search;

  /// Optional status filter (e.g., 'draft', 'confirmed', 'delivered').
  final String? status;

  const GetSalesOrdersParams({this.search, this.status});
}
