part of 'inventory_bloc.dart';

abstract class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object> get props => [];
}

class LoadStock extends InventoryEvent {
  final String? locationId;
  final bool lowStockOnly;

  const LoadStock({this.locationId, this.lowStockOnly = false});

  @override
  List<Object> get props => [locationId ?? '', lowStockOnly];
}

class LoadLowStock extends InventoryEvent {
  const LoadLowStock();
}

/// Event to search stock records by product name or SKU.
class SearchStock extends InventoryEvent {
  final String query;

  const SearchStock({required this.query});

  @override
  List<Object> get props => [query];
}

/// Event to adjust stock quantity for a product.
class AdjustStock extends InventoryEvent {
  final String productId;
  final String adjustmentType;
  final int quantity;
  final String? reason;
  final String? batchNumber;

  const AdjustStock({
    required this.productId,
    required this.adjustmentType,
    required this.quantity,
    this.reason,
    this.batchNumber,
  });

  @override
  List<Object> get props => [productId, adjustmentType, quantity, reason ?? '', batchNumber ?? ''];
}

/// Event to transfer stock between warehouse locations.
class TransferStock extends InventoryEvent {
  final String productId;
  final int quantity;
  final String fromLocationId;
  final String toLocationId;
  final String? batchNumber;

  const TransferStock({
    required this.productId,
    required this.quantity,
    required this.fromLocationId,
    required this.toLocationId,
    this.batchNumber,
  });

  @override
  List<Object> get props => [productId, quantity, fromLocationId, toLocationId, batchNumber ?? ''];
}

/// Event to load stock details for a specific product.
class LoadStockByProductId extends InventoryEvent {
  final String productId;

  const LoadStockByProductId({required this.productId});

  @override
  List<Object> get props => [productId];
}

/// Event to load products expiring within a given number of days.
class LoadExpiringProducts extends InventoryEvent {
  final int daysThreshold;

  const LoadExpiringProducts({this.daysThreshold = 30});

  @override
  List<Object> get props => [daysThreshold];
}

/// Event to load all batch stock records for a specific product.
class LoadBatchStock extends InventoryEvent {
  final String productId;

  const LoadBatchStock({required this.productId});

  @override
  List<Object> get props => [productId];
}
