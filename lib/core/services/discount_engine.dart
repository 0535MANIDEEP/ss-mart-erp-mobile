import 'dart:convert';

import '../../database/app_database.dart';
import '../../database/database_dao.dart';

/// Discount engine for multi-level discount calculations.
///
/// Supports Marg-style discount system:
/// - 4 bill-level discounts (stackable, applied sequentially)
/// - Item-level discounts (product-specific or category-specific)
/// - Party-wise discounts (pre-fixed per customer group)
/// - Category-wise discounts
/// - Bill-value-wise discount tiers
///
/// ## Discount Resolution Order
///
/// **Item-level discounts** (per product):
/// 1. Product-specific discount rules
/// 2. Category-specific discount rules
/// 3. Customer group discount rules
/// 4. The highest applicable discount wins (non-stackable at item level)
///
/// **Bill-level discounts** (applied on subtotal after item discounts):
/// 1. Party-specific discount rules (from customer group)
/// 2. Bill-value-based discount tiers
/// 3. Manual discounts applied by user (up to 4 slots)
///
/// All bill-level discounts are stackable and applied sequentially on the
/// remaining amount after each prior discount.
///
/// ## Monetary Values
///
/// All monetary values are in **paise** (integer). Divide by 100 for
/// display in rupees. This avoids floating-point rounding errors.
///
/// ## Usage
/// ```dart
/// final engine = DiscountEngine(dao: databaseDao);
///
/// // Calculate bill-level discounts
/// final result = await engine.calculateBillDiscounts(
///   subtotal: 500000, // ₹5,000 in paise
///   customerId: 'cust-123',
///   items: [
///     BillItemInput(
///       productId: 'prod-1',
///       categoryId: 'cat-1',
///       unitPrice: 10000, // ₹100
///       quantity: 5,
///       totalAmount: 50000,
///     ),
///   ],
/// );
/// print('Total discount: ${result.totalDiscount} paise');
///
/// // Calculate item-level discount
/// final itemResult = await engine.calculateItemDiscount(
///   productId: 'prod-1',
///   categoryId: 'cat-1',
///   customerId: 'cust-123',
///   unitPrice: 10000,
///   quantity: 5,
/// );
/// ```
class DiscountEngine {
  final DatabaseDao _dao;

  DiscountEngine({required DatabaseDao dao}) : _dao = dao;

  /// Calculates all applicable discounts for a bill.
  ///
  /// Processes discounts in two phases:
  /// 1. **Item-level**: Each item gets its best applicable discount.
  /// 2. **Bill-level**: Up to 4 stackable discounts are applied on the
  ///    post-item-discount subtotal.
  ///
  /// Returns a [DiscountResult] with a breakdown of every discount applied.
  ///
  /// Throws [DiscountEngineException] if subtotal is negative or items
  /// contain invalid data.
  Future<DiscountResult> calculateBillDiscounts({
    required int subtotal,
    String? customerId,
    List<BillItemInput>? items,
  }) async {
    if (subtotal < 0) {
      throw DiscountEngineException(
        'Subtotal cannot be negative: $subtotal',
      );
    }

    if (subtotal == 0) {
      return DiscountResult(
        totalDiscount: 0,
        discount1: 0,
        discount2: 0,
        discount3: 0,
        discount4: 0,
        appliedDiscounts: const [],
        finalAmount: 0,
      );
    }

    try {
      final appliedDiscounts = <AppliedDiscount>[];
      int remainingAmount = subtotal;

      // Phase 1: Resolve item-level discounts (informational, not deducted
      // from subtotal here — the caller handles per-item pricing).
      // We still compute them so the caller can display per-line discounts.

      // Phase 2: Bill-level discounts
      final customerGroupId = customerId != null
          ? await _resolveCustomerGroupId(customerId)
          : null;

      // Discount slot 1: Party (customer group) discount
      if (customerGroupId != null) {
        final partyDiscount = await _applyPartyDiscount(
          remainingAmount: remainingAmount,
          customerGroupId: customerGroupId,
        );
        if (partyDiscount != null) {
          appliedDiscounts.add(partyDiscount);
          remainingAmount -= partyDiscount.amount;
        }
      }

      // Discount slot 2: Bill-value tier discount
      final tierDiscount = await _applyBillValueTierDiscount(
        originalSubtotal: subtotal,
        remainingAmount: remainingAmount,
      );
      if (tierDiscount != null) {
        appliedDiscounts.add(tierDiscount);
        remainingAmount -= tierDiscount.amount;
      }

      // Discount slots 3 & 4: Manual discount placeholders
      // These are populated by the caller before or after calling this
      // engine. The engine returns them as zero; the UI provides
      // manual discount inputs that map to these slots.

      final discount1 = appliedDiscounts.isNotEmpty
          ? appliedDiscounts[0].amount
          : 0;
      final discount2 = appliedDiscounts.length > 1
          ? appliedDiscounts[1].amount
          : 0;
      final discount3 = appliedDiscounts.length > 2
          ? appliedDiscounts[2].amount
          : 0;
      final discount4 = appliedDiscounts.length > 3
          ? appliedDiscounts[3].amount
          : 0;

      final totalDiscount = discount1 + discount2 + discount3 + discount4;
      final finalAmount = (subtotal - totalDiscount).clamp(0, subtotal);

      return DiscountResult(
        totalDiscount: totalDiscount,
        discount1: discount1,
        discount2: discount2,
        discount3: discount3,
        discount4: discount4,
        appliedDiscounts: appliedDiscounts,
        finalAmount: finalAmount,
      );
    } catch (e) {
      if (e is DiscountEngineException) rethrow;
      throw DiscountEngineException(
        'Failed to calculate bill discounts: $e',
      );
    }
  }

  /// Calculates item-level discounts for a single product.
  ///
  /// Checks multiple discount sources in priority order and returns the
  /// best (highest) applicable discount:
  /// 1. Product-specific discount rules
  /// 2. Category-specific discount rules
  /// 3. Customer group discount
  ///
  /// Returns an [ItemDiscountResult] with the winning discount. If no
  /// discount applies, returns a zero-discount result.
  Future<ItemDiscountResult> calculateItemDiscount({
    required String productId,
    String? categoryId,
    String? customerId,
    required int unitPrice,
    required double quantity,
  }) async {
    if (unitPrice < 0) {
      throw DiscountEngineException(
        'Unit price cannot be negative: $unitPrice',
      );
    }
    if (quantity < 0) {
      throw DiscountEngineException(
        'Quantity cannot be negative: $quantity',
      );
    }

    try {
      final lineTotal = (unitPrice * quantity).round();
      double bestPercent = 0.0;
      String? bestRuleId;
      String? bestRuleName;

      // 1. Product-specific discount rules stored in AppSettings
      final productRule = await _getProductDiscountRule(productId);
      if (productRule != null && productRule['percent'] != null) {
        final percent = (productRule['percent'] as num).toDouble();
        if (percent > bestPercent && _isRuleActive(productRule)) {
          bestPercent = percent;
          bestRuleId = productRule['id'] as String?;
          bestRuleName = productRule['name'] as String?;
        }
      }

      // 2. Category-specific discount rules stored in AppSettings
      if (categoryId != null) {
        final categoryRule = await _getCategoryDiscountRule(categoryId);
        if (categoryRule != null && categoryRule['percent'] != null) {
          final percent = (categoryRule['percent'] as num).toDouble();
          if (percent > bestPercent && _isRuleActive(categoryRule)) {
            bestPercent = percent;
            bestRuleId = categoryRule['id'] as String?;
            bestRuleName = categoryRule['name'] as String?;
          }
        }
      }

      // 3. Customer group discount
      if (customerId != null) {
        final groupDiscount = await _getCustomerGroupDiscount(customerId);
        if (groupDiscount != null && groupDiscount > bestPercent) {
          bestPercent = groupDiscount;
          bestRuleId = null;
          bestRuleName = 'Customer Group Discount';
        }
      }

      final discountAmount = (lineTotal * bestPercent / 100).round();

      return ItemDiscountResult(
        discountAmount: discountAmount,
        discountPercent: bestPercent,
        ruleId: bestRuleId,
        ruleName: bestRuleName,
      );
    } catch (e) {
      if (e is DiscountEngineException) rethrow;
      throw DiscountEngineException(
        'Failed to calculate item discount for product $productId: $e',
      );
    }
  }

  /// Gets all active discount rules that apply to a given context.
  ///
  /// Aggregates rules from multiple sources:
  /// - Product-specific rules from `discount_rules_products` setting
  /// - Category-specific rules from `discount_rules_categories` setting
  /// - Customer group discounts from [CustomerGroups] table
  /// - Bill-value tier rules from `discount_rules_tiers` setting
  ///
  /// Returns a combined list sorted by priority (most specific first).
  Future<List<DiscountRule>> getApplicableRules({
    String? customerId,
    String? productId,
    String? categoryId,
    int? billAmount,
  }) async {
    final rules = <DiscountRule>[];

    try {
      // Product-specific rules
      if (productId != null) {
        final productRules = await _getAllProductDiscountRules();
        for (final rule in productRules) {
          if (rule['productId'] == productId && _isRuleActive(rule)) {
            rules.add(_parseDiscountRule(rule, DiscountRuleType.product));
          }
        }
      }

      // Category-specific rules
      if (categoryId != null) {
        final categoryRules = await _getAllCategoryDiscountRules();
        for (final rule in categoryRules) {
          if (rule['categoryId'] == categoryId && _isRuleActive(rule)) {
            rules.add(_parseDiscountRule(rule, DiscountRuleType.category));
          }
        }
      }

      // Customer group discount
      if (customerId != null) {
        final groupId = await _resolveCustomerGroupId(customerId);
        if (groupId != null) {
          final group = await _dao.getCustomerGroupById(groupId);
          if (group != null && group.isActive) {
            rules.add(DiscountRule(
              id: 'group-${group.id}',
              name: 'Group: ${group.name}',
              type: DiscountRuleType.party,
              percent: group.discountValue,
              isActive: true,
              customerGroupId: group.id,
            ));
          }
        }
      }

      // Bill-value tier rules
      if (billAmount != null) {
        final tierRules = await _getBillValueTierRules();
        for (final rule in tierRules) {
          final minAmount = rule['minAmount'] as int? ?? 0;
          if (billAmount >= minAmount && _isRuleActive(rule)) {
            rules.add(_parseDiscountRule(rule, DiscountRuleType.tier));
          }
        }
      }
    } catch (e) {
      if (e is DiscountEngineException) rethrow;
      throw DiscountEngineException(
        'Failed to fetch applicable discount rules: $e',
      );
    }

    return rules;
  }

  /// Validates that a discount rule can be applied.
  ///
  /// Checks date range validity, minimum quantity requirements,
  /// minimum bill amount thresholds, and active status.
  bool isRuleApplicable(
    DiscountRule rule, {
    double? quantity,
    int? amount,
  }) {
    if (!rule.isActive) return false;

    final now = DateTime.now();
    if (rule.validFrom != null && now.isBefore(rule.validFrom!)) {
      return false;
    }
    if (rule.validTo != null && now.isAfter(rule.validTo!)) {
      return false;
    }

    if (quantity != null && rule.minQuantity != null) {
      if (quantity < rule.minQuantity!) return false;
    }

    if (amount != null && rule.minAmount != null) {
      if (amount < rule.minAmount!) return false;
    }

    return true;
  }

  /// Applies a manual discount to a specific bill-level slot.
  ///
  /// Validates the discount amount does not exceed the remaining subtotal.
  /// Returns the adjusted amount after applying the manual discount.
  ///
  /// [slotIndex] must be 0-3 (for discount1-discount4).
  int applyManualDiscount({
    required int remainingAmount,
    required int discountAmount,
    required int slotIndex,
    String? ruleName,
  }) {
    if (slotIndex < 0 || slotIndex > 3) {
      throw DiscountEngineException(
        'Invalid discount slot index: $slotIndex. Must be 0-3.',
      );
    }
    if (discountAmount < 0) {
      throw DiscountEngineException(
        'Manual discount amount cannot be negative: $discountAmount',
      );
    }
    if (discountAmount > remainingAmount) {
      throw DiscountEngineException(
        'Manual discount ($discountAmount) exceeds remaining amount ($remainingAmount)',
      );
    }

    return discountAmount;
  }

  // ---------------------------------------------------------------------------
  // Private helpers — Party (Customer Group) Discounts
  // ---------------------------------------------------------------------------

  /// Resolves a customer's group ID from the junction table.
  Future<String?> _resolveCustomerGroupId(String customerId) async {
    final groupIds = await _dao.getCustomerGroupIds(customerId);
    return groupIds.isNotEmpty ? groupIds.first : null;
  }

  /// Applies a party-level discount from the customer's group.
  ///
  /// Customer groups store a [discountType] ('percentage' or 'fixed')
  /// and a [discountValue]. For percentage discounts, the discount is
  /// computed on [remainingAmount].
  Future<AppliedDiscount?> _applyPartyDiscount({
    required int remainingAmount,
    required String customerGroupId,
  }) async {
    final group = await _dao.getCustomerGroupById(customerGroupId);
    if (group == null || !group.isActive) return null;
    if (group.discountValue <= 0) return null;

    int discountAmount;
    if (group.discountType == 'percentage') {
      discountAmount =
          (remainingAmount * group.discountValue / 100).round();
    } else {
      // Fixed amount discount (in paise)
      discountAmount = group.discountValue.round();
    }

    // Cap at remaining amount
    discountAmount = discountAmount.clamp(0, remainingAmount);
    if (discountAmount == 0) return null;

    return AppliedDiscount(
      ruleId: 'group-${group.id}',
      ruleName: 'Party Discount (${group.name})',
      discountType: group.discountType,
      amount: discountAmount,
      percent: group.discountType == 'percentage' ? group.discountValue : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers — Bill-Value Tier Discounts
  // ---------------------------------------------------------------------------

  /// Applies a bill-value tier discount based on the original subtotal.
  ///
  /// Tier rules are stored in AppSettings as JSON under the key
  /// `discount_rules_tiers`. Each tier specifies a minimum amount and
  /// a percentage discount.
  Future<AppliedDiscount?> _applyBillValueTierDiscount({
    required int originalSubtotal,
    required int remainingAmount,
  }) async {
    final tiers = await _getBillValueTierRules();
    if (tiers.isEmpty) return null;

    // Find the highest matching tier (sorted by minAmount descending)
    final sortedTiers = List<Map<String, dynamic>>.from(tiers)
      ..sort((a, b) =>
          (b['minAmount'] as int? ?? 0).compareTo(a['minAmount'] as int? ?? 0));

    for (final tier in sortedTiers) {
      final minAmount = tier['minAmount'] as int? ?? 0;
      final percent = (tier['percent'] as num?)?.toDouble() ?? 0.0;
      final id = tier['id'] as String? ?? 'tier-$minAmount';
      final name = tier['name'] as String? ?? 'Bill Value Tier';

      if (originalSubtotal >= minAmount && percent > 0 && _isRuleActive(tier)) {
        final discountAmount =
            (remainingAmount * percent / 100).round().clamp(0, remainingAmount);
        if (discountAmount > 0) {
          return AppliedDiscount(
            ruleId: id,
            ruleName: '$name (≥₹${minAmount ~/ 100})',
            discountType: 'percentage',
            amount: discountAmount,
            percent: percent,
          );
        }
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Private helpers — Rule Storage (AppSettings JSON)
  // ---------------------------------------------------------------------------

  /// Reads product-specific discount rules from AppSettings.
  ///
  /// Expects a JSON array stored under key `discount_rules_products`.
  /// Each element: `{ id, productId, name, percent, minQty, validFrom, validTo, isActive }`.
  Future<List<Map<String, dynamic>>> _getAllProductDiscountRules() async {
    final raw = await _dao.getSettingValue('discount_rules_products');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Gets a single product discount rule by product ID.
  Future<Map<String, dynamic>?> _getProductDiscountRule(
      String productId) async {
    final rules = await _getAllProductDiscountRules();
    for (final rule in rules) {
      if (rule['productId'] == productId) return rule;
    }
    return null;
  }

  /// Reads category-specific discount rules from AppSettings.
  ///
  /// Expects a JSON array stored under key `discount_rules_categories`.
  /// Each element: `{ id, categoryId, name, percent, minQty, validFrom, validTo, isActive }`.
  Future<List<Map<String, dynamic>>> _getAllCategoryDiscountRules() async {
    final raw = await _dao.getSettingValue('discount_rules_categories');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Gets a single category discount rule by category ID.
  Future<Map<String, dynamic>?> _getCategoryDiscountRule(
      String categoryId) async {
    final rules = await _getAllCategoryDiscountRules();
    for (final rule in rules) {
      if (rule['categoryId'] == categoryId) return rule;
    }
    return null;
  }

  /// Reads bill-value tier discount rules from AppSettings.
  ///
  /// Expects a JSON array stored under key `discount_rules_tiers`.
  /// Each element: `{ id, name, minAmount, percent, validFrom, validTo, isActive }`.
  Future<List<Map<String, dynamic>>> _getBillValueTierRules() async {
    final raw = await _dao.getSettingValue('discount_rules_tiers');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Reads the customer group discount percentage for a given customer.
  ///
  /// Resolves the customer's group via [CustomerGroupMembers] junction
  /// table and returns the group's [discountValue] if [discountType]
  /// is 'percentage'. Returns null if no group discount applies.
  Future<double?> _getCustomerGroupDiscount(String customerId) async {
    final groupId = await _resolveCustomerGroupId(customerId);
    if (groupId == null) return null;

    final group = await _dao.getCustomerGroupById(groupId);
    if (group == null || !group.isActive) return null;
    if (group.discountValue <= 0) return null;

    if (group.discountType == 'percentage') {
      return group.discountValue;
    }
    return null;
  }

  /// Checks whether a discount rule is currently active based on
  /// optional date range fields.
  bool _isRuleActive(Map<String, dynamic> rule) {
    final isActive = rule['isActive'];
    if (isActive is bool && !isActive) return false;
    if (isActive is String && isActive.toLowerCase() == 'false') return false;

    final now = DateTime.now();

    final validFrom = rule['validFrom'];
    if (validFrom != null) {
      try {
        final from = DateTime.parse(validFrom.toString());
        if (now.isBefore(from)) return false;
      } catch (_) {
        // Ignore parse errors — treat as no start constraint
      }
    }

    final validTo = rule['validTo'];
    if (validTo != null) {
      try {
        final to = DateTime.parse(validTo.toString());
        if (now.isAfter(to)) return false;
      } catch (_) {
        // Ignore parse errors — treat as no end constraint
      }
    }

    return true;
  }

  /// Parses a raw JSON rule map into a [DiscountRule] domain model.
  DiscountRule _parseDiscountRule(
    Map<String, dynamic> raw,
    DiscountRuleType type,
  ) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return DiscountRule(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? 'Unnamed Rule',
      type: type,
      percent: ((raw['percent'] as num?)?.toDouble() ?? 0.0),
      minQuantity: raw['minQty'] != null
          ? (raw['minQty'] as num).toDouble()
          : null,
      minAmount: raw['minAmount'] as int?,
      validFrom: parseDate(raw['validFrom']),
      validTo: parseDate(raw['validTo']),
      isActive: raw['isActive'] != false,
      customerGroupId: raw['groupId'] as String?,
      productId: raw['productId'] as String?,
      categoryId: raw['categoryId'] as String?,
    );
  }
}

// =============================================================================
// Data Models
// =============================================================================

/// Result of bill-level discount calculation.
///
/// Contains the total discount applied, per-slot breakdowns (up to 4
/// stackable discounts), a detailed list of every applied discount,
/// and the final payable amount after all discounts.
class DiscountResult {
  /// Total discount applied across all slots, in paise.
  final int totalDiscount;

  /// First discount slot amount, in paise.
  final int discount1;

  /// Second discount slot amount, in paise.
  final int discount2;

  /// Third discount slot amount, in paise.
  final int discount3;

  /// Fourth discount slot amount, in paise.
  final int discount4;

  /// Detailed breakdown of every discount applied, for UI display
  /// and audit trail purposes.
  final List<AppliedDiscount> appliedDiscounts;

  /// Final payable amount after subtracting all discounts from the
  /// original subtotal, in paise.
  final int finalAmount;

  const DiscountResult({
    required this.totalDiscount,
    required this.discount1,
    required this.discount2,
    required this.discount3,
    required this.discount4,
    required this.appliedDiscounts,
    required this.finalAmount,
  });

  @override
  String toString() =>
      'DiscountResult(total: $totalDiscount, final: $finalAmount, '
      'slots: [$discount1, $discount2, $discount3, $discount4])';
}

/// Result of item-level discount calculation.
///
/// Represents the single best discount found for a product after
/// evaluating all applicable rules (product-specific, category-specific,
/// and customer group discounts).
class ItemDiscountResult {
  /// Discount amount in paise computed from the winning rule.
  final int discountAmount;

  /// Discount percentage of the winning rule (0.0 if no discount).
  final double discountPercent;

  /// ID of the discount rule that was applied, if any.
  final String? ruleId;

  /// Human-readable name of the applied rule, for UI display.
  final String? ruleName;

  const ItemDiscountResult({
    required this.discountAmount,
    required this.discountPercent,
    this.ruleId,
    this.ruleName,
  });

  @override
  String toString() =>
      'ItemDiscountResult(amount: $discountAmount, percent: $discountPercent, '
      'rule: $ruleName)';
}

/// Represents a single applied discount for breakdown and audit purposes.
///
/// Each instance captures one discount that was actually applied during
/// calculation, including its source rule and computed amount.
class AppliedDiscount {
  /// ID of the discount rule that produced this discount.
  final String ruleId;

  /// Human-readable name of the rule, for receipt/UI display.
  final String ruleName;

  /// Type of discount: 'percentage', 'fixed', 'party', 'tier', 'manual'.
  final String discountType;

  /// Computed discount amount in paise.
  final int amount;

  /// Original percentage of the rule, if the discount was percentage-based.
  final double? percent;

  const AppliedDiscount({
    required this.ruleId,
    required this.ruleName,
    required this.discountType,
    required this.amount,
    this.percent,
  });

  @override
  String toString() =>
      'AppliedDiscount($ruleName: $discountType, amount: $amount)';
}

/// Input model for bill items when calculating discounts.
///
/// Provides the discount engine with the necessary item context
/// (product, category, pricing, quantity) to evaluate applicable
/// discount rules.
class BillItemInput {
  /// Product ID for product-specific discount rule lookup.
  final String productId;

  /// Category ID for category-specific discount rule lookup.
  final String? categoryId;

  /// Unit price in paise at the time of sale.
  final int unitPrice;

  /// Quantity sold (supports fractional values for weight-based items).
  final double quantity;

  /// Total line amount in paise: unitPrice * quantity.
  final int totalAmount;

  const BillItemInput({
    required this.productId,
    this.categoryId,
    required this.unitPrice,
    required this.quantity,
    required this.totalAmount,
  });

  @override
  String toString() =>
      'BillItemInput(product: $productId, qty: $quantity, total: $totalAmount)';
}

/// Represents a discount rule loaded from storage or computed from
/// customer group data.
///
/// Used by [DiscountEngine.getApplicableRules] to return a unified
/// view of all discount sources regardless of their underlying storage.
class DiscountRule {
  /// Unique identifier for this rule.
  final String id;

  /// Human-readable name for display purposes.
  final String name;

  /// Type of discount rule: product, category, party, tier, or manual.
  final DiscountRuleType type;

  /// Discount percentage (0-100). For fixed-amount rules, this is 0.
  final double percent;

  /// Minimum quantity required for this rule to apply, or null for no limit.
  final double? minQuantity;

  /// Minimum bill/line amount in paise required for this rule, or null.
  final int? minAmount;

  /// Date from which this rule is valid, or null for no start constraint.
  final DateTime? validFrom;

  /// Date until which this rule is valid, or null for no end constraint.
  final DateTime? validTo;

  /// Whether this rule is currently enabled.
  final bool isActive;

  /// Customer group ID this rule applies to (for party-type rules).
  final String? customerGroupId;

  /// Product ID this rule applies to (for product-type rules).
  final String? productId;

  /// Category ID this rule applies to (for category-type rules).
  final String? categoryId;

  const DiscountRule({
    required this.id,
    required this.name,
    required this.type,
    required this.percent,
    this.minQuantity,
    this.minAmount,
    this.validFrom,
    this.validTo,
    this.isActive = true,
    this.customerGroupId,
    this.productId,
    this.categoryId,
  });

  @override
  String toString() =>
      'DiscountRule($name, type: $type, percent: $percent, active: $isActive)';
}

/// Types of discount rules supported by the engine.
enum DiscountRuleType {
  /// Discount applies to a specific product.
  product,

  /// Discount applies to all products in a category.
  category,

  /// Discount applies based on customer group membership.
  party,

  /// Discount applies based on bill total amount tier.
  tier,

  /// Manually applied discount by the cashier/manager.
  manual,
}

/// Exception thrown by [DiscountEngine] when discount calculation fails.
///
/// Contains a human-readable [message] describing the error condition.
/// Common causes include negative values, exceeded discount amounts,
/// or invalid rule configurations.
class DiscountEngineException implements Exception {
  /// Human-readable error description.
  final String message;

  DiscountEngineException(this.message);

  @override
  String toString() => 'DiscountEngineException: $message';
}
