import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/usecases/get_stock_usecase.dart';
import '../../domain/usecases/adjust_stock_usecase.dart';
import '../../domain/usecases/transfer_stock_usecase.dart';
import '../../domain/usecases/get_stock_by_product_id_usecase.dart';
import '../../domain/usecases/search_stock_usecase.dart';
import '../../domain/usecases/get_expiring_products_usecase.dart';
import '../../domain/usecases/get_batch_stock_usecase.dart';

part 'inventory_event.dart';
part 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final GetStockUseCase getStockUseCase;
  final AdjustStockUseCase adjustStockUseCase;
  final TransferStockUseCase transferStockUseCase;
  final GetStockByProductIdUseCase getStockByProductIdUseCase;
  final SearchStockUseCase searchStockUseCase;
  final GetExpiringProductsUseCase getExpiringProductsUseCase;
  final GetBatchStockUseCase getBatchStockUseCase;

  InventoryBloc({
    required this.getStockUseCase,
    required this.adjustStockUseCase,
    required this.transferStockUseCase,
    required this.getStockByProductIdUseCase,
    required this.searchStockUseCase,
    required this.getExpiringProductsUseCase,
    required this.getBatchStockUseCase,
  }) : super(InventoryInitial()) {
    on<LoadStock>(_onLoadStock);
    on<LoadLowStock>(_onLoadLowStock);
    on<LoadStockByProductId>(_onLoadStockByProductId);
    on<AdjustStock>(_onAdjustStock);
    on<TransferStock>(_onTransferStock);
    on<SearchStock>(_onSearchStock);
    on<LoadExpiringProducts>(_onLoadExpiringProducts);
    on<LoadBatchStock>(_onLoadBatchStock);
  }

  Future<void> _onLoadStock(
    LoadStock event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    final result = await getStockUseCase(
      GetStockParams(
        locationId: event.locationId,
        lowStockOnly: event.lowStockOnly,
      ),
    );
    result.fold(
      (failure) => emit(InventoryError(message: failure.message)),
      (stock) => emit(InventoryLoaded(stock: stock)),
    );
  }

  Future<void> _onLoadLowStock(
    LoadLowStock event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    final result = await getStockUseCase(
      const GetStockParams(lowStockOnly: true),
    );
    result.fold(
      (failure) => emit(InventoryError(message: failure.message)),
      (stock) => emit(InventoryLoaded(stock: stock)),
    );
  }

  Future<void> _onLoadStockByProductId(
    LoadStockByProductId event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    final result = await getStockByProductIdUseCase(event.productId);
    result.fold(
      (failure) => emit(InventoryError(message: failure.message)),
      (stock) => emit(StockDetailLoaded(stock: stock)),
    );
  }

  Future<void> _onAdjustStock(
    AdjustStock event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    final result = await adjustStockUseCase(
      AdjustStockParams(
        productId: event.productId,
        adjustmentType: event.adjustmentType,
        quantity: event.quantity,
        reason: event.reason,
        batchNumber: event.batchNumber,
      ),
    );
    result.fold(
      (failure) => emit(InventoryError(message: failure.message)),
      (stock) => emit(
        StockOperationSuccess(
          message: 'Stock adjusted successfully',
          stock: stock,
        ),
      ),
    );
  }

  Future<void> _onTransferStock(
    TransferStock event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    final result = await transferStockUseCase(
      TransferStockParams(
        productId: event.productId,
        quantity: event.quantity,
        fromLocationId: event.fromLocationId,
        toLocationId: event.toLocationId,
        batchNumber: event.batchNumber,
      ),
    );
    result.fold(
      (failure) => emit(InventoryError(message: failure.message)),
      (stock) => emit(
        StockOperationSuccess(
          message: 'Stock transferred successfully',
          stock: stock,
        ),
      ),
    );
  }

  Future<void> _onSearchStock(
    SearchStock event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    final result = await searchStockUseCase(event.query);
    result.fold(
      (failure) => emit(InventoryError(message: failure.message)),
      (stock) => emit(InventoryLoaded(stock: stock)),
    );
  }

  Future<void> _onLoadExpiringProducts(
    LoadExpiringProducts event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    final result = await getExpiringProductsUseCase(
      ExpiringProductsParams(daysThreshold: event.daysThreshold),
    );
    result.fold(
      (failure) => emit(InventoryError(message: failure.message)),
      (data) => emit(
        ExpiringProductsLoaded(
          nearExpiry: data,
          expired: const [],
        ),
      ),
    );
  }

  Future<void> _onLoadBatchStock(
    LoadBatchStock event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    final result = await getBatchStockUseCase(event.productId);
    result.fold(
      (failure) => emit(InventoryError(message: failure.message)),
      (batches) => emit(BatchStockLoaded(batches: batches)),
    );
  }
}
