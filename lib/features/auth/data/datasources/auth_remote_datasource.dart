import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';

/// Abstract contract for remote authentication operations.
///
/// Defines the interface for communicating with the auth API endpoints.
/// Implementations handle HTTP requests, JSON serialization, and error mapping.
abstract class AuthRemoteDataSource {
  /// Authenticates a user with [username] and [password].
  ///
  /// Returns a map containing `accessToken`, `refreshToken`, and `user` data
  /// on success. Throws [ServerException] on authentication failure.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  });

  /// Logs out the currently authenticated user.
  ///
  /// Invalidates the server-side session. Throws [ServerException] on failure.
  Future<void> logout();

  /// Refreshes the access token using the given [refreshToken].
  ///
  /// Returns a map containing new `accessToken` and `refreshToken` values.
  /// Throws [ServerException] if the refresh token is invalid or expired.
  Future<Map<String, dynamic>> refreshToken(String refreshToken);
}

/// Remote data source implementation for authentication endpoints.
///
/// Communicates with `POST /auth/login`, `POST /auth/logout`, and
/// `POST /auth/refresh` endpoints using the base URL from [AppConstants].
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client _client;

  /// Creates an [AuthRemoteDataSourceImpl] with the given HTTP [client].
  AuthRemoteDataSourceImpl({required http.Client client}) : _client = client;

  @override
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/auth/login');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ServerException(
        message: 'Login failed: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<void> logout() async {
    final url = Uri.parse('${AppConstants.baseUrl}/auth/logout');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw ServerException(
        message: 'Logout failed: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final url = Uri.parse('${AppConstants.baseUrl}/auth/refresh');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ServerException(
        message: 'Token refresh failed: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}
