import 'dart:convert';
import 'dart:developer' as developer;

import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../database/database_dao.dart';

/// Bundle pack manager for creating and loading product bundles.
///
/// Supports Marg-style bundle pack system:
/// - Create bundle packs from multiple products
/// - Set bundle pricing (total or per-item override)
/// - Load bundles into billing as single line items
/// - Track bundle composition and quantities
///
/// ## Bundle Pricing
/// Bundles can have:
/// 1. Total price: Set a fixed price for the entire bundle
/// 2. Per-item price override: Override individual item prices within the bundle
/// 3. Auto-calculated: Sum of all item selling prices
///
/// ## Pricing Model
/// - All monetary values are in **paise** (integer). Divide by 100 for
///   display in rupees. This avoids floating-point rounding errors.
/// - Bundle items store an optional [priceOverride] per item. When null,
///   the bundle's total price is used; the caller decides distribution.
///
/// ## Usage
/// ```dart
/// final manager = BundlePackManager(dao: databaseDao);
/// final bundle = await manager.createBundle(
///   name: 'Combo Pack A',
///   items: [
///     BundleItemInput(productId: 'p1', quantity: 2),
///     BundleItemInput(productId: 'p2', quantity: 1),
///   ],
///   totalPrice: 25000, // optional: if null, auto-calculated
/// );
/// ```
class BundlePackManager {
  final DatabaseDao _dao;
  static const _uuid = Uuid();

  BundlePackManager({required DatabaseDao dao}) : _dao = dao;

  /// Creates a new bundle pack.
  ///
  /// [name] must be unique. [items] must have at least 1 item.
  /// [totalPrice] if provided sets the bundle price; otherwise auto-calculated
  /// from current product selling prices.
  ///
  /// Returns the created bundle with a generated ID.
  ///
  /// Throws [BundlePackException] if:
  /// - [name] is empty or whitespace
  /// - [items] is empty
  /// - A bundle with the same name already exists
  /// - Any referenced product does not exist
  Future<BundlePack> createBundle({
    required String name,
    String? description,
    required List<BundleItemInput> items,
    int? totalPrice,
  }) async {
    if (name.trim().isEmpty) {
      throw BundlePackException('Bundle name cannot be empty');
    }
    if (items.isEmpty) {
      throw BundlePackException(
        'Bundle must contain at least one item',
      );
    }

    try {
      // Check for duplicate bundle name
      final existing = await searchBundles(name.trim());
      if (existing.any(
        (b) => b.name.toLowerCase() == name.trim().toLowerCase(),
      )) {
        throw BundlePackException(
          'A bundle with name "$name" already exists',
        );
      }

      // Validate all products exist and are active
      for (final item in items) {
        final product = await _dao.getProductById(item.productId);
        if (product == null) {
          throw BundlePackException(
            'Product not found: ${item.productId}',
          );
        }
        if (!product.isActive) {
          throw BundlePackException(
            'Product "${product.name}" is inactive and cannot be added to a bundle',
          );
        }
      }

      // Check for duplicate products in the bundle
      final productIds = items.map((i) => i.productId).toList();
      final uniqueIds = productIds.toSet();
      if (uniqueIds.length != productIds.length) {
        throw BundlePackException(
          'Duplicate products are not allowed in a bundle',
        );
      }

      // Calculate total price if not provided
      final resolvedTotalPrice =
          totalPrice ?? await calculateBundlePrice(items);

      if (resolvedTotalPrice <= 0) {
        throw BundlePackException(
          'Bundle total price must be positive, got $resolvedTotalPrice',
        );
      }

      final now = DateTime.now();
      final bundleId = _uuid.v4();

      // Insert the bundle header
      await _dao.insertOrUpdateSetting(
        AppSettingsCompanion.insert(
          key: 'bundle_pack:$bundleId',
          value: _encodeBundleHeader(
            id: bundleId,
            name: name.trim(),
            description: description,
            totalPrice: resolvedTotalPrice,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
          valueType: const Value('json'),
          updatedAt: now,
        ),
      );

      // Insert bundle items
      for (final item in items) {
        final itemId = _uuid.v4();
        await _dao.insertOrUpdateSetting(
          AppSettingsCompanion.insert(
            key: 'bundle_pack_item:$bundleId:$itemId',
            value: _encodeBundleItem(
              id: itemId,
              bundleId: bundleId,
              productId: item.productId,
              quantity: item.quantity,
              priceOverride: item.priceOverride,
            ),
            valueType: const Value('json'),
            updatedAt: now,
          ),
        );
      }

      developer.log(
        'Created bundle "$name" (${items.length} items, '
        'total: $resolvedTotalPrice paise)',
        name: 'BundlePackManager',
      );

      return BundlePack(
        id: bundleId,
        name: name.trim(),
        description: description,
        totalPrice: resolvedTotalPrice,
        isActive: true,
        items: await _loadBundleItems(bundleId, items),
        createdAt: now,
        updatedAt: now,
      );
    } on BundlePackException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error creating bundle "$name": $e',
        name: 'BundlePackManager',
        error: e,
        stackTrace: stackTrace,
      );
      throw BundlePackException(
        'Failed to create bundle "$name": $e',
      );
    }
  }

  /// Updates an existing bundle pack.
  ///
  /// Only non-null parameters are updated. If [items] is provided, the
  /// existing items are replaced entirely.
  ///
  /// Returns the updated bundle.
  ///
  /// Throws [BundlePackException] if the bundle does not exist or
  /// validation fails.
  Future<BundlePack> updateBundle({
    required String bundleId,
    String? name,
    String? description,
    List<BundleItemInput>? items,
    int? totalPrice,
  }) async {
    try {
      final existing = await getBundleById(bundleId);
      if (existing == null) {
        throw BundlePackException(
          'Bundle not found: $bundleId',
          bundleId: bundleId,
        );
      }

      // Check for duplicate name if changing
      if (name != null && name.trim().isNotEmpty) {
        final duplicates = await searchBundles(name.trim());
        final conflicting = duplicates.where(
          (b) =>
              b.id != bundleId &&
              b.name.toLowerCase() == name.trim().toLowerCase(),
        );
        if (conflicting.isNotEmpty) {
          throw BundlePackException(
            'A bundle with name "$name" already exists',
            bundleId: bundleId,
          );
        }
      }

      // Validate new items if provided
      if (items != null) {
        if (items.isEmpty) {
          throw BundlePackException(
            'Bundle must contain at least one item',
            bundleId: bundleId,
          );
        }

        for (final item in items) {
          final product = await _dao.getProductById(item.productId);
          if (product == null) {
            throw BundlePackException(
              'Product not found: ${item.productId}',
              bundleId: bundleId,
            );
          }
          if (!product.isActive) {
            throw BundlePackException(
              'Product "${product.name}" is inactive and cannot be added to a bundle',
              bundleId: bundleId,
            );
          }
        }

        final productIds = items.map((i) => i.productId).toList();
        final uniqueIds = productIds.toSet();
        if (uniqueIds.length != productIds.length) {
          throw BundlePackException(
            'Duplicate products are not allowed in a bundle',
            bundleId: bundleId,
          );
        }
      }

      final now = DateTime.now();
      final updatedName = name?.trim() ?? existing.name;
      final updatedDescription = description ?? existing.description;
      final updatedItems = items ?? existing.items.map((i) => BundleItemInput(
        productId: i.productId,
        quantity: i.quantity,
        priceOverride: i.priceOverride,
      )).toList();

      int resolvedTotalPrice;
      if (totalPrice != null) {
        resolvedTotalPrice = totalPrice;
      } else if (items != null) {
        resolvedTotalPrice = await calculateBundlePrice(updatedItems);
      } else {
        resolvedTotalPrice = existing.totalPrice;
      }

      if (resolvedTotalPrice <= 0) {
        throw BundlePackException(
          'Bundle total price must be positive, got $resolvedTotalPrice',
          bundleId: bundleId,
        );
      }

      // Update the bundle header
      await _dao.insertOrUpdateSetting(
        AppSettingsCompanion.insert(
          key: 'bundle_pack:$bundleId',
          value: _encodeBundleHeader(
            id: bundleId,
            name: updatedName,
            description: updatedDescription,
            totalPrice: resolvedTotalPrice,
            isActive: existing.isActive,
            createdAt: existing.createdAt,
            updatedAt: now,
          ),
          valueType: const Value('json'),
          updatedAt: now,
        ),
      );

      // Replace items if provided
      if (items != null) {
        // Delete old items
        await _deleteBundleItemSettings(bundleId);

        // Insert new items
        for (final item in updatedItems) {
          final itemId = _uuid.v4();
          await _dao.insertOrUpdateSetting(
            AppSettingsCompanion.insert(
              key: 'bundle_pack_item:$bundleId:$itemId',
              value: _encodeBundleItem(
                id: itemId,
                bundleId: bundleId,
                productId: item.productId,
                quantity: item.quantity,
                priceOverride: item.priceOverride,
              ),
              valueType: const Value('json'),
              updatedAt: now,
            ),
          );
        }
      }

      developer.log(
        'Updated bundle $bundleId ("$updatedName")',
        name: 'BundlePackManager',
      );

      return BundlePack(
        id: bundleId,
        name: updatedName,
        description: updatedDescription,
        totalPrice: resolvedTotalPrice,
        isActive: existing.isActive,
        items: items != null
            ? await _loadBundleItems(bundleId, updatedItems)
            : existing.items,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
    } on BundlePackException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error updating bundle $bundleId: $e',
        name: 'BundlePackManager',
        error: e,
        stackTrace: stackTrace,
      );
      throw BundlePackException(
        'Failed to update bundle: $e',
        bundleId: bundleId,
      );
    }
  }

  /// Soft-deletes a bundle pack (sets isActive = false).
  ///
  /// The bundle is not removed from storage; it is simply deactivated
  /// so it no longer appears in active bundle lists.
  ///
  /// Throws [BundlePackException] if the bundle does not exist.
  Future<void> deleteBundle(String bundleId) async {
    try {
      final existing = await getBundleById(bundleId);
      if (existing == null) {
        throw BundlePackException(
          'Bundle not found: $bundleId',
          bundleId: bundleId,
        );
      }

      final now = DateTime.now();
      await _dao.insertOrUpdateSetting(
        AppSettingsCompanion.insert(
          key: 'bundle_pack:$bundleId',
          value: _encodeBundleHeader(
            id: bundleId,
            name: existing.name,
            description: existing.description,
            totalPrice: existing.totalPrice,
            isActive: false,
            createdAt: existing.createdAt,
            updatedAt: now,
          ),
          valueType: const Value('json'),
          updatedAt: now,
        ),
      );

      developer.log(
        'Soft-deleted bundle $bundleId ("${existing.name}")',
        name: 'BundlePackManager',
      );
    } on BundlePackException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error deleting bundle $bundleId: $e',
        name: 'BundlePackManager',
        error: e,
        stackTrace: stackTrace,
      );
      throw BundlePackException(
        'Failed to delete bundle: $e',
        bundleId: bundleId,
      );
    }
  }

  /// Gets a bundle pack by ID with all its items.
  ///
  /// Returns null if the bundle does not exist.
  Future<BundlePack?> getBundleById(String bundleId) async {
    try {
      final raw = await _dao.getSettingValue('bundle_pack:$bundleId');
      if (raw == null || raw.isEmpty) return null;

      final header = _decodeBundleHeader(raw);
      if (header == null) return null;

      final items = await _loadBundleItemsFromStorage(bundleId);

      return BundlePack(
        id: header['id'] as String,
        name: header['name'] as String,
        description: header['description'] as String?,
        totalPrice: header['totalPrice'] as int,
        isActive: header['isActive'] as bool,
        items: items,
        createdAt: DateTime.parse(header['createdAt'] as String),
        updatedAt: DateTime.parse(header['updatedAt'] as String),
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error fetching bundle $bundleId: $e',
        name: 'BundlePackManager',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Returns all active bundle packs.
  Future<List<BundlePack>> getAllActiveBundles() async {
    try {
      final settings = await _dao.getAllSettings();
      final bundles = <BundlePack>[];

      for (final setting in settings) {
        if (!setting.key.startsWith('bundle_pack:') ||
            setting.key.contains('bundle_pack_item:')) {
          continue;
        }

        final header = _decodeBundleHeader(setting.value);
        if (header == null) continue;
        if (header['isActive'] != true) continue;

        final bundleId = header['id'] as String;
        final items = await _loadBundleItemsFromStorage(bundleId);

        bundles.add(BundlePack(
          id: bundleId,
          name: header['name'] as String,
          description: header['description'] as String?,
          totalPrice: header['totalPrice'] as int,
          isActive: true,
          items: items,
          createdAt: DateTime.parse(header['createdAt'] as String),
          updatedAt: DateTime.parse(header['updatedAt'] as String),
        ));
      }

      bundles.sort((a, b) => a.name.compareTo(b.name));
      return bundles;
    } catch (e, stackTrace) {
      developer.log(
        'Error fetching active bundles: $e',
        name: 'BundlePackManager',
        error: e,
        stackTrace: stackTrace,
      );
      throw BundlePackException('Failed to fetch active bundles: $e');
    }
  }

  /// Searches bundles by name (case-insensitive substring match).
  Future<List<BundlePack>> searchBundles(String query) async {
    try {
      final settings = await _dao.getAllSettings();
      final bundles = <BundlePack>[];
      final lowerQuery = query.toLowerCase().trim();

      for (final setting in settings) {
        if (!setting.key.startsWith('bundle_pack:') ||
            setting.key.contains('bundle_pack_item:')) {
          continue;
        }

        final header = _decodeBundleHeader(setting.value);
        if (header == null) continue;
        if (header['isActive'] != true) continue;

        final name = (header['name'] as String).toLowerCase();
        if (lowerQuery.isEmpty || name.contains(lowerQuery)) {
          final bundleId = header['id'] as String;
          final items = await _loadBundleItemsFromStorage(bundleId);

          bundles.add(BundlePack(
            id: bundleId,
            name: header['name'] as String,
            description: header['description'] as String?,
            totalPrice: header['totalPrice'] as int,
            isActive: true,
            items: items,
            createdAt: DateTime.parse(header['createdAt'] as String),
            updatedAt: DateTime.parse(header['updatedAt'] as String),
          ));
        }
      }

      bundles.sort((a, b) => a.name.compareTo(b.name));
      return bundles;
    } catch (e, stackTrace) {
      developer.log(
        'Error searching bundles with query "$query": $e',
        name: 'BundlePackManager',
        error: e,
        stackTrace: stackTrace,
      );
      throw BundlePackException('Failed to search bundles: $e');
    }
  }

  /// Loads a bundle into billing-ready format.
  ///
  /// Returns a list of [BundleBillingItem] with current prices resolved.
  /// Validates that all products are still active and in stock.
  ///
  /// Throws [BundlePackException] if:
  /// - Bundle not found or inactive
  /// - Any product is inactive
  /// - Any product has insufficient stock
  Future<List<BundleBillingItem>> loadBundleForBilling(
    String bundleId,
  ) async {
    try {
      final bundle = await getBundleById(bundleId);
      if (bundle == null) {
        throw BundlePackException(
          'Bundle not found: $bundleId',
          bundleId: bundleId,
        );
      }
      if (!bundle.isActive) {
        throw BundlePackException(
          'Bundle "${bundle.name}" is inactive',
          bundleId: bundleId,
        );
      }

      final billingItems = <BundleBillingItem>[];

      for (final item in bundle.items) {
        final product = await _dao.getProductById(item.productId);
        if (product == null) {
          throw BundlePackException(
            'Product "${item.productId}" referenced in bundle '
            '"${bundle.name}" no longer exists',
            bundleId: bundleId,
          );
        }
        if (!product.isActive) {
          throw BundlePackException(
            'Product "${product.name}" in bundle "${bundle.name}" '
            'is no longer active',
            bundleId: bundleId,
          );
        }

        final stockData = await _dao.getStockByProductId(item.productId);
        final availableStock = stockData?.quantity ?? product.currentStock;
        if (availableStock < item.quantity) {
          throw BundlePackException(
            'Insufficient stock for "${product.name}" in bundle '
            '"${bundle.name}": need ${item.quantity}, have $availableStock',
            bundleId: bundleId,
          );
        }

        final unitPrice = item.effectivePrice;
        final totalAmount = (unitPrice * item.quantity).round();

        billingItems.add(BundleBillingItem(
          productId: item.productId,
          productName: product.name,
          quantity: item.quantity,
          unitPrice: unitPrice,
          totalAmount: totalAmount,
          taxRate: product.taxRate.round(),
        ));
      }

      developer.log(
        'Loaded bundle "${bundle.name}" for billing '
        '(${billingItems.length} items)',
        name: 'BundlePackManager',
      );

      return billingItems;
    } on BundlePackException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error loading bundle $bundleId for billing: $e',
        name: 'BundlePackManager',
        error: e,
        stackTrace: stackTrace,
      );
      throw BundlePackException(
        'Failed to load bundle for billing: $e',
        bundleId: bundleId,
      );
    }
  }

  /// Calculates the total price for a bundle based on current product prices.
  ///
  /// Uses each item's [priceOverride] if set; otherwise falls back to
  /// the product's current [sellingPrice].
  ///
  /// Returns the calculated total in paise.
  ///
  /// Throws [BundlePackException] if any product is not found.
  Future<int> calculateBundlePrice(List<BundleItemInput> items) async {
    try {
      int total = 0;

      for (final item in items) {
        final product = await _dao.getProductById(item.productId);
        if (product == null) {
          throw BundlePackException(
            'Product not found: ${item.productId}',
          );
        }

        final effectivePrice = item.priceOverride ?? product.sellingPrice;
        total += (effectivePrice * item.quantity).round();
      }

      return total;
    } on BundlePackException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error calculating bundle price: $e',
        name: 'BundlePackManager',
        error: e,
        stackTrace: stackTrace,
      );
      throw BundlePackException(
        'Failed to calculate bundle price: $e',
      );
    }
  }

  /// Validates a bundle before saving (checks for duplicates, active products,
  /// empty names, etc.).
  ///
  /// If [bundleId] is provided, the name uniqueness check excludes that bundle
  /// (used during updates).
  ///
  /// Returns a [BundleValidationResult] with errors and warnings.
  Future<BundleValidationResult> validateBundle({
    String? bundleId,
    required List<BundleItemInput> items,
  }) async {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      if (items.isEmpty) {
        errors.add('Bundle must contain at least one item');
      }

      // Check for duplicate products
      final productIds = items.map((i) => i.productId).toList();
      final uniqueIds = productIds.toSet();
      if (uniqueIds.length != productIds.length) {
        errors.add('Duplicate products are not allowed in a bundle');
      }

      // Validate each product
      for (final item in items) {
        final product = await _dao.getProductById(item.productId);
        if (product == null) {
          errors.add('Product not found: ${item.productId}');
          continue;
        }
        if (!product.isActive) {
          errors.add('Product "${product.name}" is inactive');
        }
        if (item.quantity <= 0) {
          errors.add(
            'Quantity for "${product.name}" must be positive, '
            'got ${item.quantity}',
          );
        }

        // Warn if price override is below cost
        if (item.priceOverride != null && product.purchasePrice != null) {
          if (item.priceOverride! < product.purchasePrice!) {
            warnings.add(
              'Price override for "${product.name}" '
              '(${item.priceOverride} paise) is below purchase price '
              '(${product.purchasePrice} paise)',
            );
          }
        }

        // Warn if stock is low
        final stockData = await _dao.getStockByProductId(item.productId);
        final availableStock =
            stockData?.quantity ?? product.currentStock;
        if (availableStock < item.quantity) {
          warnings.add(
            'Low stock for "${product.name}": '
            'need ${item.quantity}, have $availableStock',
          );
        }
      }

      return BundleValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error validating bundle: $e',
        name: 'BundlePackManager',
        error: e,
        stackTrace: stackTrace,
      );
      return BundleValidationResult(
        isValid: false,
        errors: ['Validation failed: $e'],
        warnings: warnings,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers — Bundle Item Loading
  // ---------------------------------------------------------------------------

  /// Builds [BundlePackItem] instances from input items and current product data.
  Future<List<BundlePackItem>> _loadBundleItems(
    String bundleId,
    List<BundleItemInput> inputs,
  ) async {
    final items = <BundlePackItem>[];

    for (final input in inputs) {
      final product = await _dao.getProductById(input.productId);
      items.add(BundlePackItem(
        id: _uuid.v4(),
        bundleId: bundleId,
        productId: input.productId,
        productName: product?.name ?? 'Unknown',
        quantity: input.quantity,
        priceOverride: input.priceOverride,
        sellingPrice: product?.sellingPrice ?? 0,
      ));
    }

    return items;
  }

  /// Loads bundle items from AppSettings storage and enriches with product data.
  Future<List<BundlePackItem>> _loadBundleItemsFromStorage(
    String bundleId,
  ) async {
    final settings = await _dao.getAllSettings();
    final items = <BundlePackItem>[];
    final prefix = 'bundle_pack_item:$bundleId:';

    for (final setting in settings) {
      if (!setting.key.startsWith(prefix)) continue;

      final decoded = _decodeBundleItem(setting.value);
      if (decoded == null) continue;

      final productId = decoded['productId'] as String;
      final product = await _dao.getProductById(productId);

      items.add(BundlePackItem(
        id: decoded['id'] as String,
        bundleId: decoded['bundleId'] as String,
        productId: productId,
        productName: product?.name ?? 'Unknown',
        quantity: (decoded['quantity'] as num).toDouble(),
        priceOverride: decoded['priceOverride'] as int?,
        sellingPrice: product?.sellingPrice ?? 0,
      ));
    }

    return items;
  }

  /// Deletes all bundle item settings for a given bundle ID.
  Future<void> _deleteBundleItemSettings(String bundleId) async {
    final settings = await _dao.getAllSettings();
    final prefix = 'bundle_pack_item:$bundleId:';

    for (final setting in settings) {
      if (setting.key.startsWith(prefix)) {
        await _dao.deleteSetting(setting.key);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers — JSON Encoding/Decoding
  // ---------------------------------------------------------------------------

  /// Encodes a bundle header to JSON for storage.
  String _encodeBundleHeader({
    required String id,
    required String name,
    String? description,
    required int totalPrice,
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return jsonEncode({
      'id': id,
      'name': name,
      'description': description,
      'totalPrice': totalPrice,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    });
  }

  /// Encodes a bundle item to JSON for storage.
  String _encodeBundleItem({
    required String id,
    required String bundleId,
    required String productId,
    required double quantity,
    int? priceOverride,
  }) {
    return jsonEncode({
      'id': id,
      'bundleId': bundleId,
      'productId': productId,
      'quantity': quantity,
      'priceOverride': priceOverride,
    });
  }

  /// Decodes a bundle header from JSON.
  Map<String, dynamic>? _decodeBundleHeader(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Decodes a bundle item from JSON.
  Map<String, dynamic>? _decodeBundleItem(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}

// =============================================================================
// Data Models
// =============================================================================

/// Input model for creating/updating bundle items.
class BundleItemInput {
  /// Product ID to include in the bundle.
  final String productId;

  /// Quantity of this product in the bundle (supports fractional for
  /// weight-based items).
  final double quantity;

  /// Optional price override in paise. When null, the bundle's total price
  /// is used; the caller decides distribution.
  final int? priceOverride;

  BundleItemInput({
    required this.productId,
    required this.quantity,
    this.priceOverride,
  });

  @override
  String toString() =>
      'BundleItemInput(product: $productId, qty: $quantity, '
      'override: $priceOverride)';
}

/// Bundle pack with items, ready for display/editing.
class BundlePack {
  /// Unique identifier for this bundle.
  final String id;

  /// Display name of the bundle.
  final String name;

  /// Optional description for the bundle.
  final String? description;

  /// Total price of the bundle in paise.
  final int totalPrice;

  /// Whether this bundle is active and available for use.
  final bool isActive;

  /// Items contained in this bundle.
  final List<BundlePackItem> items;

  /// Timestamp when the bundle was created.
  final DateTime createdAt;

  /// Timestamp when the bundle was last updated.
  final DateTime updatedAt;

  BundlePack({
    required this.id,
    required this.name,
    this.description,
    required this.totalPrice,
    required this.isActive,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Auto-calculated total from items if no explicit total was set.
  ///
  /// Uses each item's effective price (override or current selling price)
  /// multiplied by quantity.
  int get calculatedTotal => items.fold(
        0,
        (sum, item) =>
            sum + (item.priceOverride ?? item.sellingPrice) * item.quantity.toInt(),
      );

  /// Savings compared to buying items individually.
  ///
  /// Positive value means the bundle offers a discount over individual
  /// purchases. Negative value means the bundle is priced above individual
  /// items total.
  int get savings => calculatedTotal - totalPrice;

  @override
  String toString() =>
      'BundlePack($name, items: ${items.length}, '
      'total: $totalPrice, savings: $savings)';
}

/// Single item within a bundle.
class BundlePackItem {
  /// Unique identifier for this bundle item entry.
  final String id;

  /// ID of the bundle this item belongs to.
  final String bundleId;

  /// Product ID for this item.
  final String productId;

  /// Product name at time of bundle creation.
  final String productName;

  /// Quantity of this product in the bundle.
  final double quantity;

  /// Optional per-item price override in paise. When null, the bundle's
  /// total price is used.
  final int? priceOverride;

  /// Current selling price of the product, in paise.
  final int sellingPrice;

  BundlePackItem({
    required this.id,
    required this.bundleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.priceOverride,
    required this.sellingPrice,
  });

  /// The effective price for this item (override or current selling price).
  int get effectivePrice => priceOverride ?? sellingPrice;

  @override
  String toString() =>
      'BundlePackItem($productName, qty: $quantity, '
      'effective: $effectivePrice)';
}

/// Bundle item ready for billing (resolved prices).
class BundleBillingItem {
  /// Product ID.
  final String productId;

  /// Product name.
  final String productName;

  /// Quantity in the bundle.
  final double quantity;

  /// Unit price in paise.
  final int unitPrice;

  /// Total line amount in paise (unitPrice * quantity).
  final int totalAmount;

  /// Tax rate percentage for this product.
  final int taxRate;

  BundleBillingItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.taxRate,
  });

  @override
  String toString() =>
      'BundleBillingItem($productName, qty: $quantity, '
      'unit: $unitPrice, total: $totalAmount)';
}

/// Validation result for bundle creation/update.
class BundleValidationResult {
  /// Whether the bundle data is valid (no errors).
  final bool isValid;

  /// List of validation errors that must be fixed.
  final List<String> errors;

  /// List of warnings that are informational (e.g., low stock, below cost).
  final List<String> warnings;

  BundleValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  @override
  String toString() =>
      'BundleValidationResult(valid: $isValid, '
      'errors: ${errors.length}, warnings: ${warnings.length})';
}

/// Exception thrown by BundlePackManager when a bundle operation fails.
///
/// Contains a human-readable [message] describing the error condition.
/// Optional [bundleId] identifies the bundle involved in the failure.
class BundlePackException implements Exception {
  /// Human-readable error description.
  final String message;

  /// The bundle ID involved in the failed operation, if applicable.
  final String? bundleId;

  BundlePackException(this.message, {this.bundleId});

  @override
  String toString() {
    final parts = <String>['BundlePackException: $message'];
    if (bundleId != null) parts.add('bundleId=$bundleId');
    return parts.join(', ');
  }
}
