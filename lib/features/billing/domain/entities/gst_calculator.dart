import 'package:equatable/equatable.dart';

enum TaxType {
  cgstSgst,
  igst,
  exempt,
}

enum TransactionType {
  b2c,
  b2b,
}

class GstBreakdown extends Equatable {
  final double cgstRate;
  final double sgstRate;
  final double igstRate;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTaxAmount;
  final TaxType taxType;

  const GstBreakdown({
    this.cgstRate = 0.0,
    this.sgstRate = 0.0,
    this.igstRate = 0.0,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.igstAmount = 0.0,
    required this.totalTaxAmount,
    required this.taxType,
  });

  factory GstBreakdown.zero() => const GstBreakdown(totalTaxAmount: 0.0, taxType: TaxType.exempt);

  @override
  List<Object?> get props => [
        cgstRate, sgstRate, igstRate,
        cgstAmount, sgstAmount, igstAmount,
        totalTaxAmount, taxType,
      ];

  GstBreakdown copyWith({
    double? cgstRate,
    double? sgstRate,
    double? igstRate,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    double? totalTaxAmount,
    TaxType? taxType,
  }) {
    return GstBreakdown(
      cgstRate: cgstRate ?? this.cgstRate,
      sgstRate: sgstRate ?? this.sgstRate,
      igstRate: igstRate ?? this.igstRate,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      totalTaxAmount: totalTaxAmount ?? this.totalTaxAmount,
      taxType: taxType ?? this.taxType,
    );
  }
}

class TaxCalculationResult extends Equatable {
  final double subtotal;
  final GstBreakdown gstBreakdown;
  final double discountAmount;
  final double roundOff;
  final double totalAmount;

  const TaxCalculationResult({
    required this.subtotal,
    required this.gstBreakdown,
    this.discountAmount = 0.0,
    this.roundOff = 0.0,
    required this.totalAmount,
  });

  @override
  List<Object?> get props => [subtotal, gstBreakdown, discountAmount, roundOff, totalAmount];
}

class GstCalculator {
  static const int _scale = 2;

  static double _round(double value) {
    return double.parse(value.toStringAsFixed(_scale));
  }

  static GstBreakdown calculateGst({
    required double taxableAmount,
    required double taxRate,
    required String sellerStateCode,
    required String buyerStateCode,
    TransactionType transactionType = TransactionType.b2c,
  }) {
    if (taxRate == 0) {
      return GstBreakdown.zero();
    }

    final isInterstate = sellerStateCode != buyerStateCode;
    final halfRate = _round(taxRate / 2);
    final fullRate = taxRate;

    if (isInterstate || transactionType == TransactionType.b2b) {
      final igstAmount = _round(taxableAmount * fullRate / 100);
      return GstBreakdown(
        igstRate: fullRate,
        igstAmount: igstAmount,
        totalTaxAmount: igstAmount,
        taxType: TaxType.igst,
      );
    } else {
      final cgstAmount = _round(taxableAmount * halfRate / 100);
      final sgstAmount = _round(taxableAmount * halfRate / 100);
      return GstBreakdown(
        cgstRate: halfRate,
        sgstRate: halfRate,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
        totalTaxAmount: cgstAmount + sgstAmount,
        taxType: TaxType.cgstSgst,
      );
    }
  }

  static TaxCalculationResult calculateBillTotals({
    required List<BillItemCalculation> items,
    required String sellerStateCode,
    required String buyerStateCode,
    TransactionType transactionType = TransactionType.b2c,
    double discountPercent = 0.0,
    double discountAmount = 0.0,
  }) {
    double subtotal = 0.0;
    double totalCgst = 0.0;
    double totalSgst = 0.0;
    double totalIgst = 0.0;

    for (final item in items) {
      final lineSubtotal = _round(item.quantity * item.unitPrice);
      final taxableAmount = lineSubtotal - item.discountAmount;

      final gst = calculateGst(
        taxableAmount: taxableAmount,
        taxRate: item.taxRate,
        sellerStateCode: sellerStateCode,
        buyerStateCode: buyerStateCode,
        transactionType: transactionType,
      );

      subtotal += lineSubtotal;
      totalCgst += gst.cgstAmount;
      totalSgst += gst.sgstAmount;
      totalIgst += gst.igstAmount;

      item.cgstAmount = gst.cgstAmount;
      item.sgstAmount = gst.sgstAmount;
      item.igstAmount = gst.igstAmount;
      item.taxAmount = gst.totalTaxAmount;
    }

    final calculatedDiscountAmount = discountAmount > 0
        ? discountAmount
        : _round(subtotal * discountPercent / 100);

    final taxableSubtotal = subtotal - calculatedDiscountAmount;
    final totalTax = totalCgst + totalSgst + totalIgst;
    final preRoundTotal = taxableSubtotal + totalTax;
    final roundedTotal = preRoundTotal.round().toDouble();
    final roundOff = _round(roundedTotal - preRoundTotal);

    final taxType = totalIgst > 0 ? TaxType.igst : (totalCgst > 0 ? TaxType.cgstSgst : TaxType.exempt);

    final gstBreakdown = GstBreakdown(
      cgstRate: totalCgst > 0 ? _round((totalCgst / taxableSubtotal) * 100) : 0,
      sgstRate: totalSgst > 0 ? _round((totalSgst / taxableSubtotal) * 100) : 0,
      igstRate: totalIgst > 0 ? _round((totalIgst / taxableSubtotal) * 100) : 0,
      cgstAmount: totalCgst,
      sgstAmount: totalSgst,
      igstAmount: totalIgst,
      totalTaxAmount: totalTax,
      taxType: taxType,
    );

    return TaxCalculationResult(
      subtotal: subtotal,
      gstBreakdown: gstBreakdown,
      discountAmount: calculatedDiscountAmount,
      roundOff: roundOff,
      totalAmount: roundedTotal,
    );
  }

  static double calculateRoundOff(double amount) {
    final rounded = amount.round().toDouble();
    return _round(rounded - amount);
  }
}

class BillItemCalculation {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double taxRate;
  final String hsnCode;
  final double discountPercent;
  double discountAmount = 0;
  double taxAmount = 0;
  double cgstAmount = 0;
  double sgstAmount = 0;
  double igstAmount = 0;

  BillItemCalculation({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
    required this.hsnCode,
    this.discountPercent = 0,
  });

  double get lineTotal => (quantity * unitPrice) + taxAmount - discountAmount;
}