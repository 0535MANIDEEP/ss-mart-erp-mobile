import 'package:equatable/equatable.dart';
import 'delivery_challan_item.dart';

/// Domain entity representing a delivery challan (delivery note).
///
/// A DeliveryChallan is a transport document accompanying the dispatch of
/// goods from the business premises to the customer. In Indian GST compliance,
/// a challan is mandatory for goods transported without a tax invoice at the
/// time of movement (e.g., for approval, on approval, or for job work).
///
/// ## Status Lifecycle
/// The challan follows a strict status progression:
///   [pending] → [dispatched] → [delivered]
///
/// - **pending**: Challan created but goods not yet loaded onto the vehicle.
/// - **dispatched**: Goods have left the premises with the assigned vehicle/driver.
/// - **delivered**: Customer has received and acknowledged the goods.
///
/// An additional [cancelled] status exists for voided challans.
///
/// ## Linkage
/// A challan may optionally be linked to a [salesOrderId] when goods are
/// dispatched against a pre-existing sales order. Alternatively, items can
/// be added directly to the challan for standalone dispatch scenarios.
///
/// All monetary values (if any) are in paise, following the project convention.
class DeliveryChallan extends Equatable {
  /// Unique identifier for the challan (UUID format).
  final String id;

  /// Sequential challan number for display (e.g., "CH-000001").
  final String challanNumber;

  /// Foreign key to the customer receiving the goods.
  final String customerId;

  /// Denormalized customer name for display without JOIN queries.
  final String customerName;

  /// Optional link to a sales order this challan fulfills.
  final String? salesOrderId;

  /// Date the challan was created / goods are to be dispatched.
  final DateTime challanDate;

  /// Registration number of the vehicle used for transport.
  final String vehicleNumber;

  /// Name of the driver assigned for delivery.
  final String driverName;

  /// Contact phone number of the driver.
  final String driverPhone;

  /// Current status of the challan: 'pending', 'dispatched', 'delivered', 'cancelled'.
  final String status;

  /// Timestamp when the challan record was first created.
  final DateTime createdAt;

  /// Timestamp of the most recent modification to this challan record.
  final DateTime updatedAt;

  /// Optimistic concurrency version counter for sync conflict resolution.
  final int version;

  /// Line items included in this delivery challan.
  final List<DeliveryChallanItem> items;

  const DeliveryChallan({
    required this.id,
    required this.challanNumber,
    required this.customerId,
    required this.customerName,
    this.salesOrderId,
    required this.challanDate,
    required this.vehicleNumber,
    required this.driverName,
    required this.driverPhone,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.items = const [],
  });

  /// Whether the challan is awaiting dispatch.
  bool get isPending => status == 'pending';

  /// Whether goods are in transit.
  bool get isDispatched => status == 'dispatched';

  /// Whether delivery has been confirmed by the customer.
  bool get isDelivered => status == 'delivered';

  /// Whether the challan has been cancelled.
  bool get isCancelled => status == 'cancelled';

  /// Total number of line items in the challan.
  int get itemCount => items.length;

  /// Sum of all ordered quantities across line items.
  double get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  /// Sum of all delivered quantities across line items.
  double get totalDeliveredQuantity =>
      items.fold(0, (sum, item) => sum + item.deliveredQuantity);

  /// Whether all items have been fully delivered.
  bool get isFullyDelivered => items.every((item) => item.isFullyDelivered);

  DeliveryChallan copyWith({
    String? id,
    String? challanNumber,
    String? customerId,
    String? customerName,
    String? salesOrderId,
    DateTime? challanDate,
    String? vehicleNumber,
    String? driverName,
    String? driverPhone,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    List<DeliveryChallanItem>? items,
  }) {
    return DeliveryChallan(
      id: id ?? this.id,
      challanNumber: challanNumber ?? this.challanNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      salesOrderId: salesOrderId ?? this.salesOrderId,
      challanDate: challanDate ?? this.challanDate,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [
        id,
        challanNumber,
        customerId,
        customerName,
        salesOrderId,
        challanDate,
        vehicleNumber,
        driverName,
        driverPhone,
        status,
        createdAt,
        updatedAt,
        version,
        items,
      ];
}
