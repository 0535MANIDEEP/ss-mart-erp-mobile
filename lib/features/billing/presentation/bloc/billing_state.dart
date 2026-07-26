part of 'billing_bloc.dart';

abstract class BillingState extends Equatable {
  const BillingState();

  @override
  List<Object> get props => [];
}

class BillingInitial extends BillingState {
  const BillingInitial();
}

class BillingReady extends BillingState {
  final List<BillItem> items;
  final String? customerId;
  final String customerName;
  final String? customerStateCode;
  final int subtotal;
  final int taxAmount;
  final int discountAmount;
  final int roundOff;
  final int totalAmount;
  final double billDiscountPercent;
  final int billDiscountAmount;

  const BillingReady({
    required this.items,
    this.customerId,
    this.customerName = 'Walk-in Customer',
    this.customerStateCode,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.roundOff = 0,
    this.totalAmount = 0,
    this.billDiscountPercent = 0,
    this.billDiscountAmount = 0,
  });

  int get itemCount => items.length;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity.round());
  bool get hasCustomer => customerId != null && customerId!.isNotEmpty;

  double get totalDiscount {
    final itemDiscounts = items.fold(0, (sum, item) => sum + item.discountAmount);
    return (itemDiscounts + billDiscountAmount).toDouble();
  }

  int get finalTotal {
    final preRoundTotal = subtotal + taxAmount - discountAmount - billDiscountAmount;
    return preRoundTotal.round();
  }

  BillingReady copyWith({
    List<BillItem>? items,
    String? customerId,
    String? customerName,
    String? customerStateCode,
    int? subtotal,
    int? taxAmount,
    int? discountAmount,
    int? roundOff,
    int? totalAmount,
    double? billDiscountPercent,
    int? billDiscountAmount,
  }) {
    return BillingReady(
      items: items ?? this.items,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerStateCode: customerStateCode ?? this.customerStateCode,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      roundOff: roundOff ?? this.roundOff,
      totalAmount: totalAmount ?? this.totalAmount,
      billDiscountPercent: billDiscountPercent ?? this.billDiscountPercent,
      billDiscountAmount: billDiscountAmount ?? this.billDiscountAmount,
    );
  }

  @override
  List<Object> get props => [
        items, customerId ?? '', customerName, customerStateCode ?? '',
        subtotal, taxAmount, discountAmount, roundOff, totalAmount,
        billDiscountPercent, billDiscountAmount,
      ];
}

class BillingProcessing extends BillingState {
  const BillingProcessing();
}

class BillingSuccess extends BillingState {
  final String message;
  final Bill? bill;

  const BillingSuccess({required this.message, this.bill});

  @override
  List<Object> get props => [message, bill ?? ''];
}

class BillingError extends BillingState {
  final String message;

  const BillingError({required this.message});

  @override
  List<Object> get props => [message];
}

class BillingRecentLoaded extends BillingState {
  final List<Bill> bills;

  const BillingRecentLoaded({required this.bills});

  @override
  List<Object> get props => [bills];
}
