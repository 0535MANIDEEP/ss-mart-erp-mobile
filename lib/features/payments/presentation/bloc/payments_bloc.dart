import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/payment.dart';
import '../../domain/usecases/payment_usecases.dart';

abstract class PaymentsEvent extends Equatable {
  const PaymentsEvent();
  @override
  List<Object?> get props => [];
}

class LoadPayments extends PaymentsEvent {
  final String? paymentType;
  final DateTime? startDate;
  final DateTime? endDate;
  const LoadPayments({this.paymentType, this.startDate, this.endDate});
  @override
  List<Object?> get props => [paymentType, startDate, endDate];
}

class AddPaymentEvent extends PaymentsEvent {
  final Payment payment;
  const AddPaymentEvent(this.payment);
  @override
  List<Object?> get props => [payment];
}

class LoadOutstanding extends PaymentsEvent {
  const LoadOutstanding();
}

class LoadPaymentSummary extends PaymentsEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  const LoadPaymentSummary({this.startDate, this.endDate});
  @override
  List<Object?> get props => [startDate, endDate];
}

class PaymentsState extends Equatable {
  final List<Payment> payments;
  final Map<String, dynamic>? outstanding;
  final Map<String, dynamic>? summary;
  final bool isLoading;
  final String? error;

  const PaymentsState({
    this.payments = const [],
    this.outstanding,
    this.summary,
    this.isLoading = false,
    this.error,
  });

  PaymentsState copyWith({
    List<Payment>? payments,
    Map<String, dynamic>? outstanding,
    Map<String, dynamic>? summary,
    bool? isLoading,
    String? error,
  }) {
    return PaymentsState(
      payments: payments ?? this.payments,
      outstanding: outstanding ?? this.outstanding,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [payments, outstanding, summary, isLoading, error];
}

class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  final GetPaymentsUseCase _getPayments;
  final CreatePaymentUseCase _createPayment;
  final GetOutstandingUseCase _getOutstanding;
  final GetPaymentSummaryUseCase _getSummary;

  PaymentsBloc({
    required GetPaymentsUseCase getPayments,
    required CreatePaymentUseCase createPayment,
    required GetOutstandingUseCase getOutstanding,
    required GetPaymentSummaryUseCase getSummary,
  })  : _getPayments = getPayments,
        _createPayment = createPayment,
        _getOutstanding = getOutstanding,
        _getSummary = getSummary,
        super(const PaymentsState()) {
    on<LoadPayments>(_onLoad);
    on<AddPaymentEvent>(_onAdd);
    on<LoadOutstanding>(_onOutstanding);
    on<LoadPaymentSummary>(_onSummary);
  }

  Future<void> _onLoad(LoadPayments event, Emitter<PaymentsState> emit) async {
    emit(state.copyWith(isLoading: true));
    final result = await _getPayments(
      paymentType: event.paymentType, startDate: event.startDate, endDate: event.endDate,
    );
    result.fold(
      (f) => emit(state.copyWith(isLoading: false, error: f.message)),
      (p) => emit(state.copyWith(isLoading: false, payments: p)),
    );
  }

  Future<void> _onAdd(AddPaymentEvent event, Emitter<PaymentsState> emit) async {
    final result = await _createPayment(event.payment);
    result.fold(
      (f) => emit(state.copyWith(error: f.message)),
      (p) => emit(state.copyWith(payments: [p, ...state.payments])),
    );
  }

  Future<void> _onOutstanding(LoadOutstanding event, Emitter<PaymentsState> emit) async {
    emit(state.copyWith(isLoading: true));
    final result = await _getOutstanding();
    result.fold(
      (f) => emit(state.copyWith(isLoading: false, error: f.message)),
      (o) => emit(state.copyWith(isLoading: false, outstanding: o)),
    );
  }

  Future<void> _onSummary(LoadPaymentSummary event, Emitter<PaymentsState> emit) async {
    emit(state.copyWith(isLoading: true));
    final result = await _getSummary(startDate: event.startDate, endDate: event.endDate);
    result.fold(
      (f) => emit(state.copyWith(isLoading: false, error: f.message)),
      (s) => emit(state.copyWith(isLoading: false, summary: s)),
    );
  }
}
