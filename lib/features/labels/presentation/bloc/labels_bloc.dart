import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/label_repository_impl.dart';
import '../../domain/entities/label_template.dart';
import '../../domain/entities/label_print_job.dart';

part 'labels_event.dart';
part 'labels_state.dart';

/// BLoC managing the label printing workflow state.
///
/// Coordinates product selection, label type switching, quantity configuration,
/// and print job generation for the label printing feature. Delegates data
/// fetching to [LabelRepositoryImpl] and print execution to the Bluetooth
/// printer service.
///
/// ## State Machine
/// ```
/// LabelsInitial → LabelsLoading → LabelsReady ⇄ LabelsPreview
///                                    ↓
///                              LabelsPrinting → LabelsPrintSuccess
///                                    ↓
///                               LabelsError
/// ```
///
/// ## Design Notes
/// - Uses [Uuid] for generating unique print job identifiers.
/// - Product selection is tracked by ID set for O(1) lookup performance.
/// - The BLoC does not hold printer state — that is managed by
///   [BluetoothPrinterService] independently.
class LabelsBloc extends Bloc<LabelsEvent, LabelsState> {
  final LabelRepositoryImpl _labelRepository;

  LabelsBloc({required LabelRepositoryImpl labelRepository})
      : _labelRepository = labelRepository,
        super(const LabelsInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<SelectProduct>(_onSelectProduct);
    on<DeselectProduct>(_onDeselectProduct);
    on<SelectAll>(_onSelectAll);
    on<DeselectAll>(_onDeselectAll);
    on<SetLabelType>(_onSetLabelType);
    on<SetQuantity>(_onSetQuantity);
    on<PrintLabels>(_onPrintLabels);
    on<PreviewLabels>(_onPreviewLabels);
    on<LoadTemplates>(_onLoadTemplates);
  }

  /// Loads products for the label selection list.
  ///
  /// Optionally filters by search [query]. Preserves existing selection
  /// state and templates when re-fetching after a search change.
  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<LabelsState> emit,
  ) async {
    emit(const LabelsLoading());

    final templatesResult = await _labelRepository.getTemplates();
    final templates = templatesResult.fold(
      (failure) => <LabelTemplate>[],
      (t) => t,
    );

    final productsResult = await _labelRepository.getProductsForLabeling(
      query: event.query,
    );

    productsResult.fold(
      (failure) => emit(LabelsError(message: failure.message)),
      (products) {
        final currentState = state;
        final selectedIds = currentState is LabelsReady
            ? currentState.selectedProductIds
            : <String>{};
        final labelType = currentState is LabelsReady
            ? currentState.labelType
            : 'barcode';
        final quantity = currentState is LabelsReady
            ? currentState.quantityPerLabel
            : 1;

        emit(LabelsReady(
          products: products,
          selectedProductIds: selectedIds,
          labelType: labelType,
          quantityPerLabel: quantity,
          templates: templates,
        ));
      },
    );
  }

  /// Toggles a product's selection state.
  ///
  /// Adds the product ID to the selection if not present, removes it if present.
  void _onSelectProduct(SelectProduct event, Emitter<LabelsState> emit) {
    final currentState = state;
    if (currentState is! LabelsReady) return;

    final updatedSelection = Set<String>.from(currentState.selectedProductIds);
    if (updatedSelection.contains(event.productId)) {
      updatedSelection.remove(event.productId);
    } else {
      updatedSelection.add(event.productId);
    }

    emit(currentState.copyWith(selectedProductIds: updatedSelection));
  }

  /// Explicitly deselects a single product.
  void _onDeselectProduct(DeselectProduct event, Emitter<LabelsState> emit) {
    final currentState = state;
    if (currentState is! LabelsReady) return;

    final updatedSelection = Set<String>.from(currentState.selectedProductIds);
    updatedSelection.remove(event.productId);
    emit(currentState.copyWith(selectedProductIds: updatedSelection));
  }

  /// Selects all products in the current filtered list.
  void _onSelectAll(SelectAll event, Emitter<LabelsState> emit) {
    final currentState = state;
    if (currentState is! LabelsReady) return;

    final allIds = currentState.products.map((p) => p.id).toSet();
    emit(currentState.copyWith(selectedProductIds: allIds));
  }

  /// Clears the entire product selection.
  void _onDeselectAll(DeselectAll event, Emitter<LabelsState> emit) {
    final currentState = state;
    if (currentState is! LabelsReady) return;

    emit(currentState.copyWith(selectedProductIds: <String>{}));
  }

  /// Switches the active label type (barcode, price, or shelf).
  void _onSetLabelType(SetLabelType event, Emitter<LabelsState> emit) {
    final currentState = state;
    if (currentState is! LabelsReady) return;

    emit(currentState.copyWith(
      labelType: event.labelType,
      printJobs: [],
    ));
  }

  /// Updates the quantity of labels to print per selected product.
  void _onSetQuantity(SetQuantity event, Emitter<LabelsState> emit) {
    final currentState = state;
    if (currentState is! LabelsReady) return;

    emit(currentState.copyWith(
      quantityPerLabel: event.quantity.clamp(1, 999),
    ));
  }

  /// Generates print jobs and triggers the printer service.
  ///
  /// Falls back to emitting [LabelsError] if no products are selected,
  /// the repository fails, or printing encounters an error.
  Future<void> _onPrintLabels(
    PrintLabels event,
    Emitter<LabelsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! LabelsReady || !currentState.hasSelection) {
      emit(const LabelsError(message: 'No products selected for printing'));
      return;
    }

    emit(const LabelsPrinting());

    final result = await _labelRepository.generatePrintJobs(
      productIds: currentState.selectedProductIds.toList(),
      templateType: currentState.labelType,
      quantity: currentState.quantityPerLabel,
    );

    result.fold(
      (failure) => emit(LabelsError(message: failure.message)),
      (jobs) => emit(LabelsPrintSuccess(
        message: '${jobs.length} label(s) sent to printer',
        printJobs: jobs,
      )),
    );
  }

  /// Generates print jobs for preview without sending to printer.
  ///
  /// Emits [LabelsPreview] with the generated jobs so the preview page
  /// can render visual label mockups.
  Future<void> _onPreviewLabels(
    PreviewLabels event,
    Emitter<LabelsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! LabelsReady || !currentState.hasSelection) {
      emit(const LabelsError(message: 'No products selected for preview'));
      return;
    }

    final result = await _labelRepository.generatePrintJobs(
      productIds: currentState.selectedProductIds.toList(),
      templateType: currentState.labelType,
      quantity: currentState.quantityPerLabel,
    );

    result.fold(
      (failure) => emit(LabelsError(message: failure.message)),
      (jobs) {
        final template = currentState.defaultTemplate;
        emit(LabelsPreview(
          printJobs: jobs,
          labelType: currentState.labelType,
          template: template,
        ));
      },
    );
  }

  /// Loads available label templates from the repository.
  ///
  /// Can be dispatched independently to refresh templates without
  /// reloading the product list.
  Future<void> _onLoadTemplates(
    LoadTemplates event,
    Emitter<LabelsState> emit,
  ) async {
    final result = await _labelRepository.getTemplates();

    result.fold(
      (failure) => emit(LabelsError(message: failure.message)),
      (templates) {
        final currentState = state;
        if (currentState is LabelsReady) {
          emit(currentState.copyWith(templates: templates));
        }
      },
    );
  }
}
