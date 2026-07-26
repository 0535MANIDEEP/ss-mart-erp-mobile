import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/stock_entity.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';

/// Abstract contract for remote stock/inventory operations.
///
/// Defines the interface for communicating with the stock API endpoints.
/// Implementations handle HTTP requests, JSON serialization, and error mapping.
abstract class StockRemoteDataSource {
  /// Fetches a paginated list of stock records with optional filters.
  ///
  /// [locationId] filters by warehouse location.
  /// [lowStockOnly] when true returns only low-stock items.
  /// [page] and [perPage] control pagination.
  Future<List<Stock>> getStock({
    String? locationId,
    bool lowStockOnly = false,
    int page = 1,
    int perPage = 20,
  });

  /// Fetches the stock record for a specific [productId].
  Future<Stock> getStockByProductId(String productId);

  /// Adjusts stock quantity for a product.
  ///
  /// [adjustmentType] is 'increase' or 'decrease'.
  /// [quantity] is the amount to adjust.
  /// [reason] and [batchNumber] are optional metadata.
  Future<Stock> adjustStock({
    required String productId,
    required String adjustmentType,
    required int quantity,
    String? reason,
    String? batchNumber,
  });

  /// Transfers stock between warehouse locations.
  ///
  /// Moves [quantity] units of [productId] from [fromLocationId] to [toLocationId].
  Future<Stock> transferStock({
    required String productId,
    required int quantity,
    required String fromLocationId,
    required String toLocationId,
    String? batchNumber,
  });

  /// Fetches all products with stock at or below the low-stock threshold.
  Future<List<Stock>> getLowStockProducts();
}

/// Remote data source implementation for stock/inventory endpoints.
///
/// Communicates with `/stock` REST endpoints using the base URL
/// from [AppConstants].
class StockRemoteDataSourceImpl implements StockRemoteDataSource {
  final http.Client _client;

  /// Creates a [StockRemoteDataSourceImpl] with the given HTTP [client].
  StockRemoteDataSourceImpl({required http.Client client}) : _client = client;

  Stock _parseStock(Map<String, dynamic> json) {
    return Stock(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      locationId: json['locationId'] as String? ?? 'MAIN',
      quantity: json['quantity'] as int,
      reservedQuantity: json['reservedQuantity'] as int? ?? 0,
      batchNumber: json['batchNumber'] as String?,
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  @override
  Future<List<Stock>> getStock({
    String? locationId,
    bool lowStockOnly = false,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      'low_stock_only': lowStockOnly.toString(),
    };
    if (locationId != null && locationId.isNotEmpty) {
      queryParams['location_id'] = locationId;
    }

    final url = Uri.parse('${AppConstants.baseUrl}/stock')
        .replace(queryParameters: queryParams);
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data is Map<String, dynamic> && data.containsKey('data')
          ? data['data'] as List
          : data as List;
      return items
          .map((e) => _parseStock(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ServerException(
        message: 'Failed to fetch stock: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Stock> getStockByProductId(String productId) async {
    final url = Uri.parse('${AppConstants.baseUrl}/stock/product/$productId');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return _parseStock(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to fetch stock by product: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Stock> adjustStock({
    required String productId,
    required String adjustmentType,
    required int quantity,
    String? reason,
    String? batchNumber,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/stock/adjust');
    final body = <String, dynamic>{
      'productId': productId,
      'adjustmentType': adjustmentType,
      'quantity': quantity,
    };
    if (reason != null) body['reason'] = reason;
    if (batchNumber != null) body['batchNumber'] = batchNumber;

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _parseStock(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to adjust stock: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Stock> transferStock({
    required String productId,
    required int quantity,
    required String fromLocationId,
    required String toLocationId,
    String? batchNumber,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/stock/transfer');
    final body = <String, dynamic>{
      'productId': productId,
      'quantity': quantity,
      'fromLocationId': fromLocationId,
      'toLocationId': toLocationId,
    };
    if (batchNumber != null) body['batchNumber'] = batchNumber;

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _parseStock(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to transfer stock: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<List<Stock>> getLowStockProducts() async {
    final url = Uri.parse('${AppConstants.baseUrl}/stock/low-stock');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data is Map<String, dynamic> && data.containsKey('data')
          ? data['data'] as List
          : data as List;
      return items
          .map((e) => _parseStock(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ServerException(
        message: 'Failed to fetch low-stock products: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}
