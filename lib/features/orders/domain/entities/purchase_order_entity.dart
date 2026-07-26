import 'package:equatable/equatable.dart';
import 'purchase_order_item_entity.dart';

/// Domain entity representing a purchase order in the SS MART ERP system.
///
/// A purchase order captures the business's intent to procure goods from a
/// supplier before the goods are received and a purchase bill is generated.
/// It tracks the full lifecycle from draft through confirmation to receipt.
///
/// ## Status Lifecycle
///
/// ```
/// draft → confirmed → received → completed
///                                  ↓
///                            (converts to Purchase)
/// ```
///
/// Orders may also be cancelled at any point before receipt.
///
/// ## Financial Fields
///
/// All monetary values are stored in **paise** (smallest currency unit)
/// to avoid floating-point rounding errors. Divide by 100 for display.
///
/// - [subtotal] — sum of all line-item totals before tax and discount
/// - [taxAmount] — total GST on this order
/// - [discountAmount] — order-level discount
/// - [totalAmount] — final cost (subtotal + tax - discount)
///
/// ## Relationships
///
/// - Links to a [Suppliers] row via [supplierId] (nullable)
/// - Contains multiple [PurchaseOrderItem] line items
/// - Can be converted to a [Purchases] record upon receipt
class PurchaseOrder extends Equatable {
  /// Unique identifier (UUID) for the purchase order.
  final String id;

  /// Human-readable order number (e.g., "PO-20240115-0001").
  final String orderNumber;

  /// Foreign key to the [Suppliers] table. Null for ad-hoc purchases.
  final String? supplierId;

  /// Denormalized supplier name for display and historical accuracy.
  final String? supplierName;

  /// Date when the order was placed with the supplier.
  final DateTime orderDate;

  /// Optional expected delivery date from the supplier.
  final DateTime? expectedDeliveryDate;

  /// Sum of all line-item totals before tax and discount (in paise).
  final int subtotal;

  /// Total tax (GST) amount on the order (in paise).
  final int taxAmount;

  /// Order-level discount amount (in paise).
  final int discountAmount;

  /// Final payable amount: subtotal + tax - discount (in paise).
  final int totalAmount;

  /// Current status of the order: draft, pending, confirmed, received,
  /// completed, or cancelled.
  final String status;

  /// Optional free-text notes or special instructions for the supplier.
  final String? notes;

  /// Employee or system user who created this order.
  final String createdBy;

  /// Timestamp when the order record was first created.
  final DateTime createdAt;

  /// Timestamp of the most recent modification to this order.
  final DateTime updatedAt;

  /// Optimistic concurrency version counter for sync conflict resolution.
  final int version;

  /// Line items attached to this purchase order.
  final List<PurchaseOrderItem> items;

  const PurchaseOrder({
    required this.id,
    required this.orderNumber,
    this.supplierId,
    this.supplierName,
    required this.orderDate,
    this.expectedDeliveryDate,
    required this.subtotal,
    this.taxAmount = 0,
    this.discountAmount = 0,
    required this.totalAmount,
    this.status = 'draft',
    this.notes,
    this.createdBy = '',
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.items = const [],
  });

  /// Whether this order is still in draft status and can be freely edited.
  bool get isDraft => status == 'draft';

  /// Whether this order has been confirmed with the supplier.
  bool get isConfirmed => status == 'confirmed';

  /// Whether the goods have been received from the supplier.
  bool get isReceived => status == 'received';

  /// Whether this order has been fully received and invoiced.
  bool get isCompleted => status == 'completed';

  /// Whether this order was cancelled.
  bool get isCancelled => status == 'cancelled';

  /// Whether this order can be converted to a purchase bill/receipt.
  bool get canConvertToReceipt =>
      (status == 'confirmed' || status == 'received') && !isCancelled;

  /// Whether this order's status can be changed.
  bool get canUpdateStatus => !isCancelled && !isCompleted;

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        supplierId,
        orderDate,
        expectedDeliveryDate,
        subtotal,
        taxAmount,
        discountAmount,
        totalAmount,
        status,
        notes,
        createdBy,
        createdAt,
        updatedAt,
        version,
        items,
      ];

  /// Creates a copy of this purchase order with optional field overrides.
  PurchaseOrder copyWith({
    String? id,
    String? orderNumber,
    String? supplierId,
    String? supplierName,
    DateTime? orderDate,
    DateTime? expectedDeliveryDate,
    int? subtotal,
    int? taxAmount,
    int? discountAmount,
    int? totalAmount,
    String? status,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    List<PurchaseOrderItem>? items,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      orderDate: orderDate ?? this.orderDate,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      items: items ?? this.items,
    );
  }
}
