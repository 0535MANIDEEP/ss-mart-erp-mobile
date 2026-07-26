import 'package:equatable/equatable.dart';

/// Domain entity representing a sellable product in the SS MART ERP system.
///
/// Products are the core inventory units tracked across sales, purchases,
/// and stock management. Each product carries pricing (MRP, selling, purchase),
/// tax information (GST/IGST), inventory thresholds, and relational links
/// to categories and suppliers.
///
/// All monetary values are stored in the smallest currency unit (paise) to
/// avoid floating-point precision issues. Prices are always non-negative integers.
///
/// The [version] field supports optimistic concurrency control during
/// offline-to-online sync conflict resolution.
class Product extends Equatable {
  /// Unique identifier for the product (UUID format).
  final String id;

  /// Display name of the product shown on bills and UI.
  final String name;

  /// Stock Keeping Unit — internal code for warehouse/tracking purposes.
  final String? sku;

  /// EAN/UPC barcode string used at POS for quick scanning lookup.
  final String? barcode;

  /// HSN (Harmonized System of Nomenclature) code required for GST compliance
  /// in Indian tax invoicing. Determines the applicable GST rate slab.
  final String hsnCode;

  /// Unit of measurement for the product (e.g., 'PCS', 'KG', 'LTR', 'BOX').
  final String unit;

  /// Number of base units per packaging unit (e.g., 12 for a dozen pack).
  final double packSize;

  /// Maximum Retail Price in paise — the MRP printed on the product.
  final int mrp;

  /// Actual selling price in paise at which the product is billed to customers.
  final int sellingPrice;

  /// Cost price per unit in paise at which the product was procured from supplier.
  /// Null when purchase history is unavailable.
  final int? purchasePrice;

  /// Tax rate percentage (e.g., 5.0, 12.0, 18.0, 28.0 for GST slabs).
  final double taxRate;

  /// Type of tax applied — 'GST' for intra-state or 'IGST' for inter-state.
  final String taxType;

  /// Foreign key to the category this product belongs to (nullable for uncategorized).
  final String? categoryId;

  /// Foreign key to the primary supplier for this product (nullable for direct imports).
  final String? supplierId;

  /// Minimum stock threshold below which a reorder alert is triggered.
  final int reorderLevel;

  /// Current physical quantity on hand in the primary warehouse.
  final int currentStock;

  /// Whether the product is actively available for sale.
  /// Inactive products are hidden from POS but retained for historical data.
  final bool isActive;

  /// Timestamp when the product was first created in the system.
  final DateTime createdAt;

  /// Timestamp of the most recent modification to this product record.
  final DateTime updatedAt;

  /// Optimistic concurrency version counter incremented on each update.
  /// Used during sync to detect and resolve edit conflicts.
  final int version;

  const Product({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    required this.hsnCode,
    this.unit = 'PCS',
    this.packSize = 1.0,
    required this.mrp,
    required this.sellingPrice,
    this.purchasePrice,
    this.taxRate = 0.0,
    this.taxType = 'GST',
    this.categoryId,
    this.supplierId,
    this.reorderLevel = 10,
    this.currentStock = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  /// Returns true if current stock is at or below the reorder threshold.
  bool get isLowStock => currentStock <= reorderLevel;

  /// Returns true if the product has zero or negative stock (oversold).
  bool get isOutOfStock => currentStock <= 0;

  /// Calculates the tax amount in paise based on selling price and tax rate.
  int get taxAmount => (sellingPrice * taxRate / 100).round();

  /// Returns the final customer-facing price including tax in paise.
  int get sellingPriceWithTax => sellingPrice + taxAmount;

  /// Calculates profit margin percentage based on purchase price.
  /// Returns 0.0 if purchase price is unknown or zero.
  double get margin => purchasePrice != null && purchasePrice! > 0
      ? ((sellingPrice - purchasePrice!) / purchasePrice! * 100)
      : 0.0;

  @override
  List<Object?> get props => [
        id, name, sku, barcode, hsnCode, unit, packSize,
        mrp, sellingPrice, purchasePrice, taxRate, taxType,
        categoryId, supplierId, reorderLevel, currentStock,
        isActive, createdAt, updatedAt, version,
      ];

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? barcode,
    String? hsnCode,
    String? unit,
    double? packSize,
    int? mrp,
    int? sellingPrice,
    int? purchasePrice,
    double? taxRate,
    String? taxType,
    String? categoryId,
    String? supplierId,
    int? reorderLevel,
    int? currentStock,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      hsnCode: hsnCode ?? this.hsnCode,
      unit: unit ?? this.unit,
      packSize: packSize ?? this.packSize,
      mrp: mrp ?? this.mrp,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      taxRate: taxRate ?? this.taxRate,
      taxType: taxType ?? this.taxType,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      currentStock: currentStock ?? this.currentStock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }
}
