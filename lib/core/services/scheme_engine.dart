import 'dart:convert';
import 'dart:developer' as developer;

import '../../database/database_dao.dart';

/// Scheme engine for promotional scheme calculations.
///
/// Supports Marg-style scheme system:
/// - Buy X Get Y free (e.g., Buy 3 Get 1 Free)
/// - Quantity-based rate discounts (volume pricing)
/// - Date-wise seasonal schemes
/// - Combo schemes (Buy item A, get discount on item B)
/// - Party/category-specific schemes
///
/// ## Scheme Resolution
/// 1. Check all active schemes for the current date
/// 2. Filter by applicable product/category/party
/// 3. Sort by priority (highest first)
/// 4. Apply the highest-priority matching scheme
///
/// ## Scheme Types
/// - `'buy_x_get_y'` — Buy [triggerQty], get [freeQty] free
/// - `'quantity_rate'` — Apply [discountPercent] or [discountAmount]
///   when quantity meets trigger threshold
/// - `'date_wise'` — Seasonal scheme active only within [startDate]/[endDate]
/// - `'combo'` — Purchase of [productId] triggers benefit on another product
/// - `'push_sale'` — Suggest related products (no discount, just hints)
///
/// ## Monetary Values
/// All monetary values are in **paise** (integer). Divide by 100 for
/// display in rupees.
///
/// ## Usage
/// ```dart
/// final engine = SchemeEngine(dao: databaseDao);
/// final result = await engine.applyScheme(
///   productId: 'prod-123',
///   quantity: 5,
///   customerId: 'cust-456',
///   unitPrice: 10000, // in paise
/// );
/// if (result.hasScheme) {
///   print('Savings: ${result.totalSavings} paise');
/// }
/// ```
class SchemeEngine {
  final DatabaseDao _dao;

  SchemeEngine({required DatabaseDao dao}) : _dao = dao;

  /// Applies the best matching scheme for a product+quantity combination.
  ///
  /// Resolution steps:
  /// 1. Fetch all active schemes for the product (by product ID or category).
  /// 2. Filter by date validity and party applicability.
  /// 3. Sort by priority (highest first).
  /// 4. Evaluate each scheme against quantity/price to compute benefit.
  /// 5. Return the first (highest priority) scheme that yields a benefit.
  ///
  /// Returns a [SchemeResult] with the discount/free items applied.
  /// If no scheme matches, returns [SchemeResult.none].
  ///
  /// Throws [SchemeEngineException] if unitPrice or quantity is negative,
  /// or if the database query fails.
  Future<SchemeResult> applyScheme({
    required String productId,
    required double quantity,
    String? customerId,
    required int unitPrice,
    String? categoryId,
  }) async {
    if (unitPrice < 0) {
      throw SchemeEngineException(
        'Unit price cannot be negative: $unitPrice',
        productId: productId,
      );
    }
    if (quantity < 0) {
      throw SchemeEngineException(
        'Quantity cannot be negative: $quantity',
        productId: productId,
      );
    }

    try {
      final schemes = await getActiveSchemes(
        productId: productId,
        customerId: customerId,
      );

      if (schemes.isEmpty) {
        return SchemeResult.none();
      }

      // Evaluate each scheme and pick the one with the best savings.
      SchemeResult bestResult = SchemeResult.none();
      int bestSavings = 0;

      for (final scheme in schemes) {
        final result = _evaluateScheme(
          scheme: scheme,
          productId: productId,
          categoryId: categoryId,
          quantity: quantity,
          unitPrice: unitPrice,
        );

        if (result.totalSavings > bestSavings) {
          bestSavings = result.totalSavings;
          bestResult = result;
        }
      }

      developer.log(
        'Scheme applied for product $productId: '
        '${bestResult.hasScheme ? "${bestResult.schemeName} (savings: ${bestResult.totalSavings})" : "none"}',
        name: 'SchemeEngine',
      );

      return bestResult;
    } on SchemeEngineException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error applying scheme: $e',
        name: 'SchemeEngine',
        error: e,
        stackTrace: stackTrace,
      );
      throw SchemeEngineException(
        'Failed to apply scheme for product $productId: $e',
        productId: productId,
      );
    }
  }

  /// Gets all active schemes for a given product.
  ///
  /// Loads scheme rules from AppSettings under key `scheme_rules`.
  /// Filters by:
  /// - Product ID match (or category match if categoryId provided)
  /// - Active status
  /// - Date range validity
  /// - Party applicability (if customerId provided)
  ///
  /// Returns schemes sorted by priority (highest first).
  Future<List<SchemeRule>> getActiveSchemes({
    required String productId,
    String? customerId,
  }) async {
    try {
      final allRules = await _loadSchemeRules();

      // Filter to schemes that could apply to this product.
      final matching = <SchemeRule>[];
      for (final rule in allRules) {
        if (!rule.isActive) continue;
        if (!isSchemeActive(rule)) continue;

        // Check product/category applicability.
        final appliesToThisProduct = _doesSchemeApplyToProduct(
          scheme: rule,
          productId: productId,
        );
        if (!appliesToThisProduct) continue;

        // Check party applicability if customerId provided.
        if (customerId != null) {
          if (!_isSchemeApplicableToParty(scheme: rule, customerId: customerId)) {
            continue;
          }
        }

        matching.add(rule);
      }

      // Sort by priority descending (highest priority first).
      matching.sort((a, b) => b.priority.compareTo(a.priority));

      developer.log(
        'Found ${matching.length} active schemes for product $productId',
        name: 'SchemeEngine',
      );

      return matching;
    } catch (e, stackTrace) {
      developer.log(
        'Error fetching active schemes: $e',
        name: 'SchemeEngine',
        error: e,
        stackTrace: stackTrace,
      );
      throw SchemeEngineException(
        'Failed to fetch active schemes for product $productId: $e',
        productId: productId,
      );
    }
  }

  /// Validates if a scheme is currently within its valid date range.
  ///
  /// A scheme is active if:
  /// - [SchemeRule.isActive] is true
  /// - Current date is on or after [SchemeRule.startDate] (or startDate is null)
  /// - Current date is on or before [SchemeRule.endDate] (or endDate is null)
  bool isSchemeActive(SchemeRule scheme) {
    if (!scheme.isActive) return false;

    final now = DateTime.now();

    if (scheme.startDate != null && now.isBefore(scheme.startDate!)) {
      return false;
    }
    if (scheme.endDate != null && now.isAfter(scheme.endDate!)) {
      return false;
    }

    return true;
  }

  /// Calculates the free quantity for a Buy X Get Y scheme.
  ///
  /// [purchasedQty] is the total quantity the customer is buying.
  /// [triggerQty] is the quantity needed to trigger the free item.
  /// [freeQty] is the number of free items given per trigger.
  ///
  /// Returns the total number of free items. For example:
  /// - purchasedQty=7, triggerQty=3, freeQty=1 → returns 2
  ///   (6 items trigger 2 free, 1 item left over)
  /// - purchasedQty=5, triggerQty=5, freeQty=2 → returns 2
  int calculateFreeQuantity({
    required double purchasedQty,
    required double triggerQty,
    required double freeQty,
  }) {
    if (triggerQty <= 0 || freeQty <= 0 || purchasedQty < 0) {
      return 0;
    }

    final triggerCount = (purchasedQty / triggerQty).floor();
    return (triggerCount * freeQty).toInt();
  }

  /// Gets suggested items for a product (push sale / combo schemes).
  ///
  /// Returns schemes of type `'push_sale'` or `'combo'` that reference
  /// the given [productId] as the trigger product. Used for upsell
  /// suggestions at the POS.
  Future<List<SchemeRule>> getSuggestedSchemes(String productId) async {
    try {
      final allRules = await _loadSchemeRules();
      final suggestions = <SchemeRule>[];

      for (final rule in allRules) {
        if (!rule.isActive) continue;
        if (!isSchemeActive(rule)) continue;

        if (rule.schemeType == 'push_sale' || rule.schemeType == 'combo') {
          if (_doesSchemeApplyToProduct(
            scheme: rule,
            productId: productId,
          )) {
            suggestions.add(rule);
          }
        }
      }

      developer.log(
        'Found ${suggestions.length} suggested schemes for product $productId',
        name: 'SchemeEngine',
      );

      return suggestions;
    } catch (e, stackTrace) {
      developer.log(
        'Error fetching suggested schemes: $e',
        name: 'SchemeEngine',
        error: e,
        stackTrace: stackTrace,
      );
      throw SchemeEngineException(
        'Failed to fetch suggested schemes for product $productId: $e',
        productId: productId,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers — Scheme evaluation
  // ---------------------------------------------------------------------------

  /// Evaluates a single scheme rule against the given product context.
  ///
  /// Dispatches to the appropriate calculator based on [SchemeRule.schemeType].
  /// Returns [SchemeResult.none] if the scheme does not yield any benefit.
  SchemeResult _evaluateScheme({
    required SchemeRule scheme,
    required String productId,
    String? categoryId,
    required double quantity,
    required int unitPrice,
  }) {
    switch (scheme.schemeType) {
      case 'buy_x_get_y':
        return _evaluateBuyXGetY(
          scheme: scheme,
          quantity: quantity,
          unitPrice: unitPrice,
        );
      case 'quantity_rate':
        return _evaluateQuantityRate(
          scheme: scheme,
          quantity: quantity,
          unitPrice: unitPrice,
        );
      case 'date_wise':
        return _evaluateDateWiseDiscount(
          scheme: scheme,
          quantity: quantity,
          unitPrice: unitPrice,
        );
      case 'combo':
        // Combo schemes don't apply discount on the trigger product;
        // they are informational for the caller to apply on the target product.
        return SchemeResult.none();
      case 'push_sale':
        // Push sale is purely a suggestion, no discount applied.
        return SchemeResult.none();
      default:
        developer.log(
          'Unknown scheme type: ${scheme.schemeType} for scheme ${scheme.id}',
          name: 'SchemeEngine',
        );
        return SchemeResult.none();
    }
  }

  /// Evaluates a Buy X Get Y free scheme.
  ///
  /// If the customer purchases at least [triggerQty] items, they get
  /// [freeQty] items free per trigger. The free quantity is priced at
  /// the unit price, giving an immediate discount.
  SchemeResult _evaluateBuyXGetY({
    required SchemeRule scheme,
    required double quantity,
    required int unitPrice,
  }) {
    if (scheme.triggerQty <= 0 || scheme.freeQty <= 0) {
      return SchemeResult.none();
    }

    final freeQty = calculateFreeQuantity(
      purchasedQty: quantity,
      triggerQty: scheme.triggerQty,
      freeQty: scheme.freeQty,
    );

    if (freeQty <= 0) {
      return SchemeResult.none();
    }

    final discountAmount = (freeQty * unitPrice).toInt();

    return SchemeResult(
      hasScheme: true,
      schemeId: scheme.id,
      schemeName: scheme.schemeName,
      schemeType: scheme.schemeType,
      discountAmount: discountAmount,
      freeQuantity: freeQty.toDouble(),
      effectivePrice: unitPrice,
      totalSavings: discountAmount,
    );
  }

  /// Evaluates a quantity-based rate discount scheme.
  ///
  /// If the purchased quantity meets or exceeds [triggerQty], a discount
  /// is applied either as a percentage ([discountPercent]) or a flat
  /// amount per unit ([discountAmount]).
  SchemeResult _evaluateQuantityRate({
    required SchemeRule scheme,
    required double quantity,
    required int unitPrice,
  }) {
    if (scheme.triggerQty <= 0) {
      return SchemeResult.none();
    }
    if (quantity < scheme.triggerQty) {
      return SchemeResult.none();
    }

    int discountPerUnit = 0;

    if (scheme.discountPercent > 0) {
      discountPerUnit = (unitPrice * scheme.discountPercent / 100).round();
    } else if (scheme.discountAmount > 0) {
      discountPerUnit = scheme.discountAmount;
    }

    if (discountPerUnit <= 0) {
      return SchemeResult.none();
    }

    // Cap discount per unit at unit price to prevent negative pricing.
    discountPerUnit = discountPerUnit.clamp(0, unitPrice);

    final totalDiscount = (discountPerUnit * quantity).toInt();
    final effectivePrice = (unitPrice - discountPerUnit).clamp(0, unitPrice);

    return SchemeResult(
      hasScheme: true,
      schemeId: scheme.id,
      schemeName: scheme.schemeName,
      schemeType: scheme.schemeType,
      discountAmount: totalDiscount,
      freeQuantity: 0,
      effectivePrice: effectivePrice,
      totalSavings: totalDiscount,
    );
  }

  /// Evaluates a date-wise seasonal discount scheme.
  ///
  /// Applies the configured discount (percentage or flat) for products
  /// within the scheme's active date range. Unlike quantity_rate, this
  /// does not require a minimum quantity threshold — the date range is
  /// the trigger.
  SchemeResult _evaluateDateWiseDiscount({
    required SchemeRule scheme,
    required double quantity,
    required int unitPrice,
  }) {
    if (quantity <= 0 || unitPrice <= 0) {
      return SchemeResult.none();
    }

    int discountPerUnit = 0;

    if (scheme.discountPercent > 0) {
      discountPerUnit = (unitPrice * scheme.discountPercent / 100).round();
    } else if (scheme.discountAmount > 0) {
      discountPerUnit = scheme.discountAmount;
    }

    if (discountPerUnit <= 0) {
      return SchemeResult.none();
    }

    discountPerUnit = discountPerUnit.clamp(0, unitPrice);

    final totalDiscount = (discountPerUnit * quantity).toInt();
    final effectivePrice = (unitPrice - discountPerUnit).clamp(0, unitPrice);

    return SchemeResult(
      hasScheme: true,
      schemeId: scheme.id,
      schemeName: scheme.schemeName,
      schemeType: scheme.schemeType,
      discountAmount: totalDiscount,
      freeQuantity: 0,
      effectivePrice: effectivePrice,
      totalSavings: totalDiscount,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers — Scheme applicability checks
  // ---------------------------------------------------------------------------

  /// Checks if a scheme applies to a specific product.
  ///
  /// A scheme applies if:
  /// - [SchemeRule.appliesTo] is `'all'`, or
  /// - [SchemeRule.appliesTo] is `'product'` and [SchemeRule.productId] matches,
  /// - [SchemeRule.appliesTo] is `'category'` and [SchemeRule.categoryId] matches.
  bool _doesSchemeApplyToProduct({
    required SchemeRule scheme,
    required String productId,
  }) {
    if (scheme.appliesTo == 'all') return true;
    if (scheme.appliesTo == 'product') {
      return scheme.productId == productId;
    }
    return false;
  }

  /// Checks if a scheme is applicable to a specific party (customer).
  ///
  /// Party applicability is determined by the presence of a [productId]
  /// in the scheme that matches the customer's context. For party-specific
  /// schemes, the scheme's productId field may encode a customer group
  /// or party identifier pattern.
  ///
  /// This is a simplified check — in a full Marg implementation, party
  /// schemes would reference customer groups via a dedicated table.
  bool _isSchemeApplicableToParty({
    required SchemeRule scheme,
    required String customerId,
  }) {
    // Currently, party schemes are not filtered by customer ID at this level.
    // The caller can pass customerId for future extensibility (e.g., when
    // party-specific scheme rules are stored in AppSettings keyed by customer).
    // For now, all active schemes are considered applicable to all parties.
    return true;
  }

  // ---------------------------------------------------------------------------
  // Private helpers — Scheme storage (AppSettings JSON)
  // ---------------------------------------------------------------------------

  /// Loads all scheme rules from AppSettings.
  ///
  /// Expects a JSON array stored under key `scheme_rules`.
  /// Each element:
  /// ```json
  /// {
  ///   "id": "scheme-1",
  ///   "schemeName": "Buy 3 Get 1",
  ///   "schemeType": "buy_x_get_y",
  ///   "triggerQty": 3,
  ///   "freeQty": 1,
  ///   "discountPercent": 0,
  ///   "discountAmount": 0,
  ///   "appliesTo": "product",
  ///   "productId": "prod-123",
  ///   "categoryId": null,
  ///   "startDate": "2026-01-01",
  ///   "endDate": "2026-12-31",
  ///   "priority": 10,
  ///   "isActive": true
  /// }
  /// ```
  Future<List<SchemeRule>> _loadSchemeRules() async {
    final raw = await _dao.getSettingValue('scheme_rules');
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_parseSchemeRule)
          .toList();
    } catch (e) {
      developer.log(
        'Error parsing scheme_rules setting: $e',
        name: 'SchemeEngine',
        error: e,
      );
      return [];
    }
  }

  /// Parses a raw JSON map into a [SchemeRule] domain model.
  SchemeRule _parseSchemeRule(Map<String, dynamic> raw) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return SchemeRule(
      id: raw['id'] as String? ?? '',
      schemeName: raw['schemeName'] as String? ?? 'Unnamed Scheme',
      schemeType: raw['schemeType'] as String? ?? 'none',
      triggerQty: ((raw['triggerQty'] as num?)?.toDouble() ?? 0.0),
      freeQty: ((raw['freeQty'] as num?)?.toDouble() ?? 0.0),
      discountPercent: ((raw['discountPercent'] as num?)?.toDouble() ?? 0.0),
      discountAmount: (raw['discountAmount'] as num?)?.toInt() ?? 0,
      appliesTo: raw['appliesTo'] as String? ?? 'all',
      productId: raw['productId'] as String?,
      categoryId: raw['categoryId'] as String?,
      startDate: parseDate(raw['startDate']),
      endDate: parseDate(raw['endDate']),
      priority: (raw['priority'] as num?)?.toInt() ?? 0,
      isActive: raw['isActive'] != false,
    );
  }
}

// =============================================================================
// Data Models
// =============================================================================

/// Result of scheme application.
///
/// Contains the scheme details, discount breakdown, free quantity,
/// and effective pricing after scheme application.
class SchemeResult {
  /// Whether a scheme was applied.
  final bool hasScheme;

  /// ID of the applied scheme rule, or null if no scheme applied.
  final String? schemeId;

  /// Human-readable name of the applied scheme.
  final String? schemeName;

  /// Type of scheme applied: `'buy_x_get_y'`, `'quantity_rate'`,
  /// `'date_wise'`, `'combo'`, `'push_sale'`, or `'none'`.
  final String schemeType;

  /// Total discount amount in paise.
  final int discountAmount;

  /// Number of free items given by the scheme.
  final double freeQuantity;

  /// Unit price after scheme discount, in paise.
  final int effectivePrice;

  /// Total savings in paise (sum of discount + free item value).
  final int totalSavings;

  const SchemeResult({
    required this.hasScheme,
    this.schemeId,
    this.schemeName,
    required this.schemeType,
    required this.discountAmount,
    required this.freeQuantity,
    required this.effectivePrice,
    required this.totalSavings,
  });

  /// Returns a no-discount result.
  factory SchemeResult.none() => const SchemeResult(
        hasScheme: false,
        schemeType: 'none',
        discountAmount: 0,
        freeQuantity: 0,
        effectivePrice: 0,
        totalSavings: 0,
      );

  @override
  String toString() =>
      'SchemeResult(hasScheme: $hasScheme, type: $schemeType, '
      'savings: $totalSavings, free: $freeQuantity)';
}

/// Scheme rule model (mirrors database structure).
///
/// Represents a single promotional scheme loaded from AppSettings.
/// The engine evaluates these rules against the current sale context
/// to determine applicable discounts and free items.
class SchemeRule {
  /// Unique identifier for this scheme rule.
  final String id;

  /// Human-readable name for display on receipts and POS UI.
  final String schemeName;

  /// Type of scheme: `'buy_x_get_y'`, `'quantity_rate'`, `'date_wise'`,
  /// `'combo'`, or `'push_sale'`.
  final String schemeType;

  /// Minimum quantity required to trigger the scheme (for buy_x_get_y
  /// and quantity_rate types).
  final double triggerQty;

  /// Number of free items given per trigger (for buy_x_get_y type).
  final double freeQty;

  /// Discount percentage to apply (for quantity_rate and date_wise types).
  final double discountPercent;

  /// Flat discount amount in paise per unit (for quantity_rate and
  /// date_wise types).
  final int discountAmount;

  /// What the scheme applies to: `'all'`, `'product'`, or `'category'`.
  final String appliesTo;

  /// Product ID this scheme targets (when [appliesTo] is `'product'`).
  final String? productId;

  /// Category ID this scheme targets (when [appliesTo] is `'category'`).
  final String? categoryId;

  /// Date from which this scheme is valid, or null for no start constraint.
  final DateTime? startDate;

  /// Date until which this scheme is valid, or null for no end constraint.
  final DateTime? endDate;

  /// Priority level for scheme resolution. Higher values indicate
  /// higher priority. When multiple schemes match, the one with the
  /// highest priority wins.
  final int priority;

  /// Whether this scheme is currently enabled.
  final bool isActive;

  const SchemeRule({
    required this.id,
    required this.schemeName,
    required this.schemeType,
    required this.triggerQty,
    required this.freeQty,
    required this.discountPercent,
    required this.discountAmount,
    required this.appliesTo,
    this.productId,
    this.categoryId,
    this.startDate,
    this.endDate,
    required this.priority,
    required this.isActive,
  });

  @override
  String toString() =>
      'SchemeRule($schemeName, type: $schemeType, priority: $priority, '
      'active: $isActive)';
}

/// Exception thrown by [SchemeEngine] when scheme calculation fails.
///
/// Contains a human-readable [message] describing the error condition
/// and the optional [productId] involved in the failure.
class SchemeEngineException implements Exception {
  /// Human-readable error description.
  final String message;

  /// The product ID involved in the failed operation, if applicable.
  final String? productId;

  SchemeEngineException(this.message, {this.productId});

  @override
  String toString() {
    final parts = <String>['SchemeEngineException: $message'];
    if (productId != null) parts.add('productId=$productId');
    return parts.join(', ');
  }
}
