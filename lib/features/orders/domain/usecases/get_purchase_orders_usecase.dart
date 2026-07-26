import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/purchase_order_entity.dart';
import '../repositories/order_repository.dart';

/// Use case for retrieving all purchase orders with optional filtering.
///
/// Supports filtering by search query (order number or supplier name)
/// and by order status (draft, confirmed, received, etc.).
class GetPurchaseOrdersUseCase
    extends UseCase<List<PurchaseOrder>, GetPurchaseOrdersParams> {
  final OrderRepository repository;

  GetPurchaseOrdersUseCase(this.repository);

  @override
  Future<Either<Failure, List<PurchaseOrder>>> call(
    GetPurchaseOrdersParams params,
  ) async {
    return await repository.getPurchaseOrders(
      search: params.search,
      status: params.status,
    );
  }
}

/// Parameters for the [GetPurchaseOrdersUseCase].
class GetPurchaseOrdersParams {
  /// Optional search term to filter by order number or supplier name.
  final String? search;

  /// Optional status filter (e.g., 'draft', 'confirmed', 'received').
  final String? status;

  const GetPurchaseOrdersParams({this.search, this.status});
}
