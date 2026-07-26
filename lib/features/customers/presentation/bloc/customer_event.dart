part of 'customer_bloc.dart';

abstract class CustomerEvent extends Equatable {
  const CustomerEvent();

  @override
  List<Object> get props => [];
}

class LoadCustomers extends CustomerEvent {
  const LoadCustomers();
}

class SearchCustomers extends CustomerEvent {
  final String query;

  const SearchCustomers({required this.query});

  @override
  List<Object> get props => [query];
}

/// Event to load a single customer by their unique identifier.
class LoadCustomerById extends CustomerEvent {
  final String customerId;

  const LoadCustomerById({required this.customerId});

  @override
  List<Object> get props => [customerId];
}

/// Event to create a new customer in the system.
class CreateCustomer extends CustomerEvent {
  final Customer customer;

  const CreateCustomer({required this.customer});

  @override
  List<Object> get props => [customer];
}

/// Event to update an existing customer record.
class UpdateCustomer extends CustomerEvent {
  final Customer customer;

  const UpdateCustomer({required this.customer});

  @override
  List<Object> get props => [customer];
}

/// Event to soft-delete a customer by their identifier.
class DeleteCustomer extends CustomerEvent {
  final String customerId;

  const DeleteCustomer({required this.customerId});

  @override
  List<Object> get props => [customerId];
}
