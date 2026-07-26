import 'package:equatable/equatable.dart';

/// Domain entity representing a single payment transaction.
///
/// Tracks payments received from customers ('receive') and payments
/// made to suppliers ('make'). Each payment can optionally reference
/// a specific bill or purchase order, or be recorded as an advance
/// payment without linking to a specific transaction.
///
/// All monetary values are in paise (smallest currency unit).
class Payment extends Equatable {
  final String id;
  final String paymentNumber;
  final String paymentType; // 'receive' or 'make'
  final String? customerId;
  final String? customerName;
  final String? supplierId;
  final String? supplierName;
  final DateTime paymentDate;
  final int amount;
  final String paymentMode;
  final String? referenceNumber;
  final String? description;
  final String? referenceBillId;
  final String? referencePurchaseOrderId;
  final bool isAdvance;
  final String status;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.paymentNumber,
    required this.paymentType,
    this.customerId,
    this.customerName,
    this.supplierId,
    this.supplierName,
    required this.paymentDate,
    required this.amount,
    this.paymentMode = 'CASH',
    this.referenceNumber,
    this.description,
    this.referenceBillId,
    this.referencePurchaseOrderId,
    this.isAdvance = false,
    this.status = 'completed',
    required this.createdAt,
  });

  String get formattedAmount => '₹${(amount / 100).toStringAsFixed(2)}';
  bool get isReceive => paymentType == 'receive';
  bool get isMake => paymentType == 'make';
  String get partyName => isReceive
      ? (customerName ?? 'Unknown Customer')
      : (supplierName ?? 'Unknown Supplier');

  Payment copyWith({
    String? id,
    String? paymentNumber,
    String? paymentType,
    String? customerId,
    String? customerName,
    String? supplierId,
    String? supplierName,
    DateTime? paymentDate,
    int? amount,
    String? paymentMode,
    String? referenceNumber,
    String? description,
    String? referenceBillId,
    String? referencePurchaseOrderId,
    bool? isAdvance,
    String? status,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      paymentNumber: paymentNumber ?? this.paymentNumber,
      paymentType: paymentType ?? this.paymentType,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      paymentDate: paymentDate ?? this.paymentDate,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      description: description ?? this.description,
      referenceBillId: referenceBillId ?? this.referenceBillId,
      referencePurchaseOrderId: referencePurchaseOrderId ?? this.referencePurchaseOrderId,
      isAdvance: isAdvance ?? this.isAdvance,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id, paymentNumber, paymentType, customerId, customerName,
        supplierId, supplierName, paymentDate, amount, paymentMode,
        referenceNumber, description, isAdvance, status, createdAt,
      ];
}
