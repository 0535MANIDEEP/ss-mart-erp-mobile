part of 'customer_bloc.dart';

abstract class CustomerState extends Equatable {
  const CustomerState();

  @override
  List<Object> get props => [];
}

class CustomerInitial extends CustomerState {
  const CustomerInitial();
}

class CustomerLoading extends CustomerState {
  const CustomerLoading();
}

class CustomerLoaded extends CustomerState {
  final List<Customer> customers;

  const CustomerLoaded({required this.customers});

  @override
  List<Object> get props => [customers];
}

/// State emitted after a successful create, update, or delete operation.
class CustomerOperationSuccess extends CustomerState {
  final String message;

  const CustomerOperationSuccess({required this.message});

  @override
  List<Object> get props => [message];
}

/// State emitted when a single customer detail is loaded successfully.
class CustomerDetailLoaded extends CustomerState {
  final Customer customer;

  const CustomerDetailLoaded({required this.customer});

  @override
  List<Object> get props => [customer];
}

class CustomerError extends CustomerState {
  final String message;

  const CustomerError({required this.message});

  @override
  List<Object> get props => [message];
}
