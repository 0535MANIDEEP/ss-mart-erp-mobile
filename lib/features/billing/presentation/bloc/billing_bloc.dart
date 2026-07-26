import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/gst_calculator.dart';
import '../../domain/usecases/bill_usecases.dart';
import '../../../customers/domain/usecases/get_customer_by_id_usecase.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final CreateBillUseCase _createBillUseCase;
  final GetRecentBillsUseCase _getRecentBillsUseCase;
  final GetCustomerByIdUseCase _getCustomerByIdUseCase;

  // Default seller state code (company's state - Karnataka = 29)
  static const String _defaultSellerStateCode = '29';

  BillingBloc({
    required CreateBillUseCase createBillUseCase,
    required GetRecentBillsUseCase getRecentBillsUseCase,
    required GetCustomerByIdUseCase getCustomerByIdUseCase,
  })  : _createBillUseCase = createBillUseCase,
        _getRecentBillsUseCase = getRecentBillsUseCase,
        _getCustomerByIdUseCase = getCustomerByIdUseCase,
        super(BillingInitial()) {
    on<InitializeBilling>(_onInitializeBilling);
    on<AddToCart>(_onAddToCart);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<UpdateCartItemQuantity>(_onUpdateCartItemQuantity);
    on<ApplyDiscount>(_onApplyDiscount);
    on<ApplyItemDiscount>(_onApplyItemDiscount);
    on<ApplyBillDiscount>(_onApplyBillDiscount);
    on<SelectBatchForItem>(_onSelectBatchForItem);
    on<ApplyScheme>(_onApplyScheme);
    on<SelectCustomer>(_onSelectCustomer);
    on<ClearCustomer>(_onClearCustomer);
    on<ClearCart>(_onClearCart);
    on<ProcessPayment>(_onProcessPayment);
    on<LoadRecentBills>(_onLoadRecentBills);
  }

  void _onInitializeBilling(InitializeBilling event, Emitter<BillingState> emit) {
    emit(const BillingReady(
      items: [],
      customerId: null,
      customerName: 'Walk-in Customer',
      customerStateCode: null,
      subtotal: 0,
      taxAmount: 0,
      discountAmount: 0,
      roundOff: 0,
      totalAmount: 0,
    ));
  }

  void _onAddToCart(AddToCart event, Emitter<BillingState> emit) {
    final currentState = state;
    if (currentState is! BillingReady) {
      final cartItem = _buildCartItem(event);
      emit(BillingReady(
        items: [cartItem],
        customerId: null,
        customerName: 'Walk-in Customer',
        subtotal: cartItem.subtotal,
        taxAmount: cartItem.taxAmount,
        discountAmount: 0,
        roundOff: 0,
        totalAmount: cartItem.totalAmount,
      ));
      return;
    }

    final existingIndex = currentState.items.indexWhere(
      (item) => item.productId == event.productId,
    );

    if (existingIndex >= 0) {
      final updatedItems = List<BillItem>.from(currentState.items);
      final existingItem = updatedItems[existingIndex];
      final newQuantity = existingItem.quantity + event.quantity;

      // Recalculate tax for the combined quantity
      final gstBreakdown = GstCalculator.calculateGst(
        taxableAmount: existingItem.unitPrice * newQuantity,
        taxRate: event.taxRate,
        sellerStateCode: _defaultSellerStateCode,
        buyerStateCode: currentState.customerStateCode ?? _defaultSellerStateCode,
      );

      final newTaxAmount = gstBreakdown.totalTaxAmount.round();
      final newTotalAmount = (existingItem.unitPrice * newQuantity).round() + newTaxAmount;

      updatedItems[existingIndex] = BillItem(
        id: existingItem.id,
        productId: existingItem.productId,
        productName: existingItem.productName,
        quantity: newQuantity,
        unitPrice: existingItem.unitPrice,
        discountPercent: existingItem.discountPercent,
        discountAmount: existingItem.discountAmount,
        taxAmount: newTaxAmount,
        cgstAmount: gstBreakdown.cgstAmount.round(),
        sgstAmount: gstBreakdown.sgstAmount.round(),
        igstAmount: gstBreakdown.igstAmount.round(),
        taxRuleVersion: 'v1',
        totalAmount: newTotalAmount,
        batchNumber: existingItem.batchNumber,
      );

      emit(_recalculateTotals(currentState.copyWith(items: updatedItems)));
    } else {
      final cartItem = _buildCartItem(event);
      final updatedItems = [...currentState.items, cartItem];
      emit(_recalculateTotals(currentState.copyWith(items: updatedItems)));
    }
  }

  void _onRemoveFromCart(RemoveFromCart event, Emitter<BillingState> emit) {
    final currentState = state;
    if (currentState is BillingReady) {
      final updatedItems = currentState.items
          .where((item) => item.id != event.itemId)
          .toList();
      emit(_recalculateTotals(currentState.copyWith(items: updatedItems)));
    }
  }

  void _onUpdateCartItemQuantity(
    UpdateCartItemQuantity event,
    Emitter<BillingState> emit,
  ) {
    final currentState = state;
    if (currentState is BillingReady) {
      final updatedItems = currentState.items.map((item) {
        if (item.id == event.itemId) {
          final newQuantity = event.quantity;
          final subtotal = (item.unitPrice * newQuantity).round();
          final discount = ((item.unitPrice * newQuantity * item.discountPercent) / 100).round();
          final taxableAmount = subtotal - discount;

          final gstBreakdown = GstCalculator.calculateGst(
            taxableAmount: taxableAmount.toDouble(),
            taxRate: item.taxRate,
            sellerStateCode: _defaultSellerStateCode,
            buyerStateCode: currentState.customerStateCode ?? _defaultSellerStateCode,
          );

          final newTax = gstBreakdown.totalTaxAmount.round();
          final newTotal = taxableAmount + newTax;

          return BillItem(
            id: item.id,
            productId: item.productId,
            productName: item.productName,
            quantity: newQuantity,
            unitPrice: item.unitPrice,
            taxRate: item.taxRate,
            discountPercent: item.discountPercent,
            discountAmount: discount,
            taxAmount: newTax,
            cgstAmount: gstBreakdown.cgstAmount.round(),
            sgstAmount: gstBreakdown.sgstAmount.round(),
            igstAmount: gstBreakdown.igstAmount.round(),
            taxRuleVersion: 'v1',
            totalAmount: newTotal,
            batchNumber: item.batchNumber,
            expiryDate: item.expiryDate,
          );
        }
        return item;
      }).toList();
      emit(_recalculateTotals(currentState.copyWith(items: updatedItems)));
    }
  }

  void _onApplyDiscount(ApplyDiscount event, Emitter<BillingState> emit) {
    final currentState = state;
    if (currentState is BillingReady) {
      final updatedItems = currentState.items.map((item) {
        final discount = (item.unitPrice * item.quantity * event.discountPercent / 100).round();
        final subtotal = item.subtotal;
        final taxableAmount = subtotal - discount;

        final gstBreakdown = GstCalculator.calculateGst(
          taxableAmount: taxableAmount.toDouble(),
          taxRate: item.taxRate,
          sellerStateCode: _defaultSellerStateCode,
          buyerStateCode: currentState.customerStateCode ?? _defaultSellerStateCode,
        );

        final newTax = gstBreakdown.totalTaxAmount.round();
        final newTotal = taxableAmount + newTax;

        return BillItem(
          id: item.id,
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          taxRate: item.taxRate,
          discountPercent: event.discountPercent,
          discountAmount: discount,
          taxAmount: newTax,
          cgstAmount: gstBreakdown.cgstAmount.round(),
          sgstAmount: gstBreakdown.sgstAmount.round(),
          igstAmount: gstBreakdown.igstAmount.round(),
          taxRuleVersion: 'v1',
          totalAmount: newTotal,
          batchNumber: item.batchNumber,
          expiryDate: item.expiryDate,
        );
      }).toList();
      emit(_recalculateTotals(currentState.copyWith(items: updatedItems)));
    }
  }

  void _onApplyItemDiscount(ApplyItemDiscount event, Emitter<BillingState> emit) {
    final currentState = state;
    if (currentState is BillingReady) {
      final updatedItems = currentState.items.map((item) {
        if (item.id == event.itemId) {
          int discount;
          double discountPct;

          if (event.discountAmount > 0) {
            discount = event.discountAmount;
            discountPct = (discount / (item.unitPrice * item.quantity) * 100);
          } else {
            discountPct = event.discountPercent;
            discount = (item.unitPrice * item.quantity * event.discountPercent / 100).round();
          }

          final subtotal = item.subtotal;
          final taxableAmount = subtotal - discount;

          final gstBreakdown = GstCalculator.calculateGst(
            taxableAmount: taxableAmount.toDouble(),
            taxRate: item.taxRate,
            sellerStateCode: _defaultSellerStateCode,
            buyerStateCode: currentState.customerStateCode ?? _defaultSellerStateCode,
          );

          final newTax = gstBreakdown.totalTaxAmount.round();
          final newTotal = taxableAmount + newTax;

          return BillItem(
            id: item.id,
            productId: item.productId,
            productName: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            taxRate: item.taxRate,
            discountPercent: discountPct,
            discountAmount: discount,
            taxAmount: newTax,
            cgstAmount: gstBreakdown.cgstAmount.round(),
            sgstAmount: gstBreakdown.sgstAmount.round(),
            igstAmount: gstBreakdown.igstAmount.round(),
            taxRuleVersion: 'v1',
            totalAmount: newTotal,
            batchNumber: item.batchNumber,
            expiryDate: item.expiryDate,
          );
        }
        return item;
      }).toList();
      emit(_recalculateTotals(currentState.copyWith(items: updatedItems)));
    }
  }

  void _onApplyBillDiscount(ApplyBillDiscount event, Emitter<BillingState> emit) {
    final currentState = state;
    if (currentState is BillingReady) {
      int billDiscountAmt;
      double billDiscountPct;

      if (event.discountAmount > 0) {
        billDiscountAmt = event.discountAmount;
        billDiscountPct = (billDiscountAmt / currentState.subtotal * 100);
      } else {
        billDiscountPct = event.discountPercent;
        billDiscountAmt = (currentState.subtotal * event.discountPercent / 100).round();
      }

      final preRoundTotal = currentState.subtotal + currentState.taxAmount - currentState.discountAmount - billDiscountAmt;
      final roundedTotal = preRoundTotal.round();
      final roundOffVal = roundedTotal - preRoundTotal;

      emit(currentState.copyWith(
        billDiscountPercent: billDiscountPct,
        billDiscountAmount: billDiscountAmt,
        roundOff: roundOffVal,
        totalAmount: roundedTotal,
      ));
    }
  }

  void _onSelectBatchForItem(SelectBatchForItem event, Emitter<BillingState> emit) {
    final currentState = state;
    if (currentState is BillingReady) {
      final updatedItems = currentState.items.map((item) {
        if (item.id == event.itemId) {
          return BillItem(
            id: item.id,
            productId: item.productId,
            productName: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            taxRate: item.taxRate,
            discountPercent: item.discountPercent,
            discountAmount: item.discountAmount,
            taxAmount: item.taxAmount,
            cgstAmount: item.cgstAmount,
            sgstAmount: item.sgstAmount,
            igstAmount: item.igstAmount,
            taxRuleVersion: item.taxRuleVersion,
            totalAmount: item.totalAmount,
            batchNumber: event.batchNumber,
            expiryDate: event.expiryDate,
          );
        }
        return item;
      }).toList();
      emit(currentState.copyWith(items: updatedItems));
    }
  }

  void _onApplyScheme(ApplyScheme event, Emitter<BillingState> emit) {
    final currentState = state;
    if (currentState is BillingReady) {
      switch (event.schemeType) {
        case 'BUY_X_GET_Y_FREE':
          final buyQty = event.value.toInt();
          final freeQty = 1;
          final updatedItems = currentState.items.map((item) {
            final totalQty = item.quantity.toInt();
            if (totalQty >= buyQty + freeQty) {
              final freeItems = (totalQty ~/ (buyQty + freeQty)) * freeQty;
              final paidQty = totalQty - freeItems;
              final subtotal = (item.unitPrice * paidQty).round();
              final discount = item.discountAmount;
              final taxableAmount = subtotal - discount;

              final gstBreakdown = GstCalculator.calculateGst(
                taxableAmount: taxableAmount.toDouble(),
                taxRate: item.taxRate,
                sellerStateCode: _defaultSellerStateCode,
                buyerStateCode: currentState.customerStateCode ?? _defaultSellerStateCode,
              );

              final newTax = gstBreakdown.totalTaxAmount.round();
              final newTotal = taxableAmount + newTax;

              return BillItem(
                id: item.id,
                productId: item.productId,
                productName: item.productName,
                quantity: paidQty.toDouble(),
                unitPrice: item.unitPrice,
                taxRate: item.taxRate,
                discountPercent: item.discountPercent,
                discountAmount: discount,
                taxAmount: newTax,
                cgstAmount: gstBreakdown.cgstAmount.round(),
                sgstAmount: gstBreakdown.sgstAmount.round(),
                igstAmount: gstBreakdown.igstAmount.round(),
                taxRuleVersion: 'v1',
                totalAmount: newTotal,
                batchNumber: item.batchNumber,
                expiryDate: item.expiryDate,
              );
            }
            return item;
          }).toList();
          emit(_recalculateTotals(currentState.copyWith(items: updatedItems)));
          break;

        case 'FLAT_DISCOUNT':
          final flatDiscount = event.value.toInt();
          final totalItemDiscount = currentState.items.fold(0, (sum, item) => sum + item.discountAmount);
          final newBillDiscount = flatDiscount - totalItemDiscount;
          if (newBillDiscount > 0) {
            final preRoundTotal = currentState.subtotal + currentState.taxAmount - currentState.discountAmount - newBillDiscount;
            final roundedTotal = preRoundTotal.round();
            final roundOffVal = roundedTotal - preRoundTotal;
            emit(currentState.copyWith(
              billDiscountPercent: (newBillDiscount / currentState.subtotal * 100),
              billDiscountAmount: newBillDiscount,
              roundOff: roundOffVal,
              totalAmount: roundedTotal,
            ));
          }
          break;

        case 'PERCENTAGE_DISCOUNT':
          final pctDiscount = event.value;
          final billDiscount = (currentState.subtotal * pctDiscount / 100).round();
          final preRoundTotal = currentState.subtotal + currentState.taxAmount - currentState.discountAmount - billDiscount;
          final roundedTotal = preRoundTotal.round();
          final roundOffVal = roundedTotal - preRoundTotal;
          emit(currentState.copyWith(
            billDiscountPercent: pctDiscount,
            billDiscountAmount: billDiscount,
            roundOff: roundOffVal,
            totalAmount: roundedTotal,
          ));
          break;

        default:
          break;
      }
    }
  }

  void _onSelectCustomer(SelectCustomer event, Emitter<BillingState> emit) {
    final currentState = state;
    if (currentState is BillingReady) {
      // Recalculate all items with new customer state code
      final updatedItems = currentState.items.map((item) {
        final subtotal = item.subtotal;
        final discount = item.discountAmount;
        final taxableAmount = subtotal - discount;

        final gstBreakdown = GstCalculator.calculateGst(
          taxableAmount: taxableAmount.toDouble(),
          taxRate: item.taxRate,
          sellerStateCode: _defaultSellerStateCode,
          buyerStateCode: event.customerStateCode ?? _defaultSellerStateCode,
        );

        final newTax = gstBreakdown.totalTaxAmount.round();
        final newTotal = taxableAmount + newTax;

        return BillItem(
          id: item.id,
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          taxRate: item.taxRate,
          discountPercent: item.discountPercent,
          discountAmount: item.discountAmount,
          taxAmount: newTax,
          cgstAmount: gstBreakdown.cgstAmount.round(),
          sgstAmount: gstBreakdown.sgstAmount.round(),
          igstAmount: gstBreakdown.igstAmount.round(),
          taxRuleVersion: 'v1',
          totalAmount: newTotal,
          batchNumber: item.batchNumber,
          expiryDate: item.expiryDate,
        );
      }).toList();

      emit(_recalculateTotals(currentState.copyWith(
        items: updatedItems,
        customerId: event.customerId,
        customerName: event.customerName,
        customerStateCode: event.customerStateCode,
      )));
    } else {
      emit(BillingReady(
        items: const [],
        customerId: event.customerId,
        customerName: event.customerName,
        customerStateCode: event.customerStateCode,
      ));
    }
  }

  void _onClearCustomer(ClearCustomer event, Emitter<BillingState> emit) {
    final currentState = state;
    if (currentState is BillingReady) {
      // Recalculate with default state code (intra-state)
      final updatedItems = currentState.items.map((item) {
        final subtotal = item.subtotal;
        final discount = item.discountAmount;
        final taxableAmount = subtotal - discount;

        final gstBreakdown = GstCalculator.calculateGst(
          taxableAmount: taxableAmount.toDouble(),
          taxRate: item.taxRate,
          sellerStateCode: _defaultSellerStateCode,
          buyerStateCode: _defaultSellerStateCode,
        );

        final newTax = gstBreakdown.totalTaxAmount.round();
        final newTotal = taxableAmount + newTax;

        return BillItem(
          id: item.id,
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          taxRate: item.taxRate,
          discountPercent: item.discountPercent,
          discountAmount: item.discountAmount,
          taxAmount: newTax,
          cgstAmount: gstBreakdown.cgstAmount.round(),
          sgstAmount: gstBreakdown.sgstAmount.round(),
          igstAmount: gstBreakdown.igstAmount.round(),
          taxRuleVersion: 'v1',
          totalAmount: newTotal,
          batchNumber: item.batchNumber,
          expiryDate: item.expiryDate,
        );
      }).toList();

      emit(_recalculateTotals(currentState.copyWith(
        items: updatedItems,
        customerId: null,
        customerName: 'Walk-in Customer',
        customerStateCode: null,
      )));
    }
  }

  void _onClearCart(ClearCart event, Emitter<BillingState> emit) {
    final currentState = state;
    final customerId = (currentState is BillingReady) ? currentState.customerId : null;
    final customerName = (currentState is BillingReady) ? currentState.customerName : 'Walk-in Customer';

    emit(BillingReady(
      items: const [],
      customerId: customerId,
      customerName: customerName,
    ));
  }

  Future<void> _onProcessPayment(
    ProcessPayment event,
    Emitter<BillingState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BillingReady || currentState.items.isEmpty) {
      emit(const BillingError(message: 'Cart is empty'));
      return;
    }

    emit(BillingProcessing());

    int paidAmount;
    int dueAmount;

    switch (event.paymentMode) {
      case 'CASH':
      case 'UPI':
      case 'CARD':
        paidAmount = currentState.totalAmount;
        dueAmount = 0;
        break;
      case 'CREDIT':
        paidAmount = event.paidAmount;
        dueAmount = currentState.totalAmount - event.paidAmount;
        break;
      default:
        paidAmount = currentState.totalAmount;
        dueAmount = 0;
    }

    if (event.paymentMode == 'CREDIT' &&
        currentState.customerId != null &&
        currentState.customerId!.isNotEmpty) {
      final customerResult = await _getCustomerByIdUseCase(
        currentState.customerId!,
      );
      customerResult.fold(
        (failure) {},
        (customer) {
          final newBalance = customer.currentBalance + dueAmount;
          if (customer.creditLimit > 0 && newBalance > customer.creditLimit) {
            final exceeded = newBalance - customer.creditLimit;
            emit(BillingError(
              message: 'Credit limit exceeded by \u20B9$exceeded. '
                  'Current balance: \u20B9${customer.currentBalance}, '
                  'Limit: \u20B9${customer.creditLimit}',
            ));
          }
        },
      );
      if (state is BillingError) return;
    }

    final params = CreateBillParams(
      customerId: currentState.customerId,
      customerName: currentState.customerName,
      subtotal: currentState.subtotal,
      taxAmount: currentState.taxAmount,
      cgstAmount: currentState.cgstAmount,
      sgstAmount: currentState.sgstAmount,
      igstAmount: currentState.igstAmount,
      taxRuleVersion: 'v1',
      discountAmount: currentState.discountAmount + currentState.billDiscountAmount,
      roundOff: currentState.roundOff,
      totalAmount: currentState.totalAmount,
      paidAmount: paidAmount,
      dueAmount: dueAmount,
      paymentMode: event.paymentMode,
      createdBy: event.employeeId ?? 'system',
      items: currentState.items,
    );

    final result = await _createBillUseCase(params);

    result.fold(
      (failure) => emit(BillingError(message: failure.message)),
      (bill) {
        emit(BillingSuccess(
          message: 'Bill ${bill.billNumber} saved successfully',
          bill: bill,
        ));
        emit(BillingReady(
          items: const [],
          customerId: null,
          customerName: 'Walk-in Customer',
        ));
      },
    );
  }

  Future<void> _onLoadRecentBills(
    LoadRecentBills event,
    Emitter<BillingState> emit,
  ) async {
    final result = await _getRecentBillsUseCase(event.limit);
    result.fold(
      (failure) {},
      (bills) => emit(BillingRecentLoaded(bills: bills)),
    );
  }

  BillItem _buildCartItem(AddToCart event) {
    // Calculate GST based on seller/buyer state codes
    final gstBreakdown = GstCalculator.calculateGst(
      taxableAmount: event.unitPrice * event.quantity,
      taxRate: event.taxRate,
      sellerStateCode: _defaultSellerStateCode,
      buyerStateCode: event.buyerStateCode ?? _defaultSellerStateCode,
    );

    final taxAmount = gstBreakdown.totalTaxAmount.round();
    final subtotal = (event.unitPrice * event.quantity).round();
    final totalAmount = subtotal + taxAmount;

    return BillItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      productId: event.productId,
      productName: event.productName,
      quantity: event.quantity,
      unitPrice: event.unitPrice,
      taxRate: event.taxRate,
      taxAmount: taxAmount,
      cgstAmount: gstBreakdown.cgstAmount.round(),
      sgstAmount: gstBreakdown.sgstAmount.round(),
      igstAmount: gstBreakdown.igstAmount.round(),
      taxRuleVersion: 'v1',
      totalAmount: totalAmount,
      batchNumber: event.batchNumber,
    );
  }

  BillingReady _recalculateTotals(BillingReady currentState) {
    int subtotal = 0;
    int taxAmount = 0;
    int cgstAmount = 0;
    int sgstAmount = 0;
    int igstAmount = 0;
    int discountAmount = 0;

    for (final item in currentState.items) {
      subtotal += item.subtotal;
      taxAmount += item.taxAmount;
      cgstAmount += item.cgstAmount;
      sgstAmount += item.sgstAmount;
      igstAmount += item.igstAmount;
      discountAmount += item.discountAmount;
    }

    final preRoundTotal = subtotal + taxAmount - discountAmount - currentState.billDiscountAmount;
    final roundedTotal = preRoundTotal.round();
    final roundOff = roundedTotal - preRoundTotal;

    return currentState.copyWith(
      subtotal: subtotal,
      taxAmount: taxAmount,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      igstAmount: igstAmount,
      discountAmount: discountAmount,
      roundOff: roundOff,
      totalAmount: roundedTotal,
    );
  }
}
