part of 'labels_bloc.dart';

/// Events for the Labels feature BLoC.
///
/// All label-related user actions and system triggers are modeled as
/// discrete event classes extending [LabelsEvent]. Each event carries
/// the data needed for the BLoC to process the state transition.
abstract class LabelsEvent extends Equatable {
  const LabelsEvent();

  @override
  List<Object> get props => [];
}

/// Loads all active products into the label selection list.
///
/// Dispatched on page initialization and after search field changes.
class LoadProducts extends LabelsEvent {
  final String? query;

  const LoadProducts({this.query});

  @override
  List<Object> get props => [query ?? ''];
}

/// Toggles selection state of a single product.
///
/// If the product is currently selected, it is deselected; otherwise it is
/// added to the selection set.
class SelectProduct extends LabelsEvent {
  final String productId;

  const SelectProduct({required this.productId});

  @override
  List<Object> get props => [productId];
}

/// Explicitly deselects a single product by its identifier.
class DeselectProduct extends LabelsEvent {
  final String productId;

  const DeselectProduct({required this.productId});

  @override
  List<Object> get props => [productId];
}

/// Selects all currently visible products in the filtered list.
class SelectAll extends LabelsEvent {
  const SelectAll();
}

/// Clears the entire product selection set.
class DeselectAll extends LabelsEvent {
  const DeselectAll();
}

/// Changes the active label type (barcode, price, or shelf).
///
/// This affects which template is used for preview and printing.
class SetLabelType extends LabelsEvent {
  final String labelType;

  const SetLabelType({required this.labelType});

  @override
  List<Object> get props => [labelType];
}

/// Updates the quantity of labels to print per selected product.
class SetQuantity extends LabelsEvent {
  final int quantity;

  const SetQuantity({required this.quantity});

  @override
  List<Object> get props => [quantity];
}

/// Triggers label printing for all selected products.
///
/// Generates print jobs from the current selection and sends them to
/// the Bluetooth printer service. Emits [PrintSuccess] or [PrintError].
class PrintLabels extends LabelsEvent {
  const PrintLabels();
}

/// Opens the label preview page with the current selection.
///
/// Generates print jobs for preview rendering without actually printing.
class PreviewLabels extends LabelsEvent {
  const PreviewLabels();
}

/// Loads the available label templates from the repository.
class LoadTemplates extends LabelsEvent {
  const LoadTemplates();
}
