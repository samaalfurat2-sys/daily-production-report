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

  // ── Auth ──────────────────────────────────────────────────────────────────

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

  // ── Shifts ────────────────────────────────────────────────────────────────

  Future<List<dynamic>> listShifts({
    String? status,
    int limit = 100,
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (status   != null) query['status']    = status;
    if (dateFrom != null) query['date_from'] = dateFrom;
    if (dateTo   != null) query['date_to']   = dateTo;
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

  // ── Warehouses / Items ────────────────────────────────────────────────────

  Future<List<dynamic>> listWarehouses() async {
    final res = await http.get(_u('/warehouses'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to load warehouses');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> listItems() async {
    final res = await http.get(_u('/inventory/items'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to load items');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> listStock({String? warehouseCode}) async {
    final query = <String, dynamic>{};
    if (warehouseCode != null && warehouseCode.isNotEmpty) query['warehouse_code'] = warehouseCode;
    final res = await http.get(_u('/inventory/stock', query), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to load stock');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> listTransactions({
    String? warehouseCode,
    String? itemCode,
    String? status,
    String? txnType,
    String? dateFrom,
    String? dateTo,
    int limit = 200,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (warehouseCode != null && warehouseCode.isNotEmpty) query['warehouse_code'] = warehouseCode;
    if (itemCode != null && itemCode.isNotEmpty) query['item_code'] = itemCode;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (txnType != null && txnType.isNotEmpty) query['txn_type'] = txnType;
    if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;
    final res = await http.get(_u('/inventory/transactions', query), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed to load transactions');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> listPendingTransactions({String targetStatus = 'PENDING'}) async {
    final res = await http.get(
      _u('/inventory/pending', {'target_status': targetStatus}),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw Exception('Failed to load pending transactions');
    return jsonDecode(res.body) as List<dynamic>;
  }

  // ── Create simple transaction (RECEIVE / ISSUE / ADJUST) ─────────────────

  Future<Map<String, dynamic>> createTransaction({
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
    if (res.statusCode != 200) throw Exception('Failed to create transaction: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Legacy alias used by existing warehouse_screen.dart
  Future<Map<String, dynamic>> createInventoryTransaction({
    required String warehouseCode,
    required String itemCode,
    required String txnType,
    required String txnDate,
    required double qty,
    String? note,
  }) => createTransaction(
        warehouseCode: warehouseCode,
        itemCode: itemCode,
        txnType: txnType,
        txnDate: txnDate,
        qty: qty,
        note: note,
      );

  // ── Create transfer pair (TRANSFER_OUT + TRANSFER_IN) ────────────────────

  Future<List<dynamic>> createTransfer({
    required String sourceWarehouseCode,
    required String targetWarehouseCode,
    required String itemCode,
    required String txnDate,
    required double qty,
    String? note,
  }) async {
    final res = await http.post(
      _u('/inventory/transfers'),
      headers: {..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'source_warehouse_code': sourceWarehouseCode,
        'target_warehouse_code': targetWarehouseCode,
        'item_code': itemCode,
        'qty': qty,
        'txn_date': txnDate,
        'note': note,
      }),
    );
    if (res.statusCode != 200) throw Exception('Failed to create transfer: ${res.body}');
    return jsonDecode(res.body) as List<dynamic>;
  }

  // ── Acknowledge / Post ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> acknowledgeTransaction(String txnId) async {
    final res = await http.post(
      _u('/inventory/transactions/$txnId/acknowledge'),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw Exception('Failed to acknowledge: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postTransaction(String txnId) async {
    final res = await http.post(
      _u('/inventory/transactions/$txnId/post'),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw Exception('Failed to post: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Sync endpoints ────────────────────────────────────────────────────────

  /// GET /sync/delta?since=<iso_timestamp>
  /// Returns {shifts, inventory_transactions, server_time}.
  Future<Map<String, dynamic>> getSyncDelta({String? since}) async {
    final query = <String, dynamic>{};
    if (since != null && since.isNotEmpty) query['since'] = since;
    final res = await http.get(_u('/sync/delta', query), headers: _headers());
    if (res.statusCode != 200) throw Exception('Sync delta failed: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// POST /sync/batch
  /// Idempotent batch create of inventory transactions.
  /// Returns list of {client_id, status, id?}.
  Future<List<dynamic>> postSyncBatch(List<Map<String, dynamic>> items) async {
    final res = await http.post(
      _u('/sync/batch'),
      headers: {..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode(items),
    );
    if (res.statusCode != 200) throw Exception('Sync batch failed: ${res.statusCode}');
    return jsonDecode(res.body) as List<dynamic>;
  }

  /// GET /sync/status  (admin only)
  Future<Map<String, dynamic>> getSyncStatus() async {
    final res = await http.get(_u('/sync/status'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Sync status failed: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

}
