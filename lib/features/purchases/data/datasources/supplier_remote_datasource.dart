import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';

/// Remote data source for Supplier API operations.
///
/// Handles HTTP communication with the backend REST API for supplier
/// CRUD operations. Uses standard REST endpoints under /api/suppliers.
abstract class SupplierRemoteDataSource {
  Future<List<Map<String, dynamic>>> getAll();
  Future<Map<String, dynamic>?> getById(String id);
  Future<Map<String, dynamic>> create(Map<String, dynamic> data);
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
}

class SupplierRemoteDataSourceImpl implements SupplierRemoteDataSource {
  final http.Client client;

  SupplierRemoteDataSourceImpl({required this.client});

  String get _baseUrl => '${AppConstants.baseUrl}/suppliers';

  @override
  Future<List<Map<String, dynamic>>> getAll() async {
    final response = await client.get(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load suppliers: ${response.statusCode}');
  }

  @override
  Future<Map<String, dynamic>?> getById(String id) async {
    final response = await client.get(
      Uri.parse('$_baseUrl/$id'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 404) return null;
    throw Exception('Failed to load supplier: ${response.statusCode}');
  }

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final response = await client.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create supplier: ${response.statusCode}');
  }

  @override
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    final response = await client.put(
      Uri.parse('$_baseUrl/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update supplier: ${response.statusCode}');
  }

  @override
  Future<void> delete(String id) async {
    final response = await client.delete(
      Uri.parse('$_baseUrl/$id'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete supplier: ${response.statusCode}');
    }
  }
}
