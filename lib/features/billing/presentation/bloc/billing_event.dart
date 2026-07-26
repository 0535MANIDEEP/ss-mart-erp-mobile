part of 'billing_bloc.dart';

abstract class BillingEvent extends Equatable {
  const BillingEvent();

  @override
  List<Object> get props => [];
}

class InitializeBilling extends BillingEvent {
  const InitializeBilling();
}

class AddToCart extends BillingEvent {
  final String productId;
  final String productName;
  final double quantity;
  final int unitPrice;
  final double taxRate;
  final int taxAmount;
  final int totalAmount;
  final String? batchNumber;
  final String? buyerStateCode;

  const AddToCart({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
    this.taxAmount = 0,
    required this.totalAmount,
    this.batchNumber,
    this.buyerStateCode,
  });

  int get subtotal => (unitPrice * quantity).round();

  @override
  List<Object> get props => [
        productId, productName, quantity, unitPrice,
        taxRate, taxAmount, totalAmount, batchNumber ?? '', buyerStateCode ?? '',
      ];
}

class RemoveFromCart extends BillingEvent {
  final String itemId;

  const RemoveFromCart({required this.itemId});

  @override
  List<Object> get props => [itemId];
}

class UpdateCartItemQuantity extends BillingEvent {
  final String itemId;
  final double quantity;

  const UpdateCartItemQuantity({
    required this.itemId,
    required this.quantity,
  });

  @override
  List<Object> get props => [itemId, quantity];
}

class ApplyDiscount extends BillingEvent {
  final double discountPercent;

  const ApplyDiscount({required this.discountPercent});

  @override
  List<Object> get props => [discountPercent];
}

class ApplyItemDiscount extends BillingEvent {
  final String itemId;
  final double discountPercent;
  final int discountAmount;

  const ApplyItemDiscount({
    required this.itemId,
    this.discountPercent = 0,
    this.discountAmount = 0,
  });

  @override
  List<Object> get props => [itemId, discountPercent, discountAmount];
}

class ApplyBillDiscount extends BillingEvent {
  final double discountPercent;
  final int discountAmount;

  const ApplyBillDiscount({
    this.discountPercent = 0,
    this.discountAmount = 0,
  });

  @override
  List<Object> get props => [discountPercent, discountAmount];
}

class SelectBatchForItem extends BillingEvent {
  final String itemId;
  final String batchNumber;
  final DateTime? expiryDate;

  const SelectBatchForItem({
    required this.itemId,
    required this.batchNumber,
    this.expiryDate,
  });

  @override
  List<Object> get props => [itemId, batchNumber, expiryDate ?? ''];
}

class ApplyScheme extends BillingEvent {
  final String schemeType;
  final double value;

  const ApplyScheme({
    required this.schemeType,
    required this.value,
  });

  @override
  List<Object> get props => [schemeType, value];
}

class SelectCustomer extends BillingEvent {
  final String customerId;
  final String customerName;
  final String? customerStateCode;

  const SelectCustomer({
    required this.customerId,
    required this.customerName,
    this.customerStateCode,
  });

  @override
  List<Object> get props => [customerId, customerName, customerStateCode ?? ''];
}

class ClearCustomer extends BillingEvent {
  const ClearCustomer();
}

class ClearCart extends BillingEvent {
  const ClearCart();
}

class ProcessPayment extends BillingEvent {
  final String paymentMode;
  final int paidAmount;
  final String? employeeId;

  const ProcessPayment({
    required this.paymentMode,
    this.paidAmount = 0,
    this.employeeId,
  });

  @override
  List<Object> get props => [paymentMode, paidAmount, employeeId ?? ''];
}

class LoadRecentBills extends BillingEvent {
  final int limit;

  const LoadRecentBills({this.limit = 10});

  @override
  List<Object> get props => [limit];
}
