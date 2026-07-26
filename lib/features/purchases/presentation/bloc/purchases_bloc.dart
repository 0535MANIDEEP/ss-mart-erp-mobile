import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/purchase_entity.dart';
import '../../domain/usecases/get_purchases_usecase.dart';
import '../../domain/usecases/create_purchase_usecase.dart';
import '../../domain/usecases/receive_purchase_usecase.dart';

part 'purchases_event.dart';
part 'purchases_state.dart';

class PurchasesBloc extends Bloc<PurchasesEvent, PurchasesState> {
  final GetPurchasesUseCase getPurchasesUseCase;
  final CreatePurchaseUseCase createPurchaseUseCase;
  final ReceivePurchaseUseCase receivePurchaseUseCase;

  PurchasesBloc({
    required this.getPurchasesUseCase,
    required this.createPurchaseUseCase,
    required this.receivePurchaseUseCase,
  }) : super(PurchasesInitial()) {
    on<LoadPurchases>(_onLoadPurchases);
    on<CreatePurchaseRequested>(_onCreatePurchase);
    on<ReceivePurchaseRequested>(_onReceivePurchase);
  }

  Future<void> _onLoadPurchases(
    LoadPurchases event,
    Emitter<PurchasesState> emit,
  ) async {
    emit(PurchasesLoading());
    final result = await getPurchasesUseCase(
      GetPurchasesParams(
        supplierId: event.supplierId,
        startDate: event.startDate,
        endDate: event.endDate,
      ),
    );
    result.fold(
      (failure) => emit(PurchasesError(message: failure.message)),
      (purchases) => emit(PurchasesLoaded(purchases: purchases)),
    );
  }

  Future<void> _onCreatePurchase(
    CreatePurchaseRequested event,
    Emitter<PurchasesState> emit,
  ) async {
    emit(PurchasesLoading());
    final result = await createPurchaseUseCase(
      CreatePurchaseParams(purchase: event.purchase),
    );
    result.fold(
      (failure) => emit(PurchasesError(message: failure.message)),
      (purchase) => emit(PurchaseCreated(purchase: purchase)),
    );
  }

  Future<void> _onReceivePurchase(
    ReceivePurchaseRequested event,
    Emitter<PurchasesState> emit,
  ) async {
    emit(PurchasesLoading());
    final result = await receivePurchaseUseCase(
      ReceivePurchaseParams(
        purchaseId: event.purchaseId,
        receivedItems: event.receivedItems,
      ),
    );
    result.fold(
      (failure) => emit(PurchasesError(message: failure.message)),
      (purchase) => emit(PurchaseReceived(purchase: purchase)),
    );
  }
}
