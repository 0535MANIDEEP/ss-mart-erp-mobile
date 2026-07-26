import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';

/// Abstract contract for remote product operations.
///
/// Defines the interface for communicating with the products API endpoints.
/// Implementations handle HTTP requests, JSON serialization, and error mapping.
abstract class ProductRemoteDataSource {
  /// Fetches a paginated list of products with optional filters.
  ///
  /// [search] filters by product name or barcode.
  /// [categoryId] filters by category.
  /// [page] and [perPage] control pagination.
  Future<List<Map<String, dynamic>>> getProducts({
    String? search,
    String? categoryId,
    int page = 1,
    int perPage = 20,
  });

  /// Fetches a single product by its unique [id].
  Future<Map<String, dynamic>> getProductById(String id);

  /// Fetches a single product by its [barcode] value.
  Future<Map<String, dynamic>> getProductByBarcode(String barcode);

  /// Creates a new product from the provided [product] data map.
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> product);

  /// Updates an existing product identified by [id] with [product] data.
  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> product);

  /// Deletes the product identified by [id].
  Future<void> deleteProduct(String id);
}

/// Remote data source implementation for product endpoints.
///
/// Communicates with `/products` REST endpoints using the base URL
/// from [AppConstants].
class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final http.Client _client;

  /// Creates a [ProductRemoteDataSourceImpl] with the given HTTP [client].
  ProductRemoteDataSourceImpl({required http.Client client}) : _client = client;

  @override
  Future<List<Map<String, dynamic>>> getProducts({
    String? search,
    String? categoryId,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      queryParams['category_id'] = categoryId;
    }

    final url = Uri.parse('${AppConstants.baseUrl}/products')
        .replace(queryParameters: queryParams);
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data is Map<String, dynamic> && data.containsKey('data')
          ? data['data'] as List
          : data as List;
      return items.cast<Map<String, dynamic>>();
    } else {
      throw ServerException(
        message: 'Failed to fetch products: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getProductById(String id) async {
    final url = Uri.parse('${AppConstants.baseUrl}/products/$id');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ServerException(
        message: 'Failed to fetch product: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getProductByBarcode(String barcode) async {
    final url = Uri.parse('${AppConstants.baseUrl}/products/barcode/$barcode');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ServerException(
        message: 'Failed to fetch product by barcode: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> product) async {
    final url = Uri.parse('${AppConstants.baseUrl}/products');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(product),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ServerException(
        message: 'Failed to create product: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> product) async {
    final url = Uri.parse('${AppConstants.baseUrl}/products/$id');
    final response = await _client.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(product),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ServerException(
        message: 'Failed to update product: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    final url = Uri.parse('${AppConstants.baseUrl}/products/$id');
    final response = await _client.delete(url);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ServerException(
        message: 'Failed to delete product: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}
