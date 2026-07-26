import 'package:equatable/equatable.dart';
import 'sales_order_item_entity.dart';

/// Domain entity representing a sales order in the SS MART ERP system.
///
/// A sales order captures a customer's intent to purchase goods before the
/// actual invoice is generated. It tracks the full lifecycle from draft
/// through confirmation to delivery/completion.
///
/// ## Status Lifecycle
///
/// ```
/// draft → confirmed → dispatched → delivered
///                                    ↓
///                               (converts to Bill)
/// ```
///
/// Orders may also be cancelled at any point before delivery.
///
/// ## Financial Fields
///
/// All monetary values are stored in **paise** (smallest currency unit)
/// to avoid floating-point rounding errors. Divide by 100 for display.
///
/// - [subtotal] — sum of all line-item totals before tax and discount
/// - [taxAmount] — total GST collected on this order
/// - [discountAmount] — order-level discount
/// - [totalAmount] — final amount (subtotal + tax - discount)
///
/// ## Relationships
///
/// - Links to a [Customers] row via [customerId] (nullable for walk-in orders)
/// - Contains multiple [SalesOrderItem] line items
/// - Can be converted to a [Bills] record upon delivery
class SalesOrder extends Equatable {
  /// Unique identifier (UUID) for the sales order.
  final String id;

  /// Human-readable order number (e.g., "SO-20240115-0001").
  final String orderNumber;

  /// Foreign key to the [Customers] table. Null for walk-in/anonymous orders.
  final String? customerId;

  /// Denormalized customer name for display and historical accuracy.
  final String? customerName;

  /// Date when the order was placed by the customer.
  final DateTime orderDate;

  /// Optional expected delivery date promised to the customer.
  final DateTime? expectedDeliveryDate;

  /// Sum of all line-item totals before tax and discount (in paise).
  final int subtotal;

  /// Total tax (GST) amount on the order (in paise).
  final int taxAmount;

  /// Order-level discount amount (in paise).
  final int discountAmount;

  /// Final payable amount: subtotal + tax - discount (in paise).
  final int totalAmount;

  /// Current status of the order: draft, pending, confirmed, dispatched,
  /// delivered, or cancelled.
  final String status;

  /// Optional free-text notes or special instructions from the customer.
  final String? notes;

  /// Employee or system user who created this order.
  final String createdBy;

  /// Timestamp when the order record was first created.
  final DateTime createdAt;

  /// Timestamp of the most recent modification to this order.
  final DateTime updatedAt;

  /// Optimistic concurrency version counter for sync conflict resolution.
  final int version;

  /// Line items attached to this sales order.
  final List<SalesOrderItem> items;

  const SalesOrder({
    required this.id,
    required this.orderNumber,
    this.customerId,
    this.customerName,
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

  /// Whether this order has been confirmed by the business.
  bool get isConfirmed => status == 'confirmed';

  /// Whether this order has been fully delivered to the customer.
  bool get isDelivered => status == 'delivered';

  /// Whether this order has been completed (delivery + billing).
  bool get isCompleted => status == 'completed';

  /// Whether this order was cancelled.
  bool get isCancelled => status == 'cancelled';

  /// Whether this order can be converted to a sales bill.
  bool get canConvertToBill =>
      (status == 'confirmed' || status == 'delivered') && !isCancelled;

  /// Whether this order's status can be changed.
  bool get canUpdateStatus => !isCancelled && !isCompleted;

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        customerId,
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

  /// Creates a copy of this sales order with optional field overrides.
  SalesOrder copyWith({
    String? id,
    String? orderNumber,
    String? customerId,
    String? customerName,
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
    List<SalesOrderItem>? items,
  }) {
    return SalesOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
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
