part of 'labels_bloc.dart';

/// States for the Labels feature BLoC.
///
/// Models every possible UI state for the label printing workflow:
/// initial, loading, ready with data, preview, printing, success, and error.
abstract class LabelsState extends Equatable {
  const LabelsState();

  @override
  List<Object> get props => [];
}

/// Initial state before any data is loaded.
class LabelsInitial extends LabelsState {
  const LabelsInitial();
}

/// Loading state while products or templates are being fetched.
class LabelsLoading extends LabelsState {
  const LabelsLoading();
}

/// Primary ready state with loaded products and selection context.
///
/// This state holds the full working state of the label printing screen:
/// the product list, current selection, label type, quantity, and templates.
class LabelsReady extends LabelsState {
  /// All available products for label selection.
  final List<ProductLabelItem> products;

  /// Set of currently selected product IDs.
  final Set<String> selectedProductIds;

  /// Active label type — one of 'barcode', 'price', or 'shelf'.
  final String labelType;

  /// Number of label copies to print per selected product.
  final int quantityPerLabel;

  /// Available label templates.
  final List<LabelTemplate> templates;

  /// Generated print jobs (populated after PreviewLabels or PrintLabels).
  final List<LabelPrintJob> printJobs;

  const LabelsReady({
    this.products = const [],
    this.selectedProductIds = const {},
    this.labelType = 'barcode',
    this.quantityPerLabel = 1,
    this.templates = const [],
    this.printJobs = const [],
  });

  /// Returns the count of currently selected products.
  int get selectedCount => selectedProductIds.length;

  /// Returns true if at least one product is selected.
  bool get hasSelection => selectedProductIds.isNotEmpty;

  /// Returns the default template for the current label type.
  LabelTemplate? get defaultTemplate =>
      templates.where((t) => t.type == labelType && t.isDefault).firstOrNull;

  /// Returns all templates matching the current label type.
  List<LabelTemplate> get templatesForType =>
      templates.where((t) => t.type == labelType).toList();

  /// Returns the filtered list of products matching the current selection.
  List<ProductLabelItem> get selectedProducts =>
      products.where((p) => selectedProductIds.contains(p.id)).toList();

  /// Returns the total number of labels to print (products x quantity).
  int get totalLabelsToPrint => selectedProductIds.length * quantityPerLabel;

  LabelsReady copyWith({
    List<ProductLabelItem>? products,
    Set<String>? selectedProductIds,
    String? labelType,
    int? quantityPerLabel,
    List<LabelTemplate>? templates,
    List<LabelPrintJob>? printJobs,
  }) {
    return LabelsReady(
      products: products ?? this.products,
      selectedProductIds: selectedProductIds ?? this.selectedProductIds,
      labelType: labelType ?? this.labelType,
      quantityPerLabel: quantityPerLabel ?? this.quantityPerLabel,
      templates: templates ?? this.templates,
      printJobs: printJobs ?? this.printJobs,
    );
  }

  @override
  List<Object> get props => [
        products,
        selectedProductIds,
        labelType,
        quantityPerLabel,
        templates,
        printJobs,
      ];
}

/// State emitted while labels are being sent to the printer.
class LabelsPrinting extends LabelsState {
  const LabelsPrinting();
}

/// State emitted after labels are sent to the printer or shared as PDF.
class LabelsPrintSuccess extends LabelsState {
  final String message;
  final List<LabelPrintJob> printJobs;

  const LabelsPrintSuccess({
    required this.message,
    required this.printJobs,
  });

  @override
  List<Object> get props => [message, printJobs];
}

/// Preview state containing generated print jobs for visual mockup.
class LabelsPreview extends LabelsState {
  final List<LabelPrintJob> printJobs;
  final String labelType;
  final LabelTemplate? template;

  const LabelsPreview({
    required this.printJobs,
    required this.labelType,
    this.template,
  });

  @override
  List<Object> get props => [printJobs, labelType, template ?? ''];
}

/// Error state with a user-facing message.
class LabelsError extends LabelsState {
  final String message;

  const LabelsError({required this.message});

  @override
  List<Object> get props => [message];
}
