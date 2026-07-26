import 'package:equatable/equatable.dart';

/// Domain entity representing a single line item within a [DeliveryChallan].
///
/// Each item tracks the product dispatched, the quantity requested versus
/// the quantity actually delivered. This distinction allows partial
/// deliveries where not all ordered goods are handed over in one trip.
///
/// All quantities are stored as doubles to support fractional units
/// (e.g., 1.5 KG for weight-based products). The [unit] field provides
/// context for the quantity (e.g., "PCS", "KG", "BOX").
class DeliveryChallanItem extends Equatable {
  /// Unique identifier for this line item (UUID format).
  final String id;

  /// Foreign key to the product being dispatched.
  final String productId;

  /// Denormalized product name for display without JOIN queries.
  final String productName;

  /// Quantity originally ordered or planned for dispatch.
  final double quantity;

  /// Quantity actually delivered/ handed over to the customer.
  /// May differ from [quantity] for partial deliveries.
  final double deliveredQuantity;

  /// Unit of measurement (e.g., "PCS", "KG", "BOX", "LTR").
  final String unit;

  const DeliveryChallanItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.deliveredQuantity = 0,
    this.unit = 'PCS',
  });

  /// Whether the full quantity has been delivered.
  bool get isFullyDelivered => deliveredQuantity >= quantity;

  /// Whether this is a partial delivery.
  bool get isPartialDelivery => deliveredQuantity > 0 && deliveredQuantity < quantity;

  /// Whether no quantity has been delivered yet.
  bool get isPending => deliveredQuantity == 0;

  DeliveryChallanItem copyWith({
    String? id,
    String? productId,
    String? productName,
    double? quantity,
    double? deliveredQuantity,
    String? unit,
  }) {
    return DeliveryChallanItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      deliveredQuantity: deliveredQuantity ?? this.deliveredQuantity,
      unit: unit ?? this.unit,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        quantity,
        deliveredQuantity,
        unit,
      ];
}
