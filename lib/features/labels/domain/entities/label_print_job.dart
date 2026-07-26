import 'package:equatable/equatable.dart';

/// Domain entity representing a single label print job for a retail product.
///
/// A print job encapsulates all the data needed to render one label: product
/// identifiers, pricing information, and the target label type. Multiple
/// print jobs are batched together when the user selects several products
/// and triggers a bulk print action.
///
/// The [quantity] field controls how many copies of this label to print.
/// For example, setting quantity to 5 will produce 5 identical labels for
/// the same product — useful when stocking new shelves.
///
/// ## Data Flow
/// ```
/// Product entity → LabelPrintJob (via LabelRepository) → BLoC → PDF/Thermal
/// ```
class LabelPrintJob extends Equatable {
  /// Unique identifier for this print job (UUID).
  final String id;

  /// Foreign key to the source product in the catalog.
  final String productId;

  /// Denormalized product name preserved at print time for label accuracy.
  final String productName;

  /// Stock Keeping Unit code, shown on barcode labels.
  final String? sku;

  /// EAN/UPC barcode string, rendered as a scannable barcode on the label.
  final String? barcode;

  /// Maximum Retail Price in paise (INR).
  final double mrp;

  /// Current selling price in paise (INR).
  final double sellingPrice;

  /// Applicable tax rate percentage (e.g., 18.0 for 18% GST).
  final double? taxRate;

  /// Target label type — one of 'barcode', 'price', or 'shelf'.
  final String templateType;

  /// Number of copies of this label to print.
  final int quantity;

  const LabelPrintJob({
    required this.id,
    required this.productId,
    required this.productName,
    this.sku,
    this.barcode,
    required this.mrp,
    required this.sellingPrice,
    this.taxRate,
    required this.templateType,
    this.quantity = 1,
  });

  /// Returns true if the product has a barcode available for rendering.
  bool get hasBarcode => barcode != null && barcode!.isNotEmpty;

  /// Returns true if this product's MRP differs from the selling price.
  bool get hasDiscount => mrp > sellingPrice;

  /// Returns the discount percentage between MRP and selling price.
  double get discountPercent =>
      mrp > 0 ? ((mrp - sellingPrice) / mrp * 100) : 0.0;

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        sku,
        barcode,
        mrp,
        sellingPrice,
        taxRate,
        templateType,
        quantity,
      ];

  /// Creates a copy with optional field overrides.
  LabelPrintJob copyWith({
    String? id,
    String? productId,
    String? productName,
    String? sku,
    String? barcode,
    double? mrp,
    double? sellingPrice,
    double? taxRate,
    String? templateType,
    int? quantity,
  }) {
    return LabelPrintJob(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      mrp: mrp ?? this.mrp,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      taxRate: taxRate ?? this.taxRate,
      templateType: templateType ?? this.templateType,
      quantity: quantity ?? this.quantity,
    );
  }
}
