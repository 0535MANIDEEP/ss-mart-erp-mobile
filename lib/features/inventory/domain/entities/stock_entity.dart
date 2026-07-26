import 'package:equatable/equatable.dart';

/// Domain entity representing the physical inventory stock of a product at a location.
///
/// Stock entities track the actual quantity of products available across different
/// warehouse locations. The entity supports batch tracking for pharmaceutical
/// and perishable goods, with expiry date monitoring.
///
/// The [reservedQuantity] field accounts for items allocated to pending orders
/// but not yet physically shipped. The [availableQuantity] getter provides
/// the true sellable quantity: [quantity] - [reservedQuantity].
///
/// Stock adjustments are recorded through the [StockRepository.adjustStock]
/// method and synced to the server via the sync queue.
class Stock extends Equatable {
  /// Unique identifier for this stock record (UUID format).
  final String id;

  /// Foreign key to the [Product] this stock record belongs to.
  final String productId;

  /// Denormalized product name for display without JOIN queries.
  final String productName;

  /// Warehouse/storage location identifier (default: 'MAIN' for primary warehouse).
  final String locationId;

  /// Physical quantity on hand at this location — includes both available and reserved.
  final int quantity;

  /// Quantity allocated to pending orders but not yet physically dispatched.
  /// Subtracting this from [quantity] gives the actually available stock.
  final int reservedQuantity;

  /// Batch/lot number for tracking specific production runs or shipments.
  /// Null for products that don't require batch tracking.
  final String? batchNumber;

  /// Expiry date for perishable/pharmaceutical products.
  /// Null for non-expirable items. Used for FIFO rotation and expiry alerts.
  final DateTime? expiryDate;

  /// Timestamp of the most recent stock adjustment or sync.
  final DateTime lastUpdated;

  const Stock({
    required this.id,
    required this.productId,
    required this.productName,
    this.locationId = 'MAIN',
    required this.quantity,
    this.reservedQuantity = 0,
    this.batchNumber,
    this.expiryDate,
    required this.lastUpdated,
  });

  /// Returns the quantity actually available for new orders (not reserved).
  int get availableQuantity => quantity - reservedQuantity;

  /// Returns true if no stock is available for new sales.
  bool get isLowStock => availableQuantity <= 0;

  /// Returns true if this stock record is tracked by batch number.
  bool get hasBatch => batchNumber != null && batchNumber!.isNotEmpty;

  /// Returns true if the product has passed its expiry date.
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Returns true if the product will expire within 30 days — triggers near-expiry alerts.
  bool get isNearExpiry =>
      expiryDate != null && expiryDate!.difference(DateTime.now()).inDays <= 30;

  @override
  List<Object?> get props => [
        id, productId, productName, locationId, quantity,
        reservedQuantity, batchNumber, expiryDate, lastUpdated,
      ];

  Stock copyWith({
    String? id,
    String? productId,
    String? productName,
    String? locationId,
    int? quantity,
    int? reservedQuantity,
    String? batchNumber,
    DateTime? expiryDate,
    DateTime? lastUpdated,
  }) {
    return Stock(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      locationId: locationId ?? this.locationId,
      quantity: quantity ?? this.quantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
