import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/stock_entity.dart';
import '../repositories/stock_repository.dart';

/// Use case for transferring stock between warehouse locations.
///
/// Atomically decrements from [fromLocationId] and increments at [toLocationId].
class TransferStockUseCase extends UseCase<Stock, TransferStockParams> {
  final StockRepository repository;

  /// Creates an instance of [TransferStockUseCase].
  TransferStockUseCase(this.repository);

  /// Executes the stock transfer.
  @override
  Future<Either<Failure, Stock>> call(TransferStockParams params) async {
    return await repository.transferStock(
      productId: params.productId,
      quantity: params.quantity,
      fromLocationId: params.fromLocationId,
      toLocationId: params.toLocationId,
      batchNumber: params.batchNumber,
    );
  }
}

/// Parameters for transferring stock between locations.
class TransferStockParams {
  /// The product identifier to transfer.
  final String productId;

  /// The quantity to transfer.
  final int quantity;

  /// The source warehouse location identifier.
  final String fromLocationId;

  /// The destination warehouse location identifier.
  final String toLocationId;

  /// Optional batch/lot number for batch-tracked products.
  final String? batchNumber;

  /// Creates [TransferStockParams] with the given transfer details.
  const TransferStockParams({
    required this.productId,
    required this.quantity,
    required this.fromLocationId,
    required this.toLocationId,
    this.batchNumber,
  });
}
