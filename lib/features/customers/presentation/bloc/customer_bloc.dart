import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/usecases/get_customers_usecase.dart';
import '../../domain/usecases/create_customer_usecase.dart';
import '../../domain/usecases/update_customer_usecase.dart';
import '../../domain/usecases/delete_customer_usecase.dart';
import '../../domain/usecases/get_customer_by_id_usecase.dart';

part 'customer_event.dart';
part 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final GetCustomersUseCase getCustomersUseCase;
  final CreateCustomerUseCase createCustomerUseCase;
  final UpdateCustomerUseCase updateCustomerUseCase;
  final DeleteCustomerUseCase deleteCustomerUseCase;
  final GetCustomerByIdUseCase getCustomerByIdUseCase;

  CustomerBloc({
    required this.getCustomersUseCase,
    required this.createCustomerUseCase,
    required this.updateCustomerUseCase,
    required this.deleteCustomerUseCase,
    required this.getCustomerByIdUseCase,
  }) : super(CustomerInitial()) {
    on<LoadCustomers>(_onLoadCustomers);
    on<SearchCustomers>(_onSearchCustomers);
    on<LoadCustomerById>(_onLoadCustomerById);
    on<CreateCustomer>(_onCreateCustomer);
    on<UpdateCustomer>(_onUpdateCustomer);
    on<DeleteCustomer>(_onDeleteCustomer);
  }

  Future<void> _onLoadCustomers(
    LoadCustomers event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    final result = await getCustomersUseCase(
      const GetCustomersParams(),
    );
    result.fold(
      (failure) => emit(CustomerError(message: failure.message)),
      (customers) => emit(CustomerLoaded(customers: customers)),
    );
  }

  Future<void> _onSearchCustomers(
    SearchCustomers event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    final result = await getCustomersUseCase(
      GetCustomersParams(search: event.query),
    );
    result.fold(
      (failure) => emit(CustomerError(message: failure.message)),
      (customers) => emit(CustomerLoaded(customers: customers)),
    );
  }

  Future<void> _onLoadCustomerById(
    LoadCustomerById event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    final result = await getCustomerByIdUseCase(event.customerId);
    result.fold(
      (failure) => emit(CustomerError(message: failure.message)),
      (customer) => emit(CustomerDetailLoaded(customer: customer)),
    );
  }

  Future<void> _onCreateCustomer(
    CreateCustomer event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    final result = await createCustomerUseCase(CreateCustomerParams(customer: event.customer));
    result.fold(
      (failure) => emit(CustomerError(message: failure.message)),
      (customer) => emit(
        const CustomerOperationSuccess(message: 'Customer created successfully'),
      ),
    );
  }

  Future<void> _onUpdateCustomer(
    UpdateCustomer event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    final result = await updateCustomerUseCase(event.customer);
    result.fold(
      (failure) => emit(CustomerError(message: failure.message)),
      (customer) => emit(
        const CustomerOperationSuccess(message: 'Customer updated successfully'),
      ),
    );
  }

  Future<void> _onDeleteCustomer(
    DeleteCustomer event,
    Emitter<CustomerState> emit,
  ) async {
    emit(CustomerLoading());
    final result = await deleteCustomerUseCase(event.customerId);
    result.fold(
      (failure) => emit(CustomerError(message: failure.message)),
      (_) => emit(
        const CustomerOperationSuccess(message: 'Customer deleted successfully'),
      ),
    );
  }
}
