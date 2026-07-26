part of 'purchases_bloc.dart';

abstract class PurchasesState extends Equatable {
  const PurchasesState();

  @override
  List<Object> get props => [];
}

class PurchasesInitial extends PurchasesState {
  const PurchasesInitial();
}

class PurchasesLoading extends PurchasesState {
  const PurchasesLoading();
}

class PurchasesLoaded extends PurchasesState {
  final List<Purchase> purchases;

  const PurchasesLoaded({required this.purchases});

  @override
  List<Object> get props => [purchases];
}

class PurchaseCreated extends PurchasesState {
  final Purchase purchase;

  const PurchaseCreated({required this.purchase});

  @override
  List<Object> get props => [purchase];
}

class PurchaseReceived extends PurchasesState {
  final Purchase purchase;

  const PurchaseReceived({required this.purchase});

  @override
  List<Object> get props => [purchase];
}

class PurchasesError extends PurchasesState {
  final String message;

  const PurchasesError({required this.message});

  @override
  List<Object> get props => [message];
}
