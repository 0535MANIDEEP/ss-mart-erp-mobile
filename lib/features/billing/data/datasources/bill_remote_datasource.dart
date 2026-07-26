import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/bill_entity.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';

/// Abstract contract for remote billing operations.
///
/// Defines the interface for communicating with the bills API endpoints.
/// Implementations handle HTTP requests, JSON serialization, and error mapping.
abstract class BillRemoteDataSource {
  /// Creates a new sales bill.
  Future<Bill> createBill(Bill bill);

  /// Fetches a single bill by its unique [id].
  Future<Bill> getBillById(String id);

  /// Fetches a paginated list of bills with optional filters.
  ///
  /// [customerId], [startDate], [endDate], and [status] are optional filters.
  /// [page] and [perPage] control pagination.
  Future<List<Bill>> getBills({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int page = 1,
    int perPage = 20,
  });

  /// Fetches the total sales amount for the given [date].
  ///
  /// Returns the total in paise.
  Future<int> getDaySalesTotal(DateTime date);

  /// Fetches the most recent bills, limited to [limit] items.
  Future<List<Bill>> getRecentBills({int limit = 10});

  /// Processes a return against an existing bill.
  ///
  /// [originalBillId] is the bill being returned.
  /// [returnItems] are the specific line items being returned.
  /// [reason] is the reason for the return.
  Future<Bill> processReturn({
    required String originalBillId,
    required List<BillItem> returnItems,
    required String reason,
  });

  /// Updates the status of a bill identified by [billId].
  Future<void> updateBillStatus(String billId, String status);
}

/// Remote data source implementation for billing endpoints.
///
/// Communicates with `/bills` REST endpoints using the base URL
/// from [AppConstants].
class BillRemoteDataSourceImpl implements BillRemoteDataSource {
  final http.Client _client;

  /// Creates a [BillRemoteDataSourceImpl] with the given HTTP [client].
  BillRemoteDataSourceImpl({required http.Client client}) : _client = client;

  BillItem _parseBillItem(Map<String, dynamic> json) {
    return BillItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: json['unitPrice'] as int,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      discountAmount: json['discountAmount'] as int? ?? 0,
      taxAmount: json['taxAmount'] as int? ?? 0,
      totalAmount: json['totalAmount'] as int,
      batchNumber: json['batchNumber'] as String?,
    );
  }

  Bill _parseBill(Map<String, dynamic> json) {
    final items = (json['items'] as List?)
            ?.map((e) => _parseBillItem(e as Map<String, dynamic>))
            .toList() ??
        [];
    return Bill(
      id: json['id'] as String,
      billNumber: json['billNumber'] as String,
      invoiceNumber: json['invoiceNumber'] as String?,
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String?,
      billDate: DateTime.parse(json['billDate'] as String),
      subtotal: json['subtotal'] as int,
      taxAmount: json['taxAmount'] as int? ?? 0,
      discountAmount: json['discountAmount'] as int? ?? 0,
      roundOff: json['roundOff'] as int? ?? 0,
      totalAmount: json['totalAmount'] as int,
      paidAmount: json['paidAmount'] as int? ?? 0,
      dueAmount: json['dueAmount'] as int? ?? 0,
      paymentMode: json['paymentMode'] as String? ?? 'CASH',
      status: json['status'] as String? ?? 'completed',
      isReturn: json['isReturn'] as bool? ?? false,
      referenceBillId: json['referenceBillId'] as String?,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int? ?? 1,
      items: items,
    );
  }

  Map<String, dynamic> _billToJson(Bill b) {
    return {
      'id': b.id,
      'billNumber': b.billNumber,
      'invoiceNumber': b.invoiceNumber,
      'customerId': b.customerId,
      'customerName': b.customerName,
      'billDate': b.billDate.toIso8601String(),
      'subtotal': b.subtotal,
      'taxAmount': b.taxAmount,
      'discountAmount': b.discountAmount,
      'roundOff': b.roundOff,
      'totalAmount': b.totalAmount,
      'paidAmount': b.paidAmount,
      'dueAmount': b.dueAmount,
      'paymentMode': b.paymentMode,
      'status': b.status,
      'isReturn': b.isReturn,
      'referenceBillId': b.referenceBillId,
      'createdBy': b.createdBy,
      'createdAt': b.createdAt.toIso8601String(),
      'updatedAt': b.updatedAt.toIso8601String(),
      'version': b.version,
      'items': b.items
          .map((item) => {
                'id': item.id,
                'productId': item.productId,
                'productName': item.productName,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'taxRate': item.taxRate,
                'discountPercent': item.discountPercent,
                'discountAmount': item.discountAmount,
                'taxAmount': item.taxAmount,
                'totalAmount': item.totalAmount,
                'batchNumber': item.batchNumber,
              })
          .toList(),
    };
  }

  @override
  Future<Bill> createBill(Bill bill) async {
    final url = Uri.parse('${AppConstants.baseUrl}/bills');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(_billToJson(bill)),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _parseBill(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to create bill: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Bill> getBillById(String id) async {
    final url = Uri.parse('${AppConstants.baseUrl}/bills/$id');
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      return _parseBill(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to fetch bill: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<List<Bill>> getBills({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (customerId != null && customerId.isNotEmpty) {
      queryParams['customer_id'] = customerId;
    }
    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final url = Uri.parse('${AppConstants.baseUrl}/bills')
        .replace(queryParameters: queryParams);
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data is Map<String, dynamic> && data.containsKey('data')
          ? data['data'] as List
          : data as List;
      return items
          .map((e) => _parseBill(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ServerException(
        message: 'Failed to fetch bills: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<int> getDaySalesTotal(DateTime date) async {
    final queryParams = <String, String>{
      'date': date.toIso8601String(),
    };
    final url = Uri.parse('${AppConstants.baseUrl}/bills/sales-total')
        .replace(queryParameters: queryParams);
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['total'] as int? ?? 0;
    } else {
      throw ServerException(
        message: 'Failed to fetch day sales total: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<List<Bill>> getRecentBills({int limit = 10}) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
    final url = Uri.parse('${AppConstants.baseUrl}/bills/recent')
        .replace(queryParameters: queryParams);
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data is Map<String, dynamic> && data.containsKey('data')
          ? data['data'] as List
          : data as List;
      return items
          .map((e) => _parseBill(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ServerException(
        message: 'Failed to fetch recent bills: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<Bill> processReturn({
    required String originalBillId,
    required List<BillItem> returnItems,
    required String reason,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/bills/return');
    final body = {
      'originalBillId': originalBillId,
      'reason': reason,
      'returnItems': returnItems
          .map((item) => {
                'id': item.id,
                'productId': item.productId,
                'productName': item.productName,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'taxRate': item.taxRate,
                'discountPercent': item.discountPercent,
                'discountAmount': item.discountAmount,
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
      return _parseBill(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ServerException(
        message: 'Failed to process return: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<void> updateBillStatus(String billId, String status) async {
    final url = Uri.parse('${AppConstants.baseUrl}/bills/$billId/status');
    final response = await _client.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw ServerException(
        message: 'Failed to update bill status: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}
