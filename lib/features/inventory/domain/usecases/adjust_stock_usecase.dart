import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/stock_entity.dart';
import '../repositories/stock_repository.dart';

/// Use case for adjusting stock quantity for a product.
///
/// [adjustmentType] categorizes the adjustment: 'purchase_received',
/// 'sale_returned', 'damaged', 'expired', 'manual_correction', etc.
/// [quantity] is the absolute adjustment amount.
/// [reason] provides audit trail context for manual adjustments.
class AdjustStockUseCase extends UseCase<Stock, AdjustStockParams> {
  final StockRepository repository;

  /// Creates an instance of [AdjustStockUseCase].
  AdjustStockUseCase(this.repository);

  /// Executes the stock adjustment.
  @override
  Future<Either<Failure, Stock>> call(AdjustStockParams params) async {
    return await repository.adjustStock(
      productId: params.productId,
      adjustmentType: params.adjustmentType,
      quantity: params.quantity,
      reason: params.reason,
      batchNumber: params.batchNumber,
    );
  }
}

/// Parameters for adjusting stock quantity.
class AdjustStockParams {
  /// The product identifier to adjust stock for.
  final String productId;

  /// The type of adjustment (e.g., 'purchase_received', 'sale_returned', 'damaged').
  final String adjustmentType;

  /// The absolute quantity to adjust.
  final int quantity;

  /// Optional reason for the adjustment (audit trail).
  final String? reason;

  /// Optional batch/lot number for batch-tracked products.
  final String? batchNumber;

  /// Creates [AdjustStockParams] with the given adjustment details.
  const AdjustStockParams({
    required this.productId,
    required this.adjustmentType,
    required this.quantity,
    this.reason,
    this.batchNumber,
  });
}
