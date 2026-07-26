import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';

/// Abstract contract for remote customer operations.
///
/// Defines the interface for communicating with the customers API endpoints.
/// Implementations handle HTTP requests, JSON serialization, and error mapping.
abstract class CustomerRemoteDataSource {
  /// Fetches a paginated list of customers with optional filters.
  ///
  /// [search] filters by name or phone.
  /// [type] filters by customer type (e.g., 'regular', 'wholesale').
  /// [page] and [perPage] control pagination.
  Future<List<Map<String, dynamic>>> getCustomers({
    String? search,
    String? type,
    int page = 1,
    int perPage = 20,
  });

  /// Fetches a single customer by their unique [id].
  Future<Map<String, dynamic>> getCustomerById(String id);

  /// Fetches a single customer by their [phone] number.
  Future<Map<String, dynamic>> getCustomerByPhone(String phone);

  /// Creates a new customer from the provided [customer] data map.
  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> customer);

  /// Updates an existing customer identified by [id] with [customer] data.
  Future<Map<String, dynamic>> updateCustomer(String id, Map<String, dynamic> customer);

  /// Deletes the customer identified by [id].
  Future<void> deleteCustomer(String id);

  /// Fetches the purchase history for the customer identified by [customerId].
  Future<List<Map<String, dynamic>>> getCustomerHistory(String customerId);
}

/// Remote data source implementation for customer endpoints.
///
/// Communicates with `/customers` REST endpoints using the base URL
/// from [AppConstants].
class CustomerRemoteDataSourceImpl implements CustomerRemoteDataSource {
  final http.Client _client;

  /// Creates a [CustomerRemoteDataSourceImpl] with the given HTTP [client].
  CustomerRemoteDataSourceImpl({required http.Client client}) : _client = client;

  @override
  Future<List<Map<String, dynamic>>> getCustomers({
    String? search,
    String? type,
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
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }

    final url = Uri.parse('${AppConstants.baseUrl}/customers')
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
        message: 'Failed to fetch customers: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getCustomerById(String id) async {
    final url = Uri.parse('${AppConstants.baseUrl}/customers/$id');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ServerException(
        message: 'Failed to fetch customer: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getCustomerByPhone(String phone) async {
    final url = Uri.parse('${AppConstants.baseUrl}/customers/phone/$phone');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ServerException(
        message: 'Failed to fetch customer by phone: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> customer) async {
    final url = Uri.parse('${AppConstants.baseUrl}/customers');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(customer),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ServerException(
        message: 'Failed to create customer: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateCustomer(String id, Map<String, dynamic> customer) async {
    final url = Uri.parse('${AppConstants.baseUrl}/customers/$id');
    final response = await _client.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(customer),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ServerException(
        message: 'Failed to update customer: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    final url = Uri.parse('${AppConstants.baseUrl}/customers/$id');
    final response = await _client.delete(url);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ServerException(
        message: 'Failed to delete customer: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomerHistory(String customerId) async {
    final url = Uri.parse('${AppConstants.baseUrl}/customers/$customerId/history');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data is Map<String, dynamic> && data.containsKey('data')
          ? data['data'] as List
          : data as List;
      return items.cast<Map<String, dynamic>>();
    } else {
      throw ServerException(
        message: 'Failed to fetch customer history: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}
