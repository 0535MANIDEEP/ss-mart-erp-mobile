import 'package:equatable/equatable.dart';

/// Domain entity representing a purchase order (procurement) from a supplier.
///
/// Purchases track the inbound inventory flow — when stock is ordered from
/// suppliers, received into the warehouse, and recorded in the books.
/// Each purchase has a lifecycle: 'pending' (ordered) → 'received' (stock
/// added to inventory) or 'cancelled'.
///
/// The [receivePurchase] operation in the repository triggers stock level
/// updates in the inventory module, linking purchase receipts to stock adjustments.
///
/// All monetary values are stored in paise (smallest currency unit).
class Purchase extends Equatable {
  /// Unique identifier for the purchase order (UUID format).
  final String id;

  /// Sequential purchase order number for display (e.g., "PO-000001").
  final String purchaseNumber;

  /// Foreign key to the [Supplier] this order was placed with.
  final String? supplierId;

  /// Denormalized supplier name for display without JOIN queries.
  final String? supplierName;

  /// Date the purchase order was placed — determines the accounting period.
  final DateTime purchaseDate;

  /// Sum of all line item amounts before tax, in paise.
  final int subtotal;

  /// Total tax amount across all line items, in paise.
  final int taxAmount;

  /// Final total amount payable to the supplier, in paise.
  final int totalAmount;

  /// Purchase order status: 'pending' (ordered), 'received' (stock added),
  /// or 'cancelled' (order voided).
  final String status;

  /// Timestamp when the purchase record was first created.
  final DateTime createdAt;

  /// Timestamp of the most recent modification to this purchase record.
  final DateTime updatedAt;

  /// Optimistic concurrency version counter for sync conflict resolution.
  final int version;

  /// Line items included in this purchase order.
  final List<PurchaseItem> items;

  const Purchase({
    required this.id,
    required this.purchaseNumber,
    this.supplierId,
    this.supplierName,
    required this.purchaseDate,
    required this.subtotal,
    this.taxAmount = 0,
    required this.totalAmount,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.items = const [],
  });

  /// Returns true if the purchase order is awaiting supplier fulfillment.
  bool get isPending => status == 'pending';

  /// Returns true if the purchase has been received and stock updated.
  bool get isReceived => status == 'received';

  /// Returns true if the purchase order was cancelled before fulfillment.
  bool get isCancelled => status == 'cancelled';

  @override
  List<Object?> get props => [
        id, purchaseNumber, supplierId, supplierName,
        purchaseDate, subtotal, taxAmount, totalAmount,
        status, createdAt, updatedAt, version, items,
      ];
}

/// A single line item within a [Purchase] order, representing one product procured.
///
/// PurchaseItem captures the quantity ordered, unit cost, and applicable tax
/// for a specific product from a supplier. The [totalAmount] represents
/// the final cost for this line item.
class PurchaseItem extends Equatable {
  /// Unique identifier for this line item (UUID format).
  final String id;

  /// Foreign key to the [Product] being procured.
  final String productId;

  /// Denormalized product name for display without JOIN queries.
  final String productName;

  /// Quantity ordered — supports fractional values for weight-based products.
  final double quantity;

  /// Unit cost price in paise at which the supplier agreed to sell.
  final int unitPrice;

  /// Tax rate percentage applied to this line item (GST/IGST).
  final double taxRate;

  /// Tax amount in paise calculated on this line item's subtotal.
  final int taxAmount;

  /// Final cost for this line item in paise: (quantity * unitPrice) + taxAmount.
  final int totalAmount;

  /// Batch/lot number assigned by the supplier for traceability.
  final String? batchNumber;

  const PurchaseItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.taxRate = 0.0,
    this.taxAmount = 0,
    required this.totalAmount,
    this.batchNumber,
  });

  @override
  List<Object?> get props => [
        id, productId, productName, quantity, unitPrice,
        taxRate, taxAmount, totalAmount, batchNumber,
      ];
}
