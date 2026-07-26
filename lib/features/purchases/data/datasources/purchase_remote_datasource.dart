import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/purchase_entity.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';

/// Abstract contract for remote purchase order operations.
///
/// Defines the interface for communicating with the purchases API endpoints.
/// Implementations handle HTTP requests, JSON serialization, and error mapping.
abstract class PurchaseRemoteDataSource {
  /// Fetches a paginated list of purchase orders with optional filters.
  ///
  /// [supplierId] filters by supplier.
  /// [startDate] and [endDate] filter by date range.
  /// [page] and [perPage] control pagination.
  Future<List<Purchase>> getPurchases({
    String? supplierId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 20,
  });

  /// Fetches a single purchase order by its unique [id].
  Future<Purchase> getPurchaseById(String id);

  /// Creates a new purchase order from the provided [purchase] entity.
  Future<Purchase> createPurchase(Purchase purchase);

  /// Updates an existing purchase order.
  Future<Purchase> updatePurchase(Purchase purchase);

  /// Deletes the purchase order identified by [id].
  Future<void> deletePurchase(String id);

  /// Marks a purchase order as received with the given [receivedItems].
  ///
  /// Updates inventory stock levels for the received items.
  Future<Purchase> receivePurchase({
    required String purchaseId,
    required List<PurchaseItem> receivedItems,
  });
}

/// Remote data source implementation for purchase order endpoints.
///
/// Communicates with `/purchases` REST endpoints using the base URL
/// from [AppConstants].
class PurchaseRemoteDataSourceImpl implements PurchaseRemoteDataSource {
  final http.Client _client;

  /// Creates a [PurchaseRemoteDataSourceImpl] with the given HTTP [client].
  PurchaseRemoteDataSourceImpl({required http.Client client}) : _client = client;

  PurchaseItem _parsePurchaseItem(Map<String, dynamic> json) {
    return PurchaseItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: json['unitPrice'] as int,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: json['taxAmount'] as int? ?? 0,
      totalAmount: json['totalAmount'] as int,
      batchNumber: json['batchNumber'] as String?,
    );
  }

  Purchase _parsePurchase(Map<String, dynamic> json) {
    final items = (json['items'] as List?)
            ?.map((e) => _parsePurchaseItem(e as Map<String, dynamic>))
            .toList() ??
        [];
    return Purchase(
      id: json['id'] as String,
      purchaseNumber: json['purchaseNumber'] as String,
      supplierId: json['supplierId'] as String?,
      supplierName: json['supplierName'] as String?,
      purchaseDate: DateTime.parse(json['purchaseDate'] as String),
      subtotal: json['subtotal'] as int,
      taxAmount: json['taxAmount'] as int? ?? 0,
      totalAmount: json['totalAmount'] as int,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int? ?? 1,
      items: items,
    );
  }

  Map<String, dynamic> _purchaseToJson(Purchase p) {
    return {
      'id': p.id,
      'purchaseNumber': p.purchaseNumber,
      'supplierId': p.supplierId,
      'supplierName': p.supplierName,
      'purchaseDate': p.purchaseDate.toIso8601String(),
      'subtotal': p.subtotal,
      'taxAmount': p.taxAmount,
      'totalAmount': p.totalAmount,
      'status': p.status,
      'createdAt': p.createdAt.toIso8601String(),
      'updatedAt': p.updatedAt.toIso8601String(),
      'version': p.version,
      'items': p.items
          .map((item) => {
                'id': item.id,
                'productId': item.productId,
                'productName': item.productName,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'taxRate': item.taxRate,
                'taxAmount': item.taxAmount,
                'totalAmount': item.totalAmount,
                'batchNumber': item.batchNumber,
              })
          .toList(),
    };
  }

  @override
  Future<List<Purchase>> getPurchases({
    String? supplierId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (supplierId != null && supplierId.isNotEmpty) {
      queryParams['supplier_id'] = supplierId;
    }
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;

    final url = Uri.parse('${AppConstants.baseUrl}/purchases')
        .replace(queryParameters: queryParams);
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data is Map<String, dynamic> && data.containsKey('data')
          ? data['data'] as List
          : data as List;
      return items
          .map((e) => _parsePurchase(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ServerException(
        message: 'Failed to fetch purchases: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Purchase> getPurchaseById(String id) async {
    final url = Uri.parse('${AppConstants.baseUrl}/purchases/$id');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return _parsePurchase(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to fetch purchase: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Purchase> createPurchase(Purchase purchase) async {
    final url = Uri.parse('${AppConstants.baseUrl}/purchases');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(_purchaseToJson(purchase)),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _parsePurchase(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to create purchase: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Purchase> updatePurchase(Purchase purchase) async {
    final url = Uri.parse('${AppConstants.baseUrl}/purchases/${purchase.id}');
    final response = await _client.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(_purchaseToJson(purchase)),
    );

    if (response.statusCode == 200) {
      return _parsePurchase(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to update purchase: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<void> deletePurchase(String id) async {
    final url = Uri.parse('${AppConstants.baseUrl}/purchases/$id');
    final response = await _client.delete(url);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ServerException(
        message: 'Failed to delete purchase: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Purchase> receivePurchase({
    required String purchaseId,
    required List<PurchaseItem> receivedItems,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/purchases/$purchaseId/receive');
    final body = {
      'receivedItems': receivedItems
          .map((item) => {
                'id': item.id,
                'productId': item.productId,
                'productName': item.productName,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'taxRate': item.taxRate,
                'taxAmount': item.taxAmount,
                'totalAmount': item.totalAmount,
                'batchNumber': item.batchNumber,
              })
          .toList(),
    };

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _parsePurchase(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to receive purchase: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}
