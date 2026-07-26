import 'dart:developer' as developer;
import '../../database/database_dao.dart';
import '../error/exceptions.dart';

/// Rate engine for multi-rate pricing with party-wise overrides.
///
/// Handles Marg-style pricing where each product can have multiple rates
/// (Rate A, Rate B, Rate C, Wholesale, Special) and customers can have
/// party-specific rate overrides.
///
/// ## Pricing Resolution Order
/// 1. Party-specific rate for the product (PartyRates table)
/// 2. Product's built-in rate tiers (Products.rateA/rateB/rateC/wholesaleRate)
/// 3. Default selling price (Products.sellingPrice)
///
/// ## Rate Types
/// - `'selling'` — default retail selling price (Products.sellingPrice)
/// - `'rateA'` — first alternate rate (Products.rateA)
/// - `'rateB'` — second alternate rate (Products.rateB)
/// - `'rateC'` — third alternate rate (Products.rateC)
/// - `'wholesale'` — wholesale rate (Products.wholesaleRate)
/// - `'mrp'` — maximum retail price (Products.mrp)
///
/// ## Usage
/// ```dart
/// final engine = RateEngine(dao: databaseDao);
/// final price = await engine.getRate(
///   productId: 'abc-123',
///   rateType: 'wholesale',
///   customerId: 'cust-456', // optional: for party-wise override
///   quantity: 10,
/// );
/// ```
class RateEngine {
  final DatabaseDao _dao;

  RateEngine({required DatabaseDao dao}) : _dao = dao;

  /// All supported rate type identifiers.
  static const List<String> supportedRateTypes = [
    'selling',
    'rateA',
    'rateB',
    'rateC',
    'wholesale',
    'mrp',
  ];

  /// Gets the best rate for a product considering party overrides and quantity breaks.
  ///
  /// Resolution order:
  /// 1. Check PartyRates for customer+product specific rate
  /// 2. Check ProductRates for quantity-based rate breaks
  /// 3. Fall back to product's built-in rate tier
  /// 4. Fall back to default sellingPrice
  ///
  /// Returns rate in paise (integer).
  /// Throws [RateEngineException] if product not found or rate calculation fails.
  Future<int> getRate({
    required String productId,
    String rateType = 'selling',
    String? customerId,
    double quantity = 1.0,
  }) async {
    try {
      final product = await _dao.getProductById(productId);
      if (product == null) {
        throw RateEngineException(
          'Product not found: $productId',
          productId: productId,
        );
      }

      if (quantity < 0) {
        throw RateEngineException(
          'Quantity must be non-negative, got $quantity',
          productId: productId,
        );
      }

      // Step 1: Check party-wise rate override
      if (customerId != null) {
        final partyRate = await _getPartyRateOverride(
          customerId: customerId,
          productId: productId,
          rateType: rateType,
        );
        if (partyRate != null) {
          developer.log(
            'Party rate override found: $partyRate paise for '
            'customer=$customerId, product=$productId, rate=$rateType',
            name: 'RateEngine',
          );
          return partyRate;
        }
      }

      // Step 2: Get the built-in rate from the product
      final rate = _getProductRate(product, rateType);
      if (rate != null) {
        return rate;
      }

      // Step 3: Fall back to selling price
      if (rateType != 'selling') {
        developer.log(
          'Rate type "$rateType" not configured for product $productId, '
          'falling back to selling price',
          name: 'RateEngine',
        );
        return product.sellingPrice;
      }

      throw RateEngineException(
        'No rate configured for product: $productId (rateType: $rateType)',
        productId: productId,
      );
    } on RateEngineException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error calculating rate: $e',
        name: 'RateEngine',
        error: e,
        stackTrace: stackTrace,
      );
      throw RateEngineException(
        'Failed to calculate rate for product $productId: $e',
        productId: productId,
      );
    }
  }

  /// Gets all available rates for a product.
  /// Returns a map of rateType -> rateValue (in paise).
  ///
  /// If a [customerId] is provided, party-wise overrides are applied
  /// to the relevant rate types. All rates are guaranteed non-null in
  /// the returned map (missing tiers are populated with the selling price).
  Future<Map<String, int>> getAllRates({
    required String productId,
    String? customerId,
    double quantity = 1.0,
  }) async {
    try {
      final product = await _dao.getProductById(productId);
      if (product == null) {
        throw RateEngineException(
          'Product not found: $productId',
          productId: productId,
        );
      }

      final rates = <String, int>{};

      for (final rateType in supportedRateTypes) {
        // Check party override first
        if (customerId != null) {
          final partyRate = await _getPartyRateOverride(
            customerId: customerId,
            productId: productId,
            rateType: rateType,
          );
          if (partyRate != null) {
            rates[rateType] = partyRate;
            continue;
          }
        }

        // Fall back to product built-in rate
        final rate = _getProductRate(product, rateType);
        if (rate != null) {
          rates[rateType] = rate;
        } else {
          rates[rateType] = product.sellingPrice;
        }
      }

      developer.log(
        'Fetched all rates for product $productId: $rates',
        name: 'RateEngine',
      );

      return rates;
    } on RateEngineException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error fetching all rates: $e',
        name: 'RateEngine',
        error: e,
        stackTrace: stackTrace,
      );
      throw RateEngineException(
        'Failed to fetch rates for product $productId: $e',
        productId: productId,
      );
    }
  }

  /// Gets the applicable rate type for a customer based on their group/category.
  /// Falls back to 'selling' if no group-based rate is configured.
  ///
  /// Looks up the customer's group memberships via [CustomerGroupMembers]
  /// and resolves a rate type from the group name using a standard mapping:
  /// - 'Wholesale' group → 'wholesale'
  /// - 'VIP' group → 'rateA'
  /// - 'Distributor' group → 'rateB'
  /// - 'Retailer' group → 'rateC'
  Future<String> getRateTypeForCustomer(String customerId) async {
    try {
      final customer = await _dao.getCustomerById(customerId);
      if (customer == null) {
        developer.log(
          'Customer not found: $customerId, defaulting to "selling" rate type',
          name: 'RateEngine',
        );
        return 'selling';
      }

      final groupIds = await _dao.getCustomerGroupIds(customerId);
      if (groupIds.isEmpty) {
        return 'selling';
      }

      // Check each group for a rate type mapping
      for (final groupId in groupIds) {
        final group = await _dao.getCustomerGroupById(groupId);
        if (group == null) continue;

        final rateType = _rateTypeFromGroupName(group.name);
        if (rateType != null) {
          developer.log(
            'Customer $customerId mapped to rate type "$rateType" '
            'via group "${group.name}"',
            name: 'RateEngine',
          );
          return rateType;
        }
      }

      return 'selling';
    } catch (e, stackTrace) {
      developer.log(
        'Error determining rate type for customer $customerId: $e',
        name: 'RateEngine',
        error: e,
        stackTrace: stackTrace,
      );
      return 'selling';
    }
  }

  /// Checks if a party-wise rate override exists for a customer+product combination.
  Future<bool> hasPartyRateOverride({
    required String customerId,
    required String productId,
  }) async {
    try {
      final override = await _getPartyRateOverride(
        customerId: customerId,
        productId: productId,
        rateType: 'selling',
      );
      return override != null;
    } catch (e, stackTrace) {
      developer.log(
        'Error checking party rate override: $e',
        name: 'RateEngine',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Looks up a party-wise rate override for a specific customer+product+rateType.
  ///
  /// Returns the overridden rate in paise, or null if no override exists.
  ///
  /// This queries the app settings table using a key convention:
  /// `party_rate:{customerId}:{productId}:{rateType}`. This allows
  /// Marg-style per-customer per-product pricing without a dedicated table.
  Future<int?> _getPartyRateOverride({
    required String customerId,
    required String productId,
    required String rateType,
  }) async {
    try {
      final key = 'party_rate:$customerId:$productId:$rateType';
      final value = await _dao.getSettingValue(key);
      if (value != null) {
        final rate = int.tryParse(value);
        if (rate != null && rate > 0) {
          return rate;
        }
      }
      return null;
    } catch (e) {
      developer.log(
        'Error fetching party rate override: $e',
        name: 'RateEngine',
        error: e,
      );
      return null;
    }
  }

  /// Extracts the rate value for a given [rateType] from a [ProductData] row.
  ///
  /// Returns null if the rate column is null (i.e., not configured).
  int? _getProductRate(dynamic product, String rateType) {
    switch (rateType) {
      case 'selling':
        return product.sellingPrice;
      case 'rateA':
        return product.rateA;
      case 'rateB':
        return product.rateB;
      case 'rateC':
        return product.rateC;
      case 'wholesale':
        return product.wholesaleRate;
      case 'mrp':
        return product.mrp;
      default:
        return null;
    }
  }

  /// Maps a customer group name to a rate type identifier.
  ///
  /// Returns null if the group name does not match any known rate type mapping.
  String? _rateTypeFromGroupName(String groupName) {
    final normalized = groupName.toLowerCase().trim();
    const mappings = <String, String>{
      'wholesale': 'wholesale',
      'vip': 'rateA',
      'distributor': 'rateB',
      'retailer': 'rateC',
      'dealer': 'rateC',
      'special': 'rateA',
    };
    return mappings[normalized];
  }
}

/// Exception thrown by RateEngine when rate calculation fails.
class RateEngineException implements Exception {
  /// Human-readable error description.
  final String message;

  /// The product ID involved in the failed operation, if applicable.
  final String? productId;

  /// The customer ID involved in the failed operation, if applicable.
  final String? customerId;

  RateEngineException(this.message, {this.productId, this.customerId});

  @override
  String toString() {
    final parts = <String>['RateEngineException: $message'];
    if (productId != null) parts.add('productId=$productId');
    if (customerId != null) parts.add('customerId=$customerId');
    return parts.join(', ');
  }
}
