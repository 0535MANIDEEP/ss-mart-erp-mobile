import 'package:equatable/equatable.dart';

/// Domain entity representing a line item within a [PurchaseOrder].
///
/// Each item captures the product, quantity ordered, pricing, and tax details
/// for a single product on the purchase order. Denormalized product name
/// preserves historical accuracy even if the product master is later modified.
///
/// ## Receiving Tracking
///
/// [receivedQuantity] tracks partial receipts. When the full quantity is
/// received, this equals [quantity]. Partial receipts allow progressive
/// fulfilment of large orders across multiple delivery consignments.
///
/// All monetary values are stored in **paise** (smallest currency unit).
class PurchaseOrderItem extends Equatable {
  /// Unique identifier (UUID) for this line item.
  final String id;

  /// Foreign key linking back to the parent [PurchaseOrder].
  final String orderId;

  /// Foreign key to the [Products] table.
  final String productId;

  /// Denormalized product name for display and historical accuracy.
  final String productName;

  /// Ordered quantity. Supports fractional units (e.g., 1.5 kg).
  final double quantity;

  /// Unit purchase price in paise at the time the order was placed.
  final int unitPrice;

  /// Tax rate percentage applied to this line item (e.g., 18.0 for 18% GST).
  final double taxRate;

  /// Item-level discount amount in paise.
  final int discountAmount;

  /// Total tax amount for this line item in paise.
  final int taxAmount;

  /// Total amount for this line item in paise (qty × unitPrice + tax - discount).
  final int totalAmount;

  /// Optional batch/lot number for batch-tracked inventory items.
  final String? batchNumber;

  /// Quantity that has been received from the supplier so far. Supports
  /// partial receipts. Must be <= [quantity].
  final double receivedQuantity;

  const PurchaseOrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.taxRate = 0.0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    required this.totalAmount,
    this.batchNumber,
    this.receivedQuantity = 0.0,
  });

  /// Whether the full quantity has been received.
  bool get isFullyReceived => receivedQuantity >= quantity;

  /// Whether partial receipt has been made but not yet complete.
  bool get isPartiallyReceived =>
      receivedQuantity > 0 && receivedQuantity < quantity;

  /// Remaining quantity yet to be received from the supplier.
  double get pendingQuantity => quantity - receivedQuantity;

  @override
  List<Object?> get props => [
        id,
        orderId,
        productId,
        productName,
        quantity,
        unitPrice,
        taxRate,
        discountAmount,
        taxAmount,
        totalAmount,
        batchNumber,
        receivedQuantity,
      ];

  /// Creates a copy of this purchase order item with optional field overrides.
  PurchaseOrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? productName,
    double? quantity,
    int? unitPrice,
    double? taxRate,
    int? discountAmount,
    int? taxAmount,
    int? totalAmount,
    String? batchNumber,
    double? receivedQuantity,
  }) {
    return PurchaseOrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate ?? this.taxRate,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      batchNumber: batchNumber ?? this.batchNumber,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
    );
  }
}
