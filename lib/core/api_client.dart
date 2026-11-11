import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'ticket.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  bool get isAuth => statusCode == 401 || statusCode == 403;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}

class SyncResult {
  const SyncResult({required this.saleId, required this.total, required this.created});
  final int saleId;
  final String total;
  final bool created;
}

class ShiftSummary {
  const ShiftSummary({
    required this.operationalDate,
    required this.sales,
    required this.expenses,
    required this.advances,
    required this.suppliers,
    required this.closed,
    this.previousCashInId,
    this.cashInId,
  });

  final String operationalDate;
  final String sales;
  final String expenses;
  final String advances;
  final String suppliers;
  final bool closed;
  final int? previousCashInId;
  final int? cashInId;

  factory ShiftSummary.fromJson(Map<String, dynamic> json) => ShiftSummary(
        operationalDate: json['operational_date'] as String? ?? '',
        sales: json['sales']?.toString() ?? '0',
        expenses: json['expenses']?.toString() ?? '0',
        advances: json['advances']?.toString() ?? '0',
        suppliers: json['suppliers']?.toString() ?? '0',
        closed: json['closed'] == true,
        previousCashInId: json['previous_cash_in_id'] == null ? null : (json['previous_cash_in_id'] as num).toInt(),
        cashInId: json['cash_in_id'] == null ? null : (json['cash_in_id'] as num).toInt(),
      );
}

class ShiftExpense {
  const ShiftExpense({required this.id, required this.account, required this.amount, required this.reason});
  final int id;
  final String account;
  final String amount;
  final String reason;

  factory ShiftExpense.fromJson(Map<String, dynamic> json) => ShiftExpense(
        id: (json['id'] as num).toInt(),
        account: json['account'] as String? ?? '',
        amount: json['amount'].toString(),
        reason: json['reason'] as String? ?? '',
      );
}

class ApiClient {
  ApiClient({required String baseUrl, this.token, http.Client? httpClient})
      : baseUrl = normalizeBaseUrl(baseUrl),
        _http = httpClient ?? http.Client();

  static String normalizeBaseUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) return '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'https://$url';
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  String baseUrl;
  String? token;
  final http.Client _http;
  static const Duration requestTimeout = Duration(seconds: 25);

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null || query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  /// Menu images arrive as site-relative paths (``/media/...``).
  String resolveUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl${path.startsWith('/') ? '' : '/'}$path';
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Token $token',
      };

  Never _fail(http.Response response) {
    var message = 'تعذر الاتصال بالخادم (${response.statusCode}).';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] != null) message = body['error'].toString();
    } catch (_) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        message = 'انتهت الجلسة. سجّل الدخول مرة أخرى.';
      }
    }
    throw ApiException(response.statusCode, message);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode >= 400) _fail(response);
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) throw ApiException(response.statusCode, 'استجابة غير متوقعة من الخادم.');
    return body;
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final response = await _http.get(_uri(path, query), headers: _headers).timeout(requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload) async {
    final response = await _http
        .post(_uri(path), headers: {..._headers, 'Content-Type': 'application/json'}, body: jsonEncode(payload))
        .timeout(requestTimeout);
    return _decode(response);
  }

  Future<({String token, PosUser user})> login({
    required String username,
    required String password,
    required String deviceName,
  }) async {
    final body = await _post('/pos-api/v1/auth/login/', {
      'username': username,
      'password': password,
      'device_name': deviceName,
    });
    return (token: body['token'] as String, user: PosUser.fromJson(body['user'] as Map<String, dynamic>));
  }

  Future<void> logout() async {
    try {
      await _post('/pos-api/v1/auth/logout/', {});
    } on ApiException {
      // A revoked or expired token is already logged out as far as the server cares.
    }
  }

  Future<Map<String, dynamic>> bootstrapRaw() => _get('/pos-api/v1/bootstrap/');

  Future<Bootstrap> bootstrap() async => Bootstrap.fromJson(await bootstrapRaw());

  Future<Map<String, dynamic>> catalogRaw(int branchId) => _get('/pos-api/v1/catalog/$branchId/');

  Future<List<PosProduct>> catalog(int branchId) async => parseCatalog(await catalogRaw(branchId));

  static List<PosProduct> parseCatalog(Map<String, dynamic> body) => (body['products'] as List<dynamic>? ?? [])
      .map((item) => PosProduct.fromJson(item as Map<String, dynamic>))
      .where((product) => product.isMenuSection)
      .toList();

  Future<SyncResult> syncTicket(Ticket ticket) async {
    final response = await _http
        .post(_uri('/pos-api/v1/sync/'),
            headers: {..._headers, 'Content-Type': 'application/json'}, body: jsonEncode(ticket.toSyncPayload()))
        .timeout(requestTimeout);
    final body = _decode(response);
    return SyncResult(
      saleId: (body['id'] as num).toInt(),
      total: body['total'].toString(),
      created: response.statusCode == 201,
    );
  }

  Future<ShiftSummary> shiftSummary(int branchId) async =>
      ShiftSummary.fromJson(await _get('/pos-api/v1/shift/summary/', {'branch': '$branchId'}));

  Future<({List<ShiftExpense> expenses, String total})> shiftExpenses(int branchId) async {
    final body = await _get('/pos-api/v1/shift/expenses/', {'branch': '$branchId'});
    return (
      expenses: (body['expenses'] as List<dynamic>? ?? [])
          .map((item) => ShiftExpense.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: body['total']?.toString() ?? '0',
    );
  }

  Future<void> addExpense({required int branchId, required int accountId, required String amount, required String reason}) =>
      _post('/pos-api/v1/shift/expense/', {'branch': branchId, 'account': accountId, 'amount': amount, 'reason': reason});

  Future<void> addAdvance({required int branchId, required int employeeId, required String amount, required String notes}) =>
      _post('/pos-api/v1/shift/advance/', {'branch': branchId, 'employee': employeeId, 'amount': amount, 'notes': notes});

  Future<void> addSupplierPayment({required int branchId, required int supplierId, required String amount, required String notes}) =>
      _post('/pos-api/v1/shift/supplier-payment/', {'branch': branchId, 'supplier': supplierId, 'amount': amount, 'notes': notes});

  Future<int> closeShift({required int branchId, required String shift}) async {
    final body = await _post('/pos-api/v1/shift/close/', {'branch': branchId, 'shift': shift});
    return (body['cash_in_id'] as num).toInt();
  }

  Future<Map<String, dynamic>?> appLatest() async {
    try {
      return await _get('/pos-api/v1/app/latest/');
    } on ApiException {
      return null;
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    }
  }

  void close() => _http.close();
}