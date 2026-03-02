import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl, required this.token});

  final String baseUrl;
  final String? token;

  Uri _u(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse(baseUrl);
    return uri.replace(
      path: '${uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path}$path',
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (auth && token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<String> login({required String username, required String password}) async {
    final res = await http.post(
      _u('/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json'},
      body: {'username': username, 'password': password},
    );
    if (res.statusCode != 200) {
      throw Exception('Login failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['access_token'] as String;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(_u('/me'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to load user');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listShifts({String? status, int limit = 100}) async {
    final query = <String, dynamic>{'limit': limit};
    if (status != null) query['status'] = status;
    final res = await http.get(_u('/shifts', query), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to load shifts');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createShift({required String reportDate, required String shiftCode}) async {
    final res = await http.post(
      _u('/shifts'),
      headers: {..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({'report_date': reportDate, 'shift_code': shiftCode}),
    );
    if (res.statusCode != 200) throw Exception('Failed to create shift');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getShift(String id) async {
    final res = await http.get(_u('/shifts/$id'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to load shift');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateUnit(String shiftId, String unitPath, Map<String, dynamic> payload) async {
    final res = await http.put(
      _u('/shifts/$shiftId/$unitPath'),
      headers: {..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200) throw Exception('Failed to update $unitPath: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitShift(String shiftId) async {
    final res = await http.post(_u('/shifts/$shiftId/submit'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to submit shift');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approveShift(String shiftId) async {
    final res = await http.post(_u('/shifts/$shiftId/approve'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to approve shift');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> lockShift(String shiftId) async {
    final res = await http.post(_u('/shifts/$shiftId/lock'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to lock shift');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listWarehouses() async {
    final res = await http.get(_u('/warehouses'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to load warehouses');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> listStock() async {
    final res = await http.get(_u('/inventory/stock'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to load stock');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> listTransactions({String? warehouseCode, String? itemCode}) async {
    final query = <String, dynamic>{};
    if (warehouseCode != null && warehouseCode.isNotEmpty) query['warehouse_code'] = warehouseCode;
    if (itemCode != null && itemCode.isNotEmpty) query['item_code'] = itemCode;
    final res = await http.get(_u('/inventory/transactions', query), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to load transactions');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> listItems() async {
    final res = await http.get(_u('/inventory/items'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to load items');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createInventoryTransaction({
    required String warehouseCode,
    required String itemCode,
    required String txnType,
    required String txnDate,
    required double qty,
    String? note,
  }) async {
    final res = await http.post(
      _u('/inventory/transactions'),
      headers: {..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'warehouse_code': warehouseCode,
        'item_code': itemCode,
        'txn_type': txnType,
        'qty': qty,
        'txn_date': txnDate,
        'note': note,
      }),
    );
    if (res.statusCode != 200) throw Exception('Failed to create inventory transaction: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
