import 'package:equatable/equatable.dart';

/// Domain entity representing a configurable label template for printing.
///
/// Templates define the visual layout and physical dimensions for three types
/// of retail labels: barcode stickers, price tags, and shelf labels. Each
/// template specifies width/height in millimeters and an optional JSON-based
/// [layout] map that controls element positioning within the label boundary.
///
/// Templates are pre-defined at app initialization and stored in-memory;
/// they do not require a dedicated database table since the set of available
/// templates is fixed per deployment.
///
/// ## Label Types
/// - **barcode**: Compact sticker with barcode, product name, and SKU.
/// - **price**: Price tag showing MRP, selling price, and product name.
/// - **shelf**: Larger shelf label with full product details for display.
class LabelTemplate extends Equatable {
  /// Unique identifier for this template.
  final String id;

  /// Human-readable display name (e.g., '58mm Barcode').
  final String name;

  /// Template category — one of 'barcode', 'price', or 'shelf'.
  final String type;

  /// Label width in millimeters (e.g., 58 for standard thermal width).
  final int width;

  /// Label height in millimeters (e.g., 30 for a small barcode sticker).
  final int height;

  /// Optional JSON-serializable layout configuration for element positioning.
  ///
  /// Keys may include 'fontSize', 'showBarcode', 'showPrice', 'showMrp',
  /// 'alignment', etc., depending on the template type.
  final Map<String, dynamic>? layout;

  /// Whether this template is the default selection for its [type].
  final bool isDefault;

  const LabelTemplate({
    required this.id,
    required this.name,
    required this.type,
    this.width = 58,
    this.height = 30,
    this.layout,
    this.isDefault = false,
  });

  /// Returns the label dimensions as a readable string (e.g., '58 x 30 mm').
  String get dimensions => '$width x $height mm';

  @override
  List<Object?> get props => [id, name, type, width, height, layout, isDefault];

  /// Creates a copy with optional field overrides.
  LabelTemplate copyWith({
    String? id,
    String? name,
    String? type,
    int? width,
    int? height,
    Map<String, dynamic>? layout,
    bool? isDefault,
  }) {
    return LabelTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      width: width ?? this.width,
      height: height ?? this.height,
      layout: layout ?? this.layout,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
