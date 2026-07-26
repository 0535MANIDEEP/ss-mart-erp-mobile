part of 'inventory_bloc.dart';

abstract class InventoryState extends Equatable {
  const InventoryState();

  @override
  List<Object> get props => [];
}

class InventoryInitial extends InventoryState {
  const InventoryInitial();
}

class InventoryLoading extends InventoryState {
  const InventoryLoading();
}

class InventoryLoaded extends InventoryState {
  final List<Stock> stock;

  const InventoryLoaded({required this.stock});

  @override
  List<Object> get props => [stock];
}

/// State emitted after a successful stock adjustment or transfer operation.
class StockOperationSuccess extends InventoryState {
  final String message;
  final Stock stock;

  const StockOperationSuccess({required this.message, required this.stock});

  @override
  List<Object> get props => [message, stock];
}

/// State emitted when a single stock record is loaded successfully.
class StockDetailLoaded extends InventoryState {
  final Stock stock;

  const StockDetailLoaded({required this.stock});

  @override
  List<Object> get props => [stock];
}

/// State emitted when expiring products are loaded successfully.
class ExpiringProductsLoaded extends InventoryState {
  final List<Stock> nearExpiry;
  final List<Stock> expired;

  const ExpiringProductsLoaded({
    required this.nearExpiry,
    required this.expired,
  });

  @override
  List<Object> get props => [nearExpiry, expired];
}

/// State emitted when batch stock records for a product are loaded successfully.
class BatchStockLoaded extends InventoryState {
  final List<Stock> batches;

  const BatchStockLoaded({required this.batches});

  @override
  List<Object> get props => [batches];
}

class InventoryError extends InventoryState {
  final String message;

  const InventoryError({required this.message});

  @override
  List<Object> get props => [message];
}
