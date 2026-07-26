import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/loyalty_entity.dart';
import '../../domain/entities/loyalty_balance.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';

/// Abstract contract for remote loyalty operations.
///
/// Defines the interface for communicating with the loyalty API endpoints.
/// Implementations handle HTTP requests, JSON serialization, and error mapping.
abstract class LoyaltyRemoteDataSource {
  /// Fetches the current loyalty point balance for [customerId].
  Future<LoyaltyBalance> getLoyaltyBalance(String customerId);

  /// Earns loyalty points for [customerId].
  ///
  /// [points] is the number of points to add.
  /// [referenceType] and [referenceId] link the earn to a bill or transaction.
  Future<LoyaltyTransaction> earnPoints({
    required String customerId,
    required int points,
    String? referenceType,
    String? referenceId,
  });

  /// Redeems loyalty points for [customerId].
  ///
  /// [points] is the number of points to deduct.
  /// [referenceType] and [referenceId] link the redemption to a bill.
  Future<LoyaltyTransaction> redeemPoints({
    required String customerId,
    required int points,
    String? referenceType,
    String? referenceId,
  });

  /// Fetches the transaction history for [customerId] with pagination.
  Future<List<LoyaltyTransaction>> getLoyaltyHistory({
    required String customerId,
    int page = 1,
    int perPage = 20,
  });
}

/// Remote data source implementation for loyalty endpoints.
///
/// Communicates with `/loyalty` REST endpoints using the base URL
/// from [AppConstants].
class LoyaltyRemoteDataSourceImpl implements LoyaltyRemoteDataSource {
  final http.Client _client;

  /// Creates a [LoyaltyRemoteDataSourceImpl] with the given HTTP [client].
  LoyaltyRemoteDataSourceImpl({required http.Client client}) : _client = client;

  LoyaltyTransaction _parseTransaction(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      customerName: json['customerName'] as String,
      transactionType: json['transactionType'] as String,
      points: json['points'] as int,
      referenceType: json['referenceType'] as String?,
      referenceId: json['referenceId'] as String?,
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  LoyaltyBalance _parseBalance(Map<String, dynamic> json) {
    final recentTxn = (json['recentTransactions'] as List?)
            ?.map((e) => _parseTransaction(e as Map<String, dynamic>))
            .toList() ??
        [];
    return LoyaltyBalance(
      customerId: json['customerId'] as String,
      customerName: json['customerName'] as String,
      totalPointsEarned: json['totalPointsEarned'] as int,
      totalPointsRedeemed: json['totalPointsRedeemed'] as int,
      currentBalance: json['currentBalance'] as int,
      pendingPoints: json['pendingPoints'] as int? ?? 0,
      expiringPoints: json['expiringPoints'] as int? ?? 0,
      nextExpiryDate: json['nextExpiryDate'] != null
          ? DateTime.parse(json['nextExpiryDate'] as String)
          : null,
      recentTransactions: recentTxn,
    );
  }

  @override
  Future<LoyaltyBalance> getLoyaltyBalance(String customerId) async {
    final url = Uri.parse('${AppConstants.baseUrl}/loyalty/$customerId/balance');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return _parseBalance(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to fetch loyalty balance: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<LoyaltyTransaction> earnPoints({
    required String customerId,
    required int points,
    String? referenceType,
    String? referenceId,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/loyalty/earn');
    final body = <String, dynamic>{
      'customerId': customerId,
      'points': points,
    };
    if (referenceType != null) body['referenceType'] = referenceType;
    if (referenceId != null) body['referenceId'] = referenceId;

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _parseTransaction(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to earn points: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<LoyaltyTransaction> redeemPoints({
    required String customerId,
    required int points,
    String? referenceType,
    String? referenceId,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/loyalty/redeem');
    final body = <String, dynamic>{
      'customerId': customerId,
      'points': points,
    };
    if (referenceType != null) body['referenceType'] = referenceType;
    if (referenceId != null) body['referenceId'] = referenceId;

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return _parseTransaction(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to redeem points: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<List<LoyaltyTransaction>> getLoyaltyHistory({
    required String customerId,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    final url = Uri.parse('${AppConstants.baseUrl}/loyalty/$customerId/history')
        .replace(queryParameters: queryParams);
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data is Map<String, dynamic> && data.containsKey('data')
          ? data['data'] as List
          : data as List;
      return items
          .map((e) => _parseTransaction(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ServerException(
        message: 'Failed to fetch loyalty history: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}
