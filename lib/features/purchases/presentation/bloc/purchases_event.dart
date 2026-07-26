part of 'purchases_bloc.dart';

abstract class PurchasesEvent extends Equatable {
  const PurchasesEvent();

  @override
  List<Object> get props => [];
}

class LoadPurchases extends PurchasesEvent {
  final String? supplierId;
  final String? startDate;
  final String? endDate;

  const LoadPurchases({
    this.supplierId,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object> get props => [supplierId ?? '', startDate ?? '', endDate ?? ''];
}

class CreatePurchaseRequested extends PurchasesEvent {
  final Purchase purchase;

  const CreatePurchaseRequested({required this.purchase});

  @override
  List<Object> get props => [purchase];
}

class ReceivePurchaseRequested extends PurchasesEvent {
  final String purchaseId;
  final List<PurchaseItem> receivedItems;

  const ReceivePurchaseRequested({
    required this.purchaseId,
    required this.receivedItems,
  });

  @override
  List<Object> get props => [purchaseId, receivedItems];
}
