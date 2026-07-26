import 'package:equatable/equatable.dart';

/// Domain entity representing a sales bill (invoice) generated at the POS.
///
/// A Bill is the primary revenue-generating transaction in the ERP system.
/// It captures the line items sold, applies applicable taxes and discounts,
/// and tracks payment status. Bills can be generated for walk-in customers
/// (anonymous cash sale) or linked to a registered customer for credit tracking.
///
/// The bill number is a human-readable sequential identifier (e.g., "BILL-001234"),
/// while the invoice number is the GST-compliant auto-generated number
/// (used for tax filing). The distinction allows local-only bills without
/// GST compliance for small businesses.
///
/// All monetary values are in paise. The [roundOff] field handles the
/// rounding adjustment between calculated total and nearest integer
/// required by Indian currency conventions.
class Bill extends Equatable {
  /// Unique identifier for the bill (UUID format).
  final String id;

  /// Sequential bill number for display and quick lookup (e.g., "BILL-000001").
  final String billNumber;

  /// GST-compliant invoice number — auto-generated for tax reporting.
  /// Null when no GST invoice is issued (e.g., small business exemption).
  final String? invoiceNumber;

  /// Foreign key to the customer this bill is issued to.
  /// Null for anonymous walk-in cash sales.
  final String? customerId;

  /// Denormalized customer name for display without JOIN queries.
  final String? customerName;

  /// Date of the transaction — determines the accounting period.
  final DateTime billDate;

  /// Sum of all line item amounts before tax and discount, in paise.
  final int subtotal;

  /// Total tax amount across all line items, in paise.
  final int taxAmount;

  /// CGST component of total tax, in paise (intra-state only).
  final int cgstAmount;

  /// SGST component of total tax, in paise (intra-state only).
  final int sgstAmount;

  /// IGST component of total tax, in paise (inter-state only).
  final int igstAmount;

  /// Tax rule version used for this bill's calculations.
  /// 'v1' for new bills, 'pre-migration' for bills created before GST engine.
  final String taxRuleVersion;

  /// Total discount applied at the bill level, in paise.
  final int discountAmount;

  /// Rounding adjustment to nearest integer rupee, in paise.
  /// Can be positive or negative (+1/-1 paise).
  final int roundOff;

  /// Final amount payable by the customer, in paise.
  /// Calculated as: subtotal + taxAmount - discountAmount + roundOff.
  final int totalAmount;

  /// Amount already paid at the time of bill creation, in paise.
  /// For full cash sales this equals [totalAmount].
  final int paidAmount;

  /// Remaining amount owed by the customer, in paise.
  /// Zero for fully paid bills; equals totalAmount for credit sales.
  final int dueAmount;

  /// Payment method used: 'CASH', 'UPI', 'CARD', 'CREDIT', etc.
  final String paymentMode;

  /// Bill status: 'completed', 'pending', 'cancelled', or 'returned'.
  final String status;

  /// Whether this bill represents a return (refund) transaction.
  final bool isReturn;

  /// Foreign key to the original bill this return references.
  /// Null unless [isReturn] is true.
  final String? referenceBillId;

  /// Employee ID of the cashier who created this bill.
  final String createdBy;

  /// Timestamp when the bill record was first created in the system.
  final DateTime createdAt;

  /// Timestamp of the most recent modification to this bill record.
  final DateTime updatedAt;

  /// Optimistic concurrency version counter for sync conflict resolution.
  final int version;

  /// Line items included in this bill.
  final List<BillItem> items;

  const Bill({
    required this.id,
    required this.billNumber,
    this.invoiceNumber,
    this.customerId,
    this.customerName,
    required this.billDate,
    required this.subtotal,
    this.taxAmount = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.taxRuleVersion = 'v1',
    this.discountAmount = 0,
    this.roundOff = 0,
    required this.totalAmount,
    this.paidAmount = 0,
    this.dueAmount = 0,
    this.paymentMode = 'CASH',
    this.status = 'completed',
    this.isReturn = false,
    this.referenceBillId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.items = const [],
  });

  /// Returns true if the bill has been fully paid (no outstanding dues).
  bool get isFullyPaid => dueAmount == 0;

  /// Returns true if a partial payment has been made (some amount still owed).
  bool get isPartialPayment => paidAmount > 0 && dueAmount > 0;

  /// Returns true if the bill was sold on credit terms.
  bool get isCreditSale => paymentMode == 'CREDIT';

  Bill copyWith({
    String? id,
    String? billNumber,
    String? invoiceNumber,
    String? customerId,
    String? customerName,
    DateTime? billDate,
    int? subtotal,
    int? taxAmount,
    int? cgstAmount,
    int? sgstAmount,
    int? igstAmount,
    String? taxRuleVersion,
    int? discountAmount,
    int? roundOff,
    int? totalAmount,
    int? paidAmount,
    int? dueAmount,
    String? paymentMode,
    String? status,
    bool? isReturn,
    String? referenceBillId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    List<BillItem>? items,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      billDate: billDate ?? this.billDate,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      taxRuleVersion: taxRuleVersion ?? this.taxRuleVersion,
      discountAmount: discountAmount ?? this.discountAmount,
      roundOff: roundOff ?? this.roundOff,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      dueAmount: dueAmount ?? this.dueAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      status: status ?? this.status,
      isReturn: isReturn ?? this.isReturn,
      referenceBillId: referenceBillId ?? this.referenceBillId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [
        id, billNumber, invoiceNumber, customerId, customerName,
        billDate, subtotal, taxAmount, cgstAmount, sgstAmount, igstAmount,
        taxRuleVersion, discountAmount, roundOff,
        totalAmount, paidAmount, dueAmount, paymentMode, status,
        isReturn, referenceBillId, createdBy, createdAt, updatedAt,
        version, items,
      ];
}

/// A single line item within a [Bill], representing one product sold.
///
/// BillItem captures the quantity, unit price, applicable tax, and any
/// line-level discounts for a specific product. The [totalAmount] is the
/// final charge for this line item after all calculations.
class BillItem extends Equatable {
  /// Unique identifier for this line item (UUID format).
  final String id;

  /// Foreign key to the product being sold.
  final String productId;

  /// Denormalized product name for display without JOIN queries.
  final String productName;

  /// Quantity sold — supports fractional values for weight-based products (e.g., 1.5 KG).
  final double quantity;

  /// Unit price in paise at the time of sale (may differ from current Product.sellingPrice).
  final int unitPrice;

  /// Tax rate percentage applied to this specific line item.
  final double taxRate;

  /// Line-level discount percentage (0-100).
  final double discountPercent;

  /// Line-level discount amount in paise after percentage calculation.
  final int discountAmount;

  /// Tax amount in paise calculated on this line item's subtotal.
  final int taxAmount;

  /// CGST component in paise (intra-state).
  final int cgstAmount;

  /// SGST component in paise (intra-state).
  final int sgstAmount;

  /// IGST component in paise (inter-state).
  final int igstAmount;

  /// Tax rule version used for this line item's calculations.
  final String taxRuleVersion;

  /// Final charge for this line item in paise: (quantity * unitPrice) - discountAmount + taxAmount.
  final int totalAmount;

  /// Batch/lot number for tracking pharmaceutical or perishable inventory.
  final String? batchNumber;

  /// Expiry date for the batch — used for perishable/pharmaceutical items.
  final DateTime? expiryDate;

  const BillItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.taxRate = 0.0,
    this.discountPercent = 0.0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.taxRuleVersion = 'v1',
    required this.totalAmount,
    this.batchNumber,
    this.expiryDate,
  });

  /// Returns the pre-tax, pre-discount subtotal: unitPrice * quantity, in paise.
  int get subtotal => (unitPrice * quantity).round();

  @override
  List<Object?> get props => [
        id, productId, productName, quantity, unitPrice,
        taxRate, discountPercent, discountAmount, taxAmount,
        cgstAmount, sgstAmount, igstAmount, taxRuleVersion,
        totalAmount, batchNumber, expiryDate,
      ];

  BillItem copyWith({
    String? id,
    String? productId,
    String? productName,
    double? quantity,
    int? unitPrice,
    double? taxRate,
    double? discountPercent,
    int? discountAmount,
    int? taxAmount,
    int? cgstAmount,
    int? sgstAmount,
    int? igstAmount,
    String? taxRuleVersion,
    int? totalAmount,
    String? batchNumber,
    DateTime? expiryDate,
  }) {
    return BillItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate ?? this.taxRate,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      taxRuleVersion: taxRuleVersion ?? this.taxRuleVersion,
      totalAmount: totalAmount ?? this.totalAmount,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }
}
