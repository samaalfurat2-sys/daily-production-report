import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'graph_client.dart';

class OneDriveDb {
  final GraphClient graph;
  static const _db = 'ProductionReports/db';
  OneDriveDb(this.graph);
  String _h(String s) => sha256.convert(utf8.encode(s)).toString();

  Future<void> initialize() async {
    await _ensure('$_db/users.json', _users());
    await _ensure('$_db/shifts.json', []);
    await _ensure('$_db/inventory.json', _inv());
    await _ensure('$_db/transfers.json', []);
    await _ensure('$_db/invoices.json', []);
    await _ensure('$_db/fuel_logs.json', []);
    await _ensure('$_db/config.json', {'shift_order': ['A','B','C'], 'app_version': '3.0.0'});
  }

  Future<void> _ensure(String p, dynamic d) async {
    try { await graph.readJsonFile(p); } catch (_) { await graph.writeJsonFile(p, d); }
  }

  List _users() => [
    // Legacy users
    {'id':1,'username':'admin','password_hash':_h('Admin1234'),'roles':['admin','general_manager'],'unit_permissions':{},'preferred_locale':'ar'},
    {'id':2,'username':'supervisor','password_hash':_h('Supervisor123'),'roles':['auditor_controller'],'unit_permissions':{},'preferred_locale':'ar'},
    {'id':3,'username':'operator','password_hash':_h('Operator123'),'roles':['production_supervisor'],'unit_permissions':{'blow':true,'filling':true,'label':true,'shrink':true,'diesel':true},'preferred_locale':'ar'},
    {'id':4,'username':'viewer','password_hash':_h('Viewer123'),'roles':['account_auditor'],'unit_permissions':{},'preferred_locale':'ar'},
    // New role-specific users
    {'id':5,'username':'raw_keeper','password_hash':_h('RawKeeper123'),'roles':['raw_warehouse_keeper'],'unit_permissions':{},'preferred_locale':'ar'},
    {'id':6,'username':'prod_supervisor','password_hash':_h('ProdSup123'),'roles':['production_supervisor'],'unit_permissions':{'blow':true,'filling':true,'label':true,'shrink':true},'preferred_locale':'ar'},
    {'id':7,'username':'fg_keeper','password_hash':_h('FgKeeper123'),'roles':['fg_warehouse_keeper'],'unit_permissions':{},'preferred_locale':'ar'},
    {'id':8,'username':'fuel_keeper','password_hash':_h('FuelKeeper123'),'roles':['fuel_warehouse_keeper'],'unit_permissions':{},'preferred_locale':'ar'},
    {'id':9,'username':'accountant','password_hash':_h('Accountant123'),'roles':['warehouse_accountant'],'unit_permissions':{},'preferred_locale':'ar'},
    {'id':10,'username':'controller','password_hash':_h('Controller123'),'roles':['auditor_controller'],'unit_permissions':{},'preferred_locale':'ar'},
    {'id':11,'username':'manager','password_hash':_h('Manager123'),'roles':['general_manager','admin'],'unit_permissions':{},'preferred_locale':'ar'},
    {'id':12,'username':'auditor','password_hash':_h('Auditor123'),'roles':['account_auditor'],'unit_permissions':{},'preferred_locale':'ar'},
  ];

  Map _inv() => {
    'warehouses': [
      {'code':'RAW','name_ar':'مخزن المواد الخام','name_en':'Raw Materials Warehouse'},
      {'code':'HALL','name_ar':'صالة الإنتاج','name_en':'Production Hall'},
      {'code':'FG','name_ar':'مخزن المنتج الجاهز','name_en':'Finished Goods Warehouse'},
      {'code':'FUEL','name_ar':'مخزن المحروقات','name_en':'Fuel Warehouse'},
    ],
    'items': [
      // Raw materials
      {'code':'PREFORM','name_en':'Preforms','name_ar':'بريفورم','warehouse_code':'RAW','stock':0.0,'uom':'pcs'},
      {'code':'CAP','name_en':'Caps','name_ar':'أغطية','warehouse_code':'RAW','stock':0.0,'uom':'pcs'},
      {'code':'LABEL','name_en':'Labels','name_ar':'لاصقات','warehouse_code':'RAW','stock':0.0,'uom':'roll'},
      {'code':'SHRINK','name_en':'Shrink Film','name_ar':'فيلم تقليص','warehouse_code':'RAW','stock':0.0,'uom':'kg'},
      // Finished goods
      {'code':'WATER_500','name_en':'Water 500ml','name_ar':'مياه 500مل','warehouse_code':'FG','stock':0.0,'uom':'carton'},
      {'code':'WATER_1500','name_en':'Water 1500ml','name_ar':'مياه 1500مل','warehouse_code':'FG','stock':0.0,'uom':'carton'},
      // Fuel
      {'code':'DIESEL','name_en':'Diesel','name_ar':'ديزل/سولار','warehouse_code':'FUEL','stock':0.0,'uom':'litre'},
    ],
    'transactions': [],
  };

  // ─── Auth ──────────────────────────────────────────────────────────────────
  Future<Map<String,dynamic>> login(String u, String p) async {
    final users = await graph.readJsonFile('$_db/users.json') as List;
    final h = _h(p);
    for (final x in users) { final m = x as Map<String,dynamic>; if (m['username']==u && m['password_hash']==h) return m; }
    throw Exception('Invalid credentials');
  }

  Future<Map<String,dynamic>> getMe(String u) async {
    final users = await graph.readJsonFile('$_db/users.json') as List;
    for (final x in users) { final m = x as Map<String,dynamic>; if (m['username']==u) return m; }
    throw Exception('User not found');
  }

  // ─── Shifts ────────────────────────────────────────────────────────────────
  Future<List> getShifts({String? status, int limit=100}) async {
    var s = await graph.readJsonFile('$_db/shifts.json') as List;
    if (status != null) s = s.where((x) => (x as Map)['status']==status).toList();
    s.sort((a,b) => ((b as Map)['report_date']??'').compareTo((a as Map)['report_date']??''));
    return s.take(limit).toList();
  }
  Future<List> listShifts({String? status, int limit=100}) => getShifts(status: status, limit: limit);

  Future<Map<String,dynamic>> getShift(String id) async {
    final s = await graph.readJsonFile('$_db/shifts.json') as List;
    for (final x in s) { if ((x as Map)['id']==id) return x as Map<String,dynamic>; }
    throw Exception('Shift not found');
  }

  Future<Map<String,dynamic>> createShift({required String reportDate, required String shiftCode, required String createdBy}) async {
    final s = await graph.readJsonFile('$_db/shifts.json') as List;
    final n = {
      'id':DateTime.now().millisecondsSinceEpoch.toString(),
      'report_date':reportDate,'shift_code':shiftCode,
      'status':'open','created_by':createdBy,
      'created_at':DateTime.now().toIso8601String(),
      'blow':null,'filling':null,'label':null,'shrink':null,'diesel':null
    };
    s.add(n); await graph.writeJsonFile('$_db/shifts.json', s); return n;
  }

  Future<Map<String,dynamic>> updateUnit(String id, String unit, Map<String,dynamic> p) async {
    final s = await graph.readJsonFile('$_db/shifts.json') as List;
    for (final x in s) { final m = x as Map<String,dynamic>; if (m['id']==id) { m[unit]=p; await graph.writeJsonFile('$_db/shifts.json',s); return m; } }
    throw Exception('Shift not found');
  }

  Future<Map<String,dynamic>> submitShift(String id) => _setStatus(id,'submitted');
  Future<Map<String,dynamic>> approveShift(String id) => _setStatus(id,'approved');
  Future<Map<String,dynamic>> lockShift(String id) => _setStatus(id,'locked');

  Future<Map<String,dynamic>> _setStatus(String id, String st) async {
    final s = await graph.readJsonFile('$_db/shifts.json') as List;
    for (final x in s) { final m = x as Map<String,dynamic>; if (m['id']==id) { m['status']=st; await graph.writeJsonFile('$_db/shifts.json',s); return m; } }
    throw Exception('Shift not found');
  }

  Future<List> getPendingApprovals() => getShifts(status:'submitted');

  // ─── Inventory ─────────────────────────────────────────────────────────────
  Future<List> listWarehouses() async {
    final inv = await graph.readJsonFile('$_db/inventory.json') as Map;
    return (inv['warehouses'] as List? ?? []);
  }

  Future<List> listItems({String? warehouseCode}) async {
    final inv = await graph.readJsonFile('$_db/inventory.json') as Map;
    var items = (inv['items'] as List? ?? []).cast<Map<String,dynamic>>();
    if (warehouseCode != null) items = items.where((i) => i['warehouse_code']==warehouseCode).toList();
    return items;
  }

  Future<List> listStock({String? warehouseCode}) async {
    final inv = await graph.readJsonFile('$_db/inventory.json') as Map<String,dynamic>;
    var items = (inv['items'] as List? ?? []).cast<Map<String,dynamic>>();
    if (warehouseCode != null) items = items.where((i) => i['warehouse_code']==warehouseCode).toList();
    return items.map((item) => <String,dynamic>{
      'warehouse_code': item['warehouse_code'] ?? '',
      'item_code': item['code'] ?? '',
      'item_name_en': item['name_en'] ?? '',
      'item_name_ar': item['name_ar'] ?? '',
      'qty_on_hand': (item['stock'] as num?)?.toDouble() ?? 0.0,
      'uom': item['uom'] ?? 'pcs',
    }).toList();
  }

  Future<List> listTransactions({String? warehouseCode, int limit=200}) async {
    final inv = await graph.readJsonFile('$_db/inventory.json') as Map<String,dynamic>;
    var txns = (inv['transactions'] as List? ?? []).cast<Map<String,dynamic>>();
    if (warehouseCode != null) txns = txns.where((t) => t['warehouse_code']==warehouseCode).toList();
    txns.sort((a,b) => ((b['created_at'] as String?) ?? '').compareTo((a['created_at'] as String?) ?? ''));
    return txns.take(limit).toList();
  }

  Future<Map<String,dynamic>> createTransaction({
    required String warehouseCode, required String itemCode,
    required String txnType, required double qty,
    required String txnDate, String? note, String? createdBy,
  }) async {
    final inv = await graph.readJsonFile('$_db/inventory.json') as Map<String,dynamic>;
    final txns = inv['transactions'] as List;
    final t = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'warehouse_code': warehouseCode, 'item_code': itemCode,
      'txn_type': txnType, 'qty': qty, 'txn_date': txnDate,
      'note': note, 'created_by': createdBy,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    };
    txns.add(t);
    // Update stock
    final isIn = (txnType == 'RECEIVE' || txnType == 'TRANSFER_IN');
    for (final x in inv['items'] as List) {
      final m = x as Map<String,dynamic>;
      if (m['code'] == itemCode && m['warehouse_code'] == warehouseCode) {
        final s = (m['stock'] as num?)?.toDouble() ?? 0.0;
        m['stock'] = isIn ? s + qty : (s - qty).clamp(0.0, double.infinity);
        break;
      }
    }
    await graph.writeJsonFile('$_db/inventory.json', inv);
    return t;
  }

  // ─── Transfers ─────────────────────────────────────────────────────────────
  Future<List> listTransfers({String? status, String? fromWarehouse, String? toWarehouse, int limit=200}) async {
    var list = await graph.readJsonFile('$_db/transfers.json') as List;
    var transfers = list.cast<Map<String,dynamic>>();
    if (status != null) transfers = transfers.where((t) => t['status']==status).toList();
    if (fromWarehouse != null) transfers = transfers.where((t) => t['from_warehouse']==fromWarehouse).toList();
    if (toWarehouse != null) transfers = transfers.where((t) => t['to_warehouse']==toWarehouse).toList();
    transfers.sort((a,b) => ((b['created_at'] as String?) ?? '').compareTo((a['created_at'] as String?) ?? ''));
    return transfers.take(limit).toList();
  }

  Future<Map<String,dynamic>> createTransfer({
    required String fromWarehouse, required String toWarehouse,
    required List<Map<String,dynamic>> items,
    required String transferDate, String? shiftCode,
    String? notes, required String createdBy,
  }) async {
    final list = await graph.readJsonFile('$_db/transfers.json') as List;
    final t = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'from_warehouse': fromWarehouse, 'to_warehouse': toWarehouse,
      'items': items, 'transfer_date': transferDate,
      'shift_code': shiftCode, 'notes': notes,
      'status': 'pending', 'created_by': createdBy,
      'created_at': DateTime.now().toIso8601String(),
      'confirmed_by': null, 'confirmed_at': null,
    };
    list.add(t);
    await graph.writeJsonFile('$_db/transfers.json', list);
    return t;
  }

  Future<Map<String,dynamic>> confirmTransfer(String id, String confirmedBy) async {
    final list = await graph.readJsonFile('$_db/transfers.json') as List;
    for (final x in list) {
      final m = x as Map<String,dynamic>;
      if (m['id'] == id) {
        m['status'] = 'confirmed';
        m['confirmed_by'] = confirmedBy;
        m['confirmed_at'] = DateTime.now().toIso8601String();
        await graph.writeJsonFile('$_db/transfers.json', list);
        return m;
      }
    }
    throw Exception('Transfer not found');
  }

  Future<Map<String,dynamic>> postTransfer(String id, String postedBy) async {
    final list = await graph.readJsonFile('$_db/transfers.json') as List;
    for (final x in list) {
      final m = x as Map<String,dynamic>;
      if (m['id'] == id) {
        if (m['status'] != 'confirmed') throw Exception('Transfer must be confirmed before posting');
        m['status'] = 'posted';
        m['posted_by'] = postedBy;
        m['posted_at'] = DateTime.now().toIso8601String();
        // Apply stock movements
        await _applyTransferStock(m);
        await graph.writeJsonFile('$_db/transfers.json', list);
        return m;
      }
    }
    throw Exception('Transfer not found');
  }

  Future<void> _applyTransferStock(Map<String,dynamic> transfer) async {
    final inv = await graph.readJsonFile('$_db/inventory.json') as Map<String,dynamic>;
    final items = (inv['items'] as List).cast<Map<String,dynamic>>();
    for (final ti in (transfer['items'] as List).cast<Map<String,dynamic>>()) {
      final code = ti['item_code'] as String;
      final qty = (ti['qty'] as num).toDouble();
      // Deduct from source
      for (final item in items) {
        if (item['code'] == code && item['warehouse_code'] == transfer['from_warehouse']) {
          item['stock'] = ((item['stock'] as num?)?.toDouble() ?? 0.0 - qty).clamp(0.0, double.infinity);
        }
        // Add to destination
        if (item['code'] == code && item['warehouse_code'] == transfer['to_warehouse']) {
          item['stock'] = ((item['stock'] as num?)?.toDouble() ?? 0.0) + qty;
        }
      }
    }
    await graph.writeJsonFile('$_db/inventory.json', inv);
  }

  // ─── Invoices (FG Issue) ───────────────────────────────────────────────────
  Future<List> listInvoices({String? status, int limit=200}) async {
    final list = await graph.readJsonFile('$_db/invoices.json') as List;
    var invoices = list.cast<Map<String,dynamic>>();
    if (status != null) invoices = invoices.where((i) => i['status']==status).toList();
    invoices.sort((a,b) => ((b['created_at'] as String?) ?? '').compareTo((a['created_at'] as String?) ?? ''));
    return invoices.take(limit).toList();
  }

  Future<Map<String,dynamic>> createInvoice({
    required String invoiceNo, required String customer,
    required List<Map<String,dynamic>> items,
    required String invoiceDate, String? notes,
    required String createdBy,
  }) async {
    final list = await graph.readJsonFile('$_db/invoices.json') as List;
    final inv = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'invoice_no': invoiceNo, 'customer': customer,
      'items': items, 'invoice_date': invoiceDate,
      'notes': notes, 'status': 'pending',
      'created_by': createdBy,
      'created_at': DateTime.now().toIso8601String(),
      'confirmed_by': null,
    };
    list.add(inv);
    await graph.writeJsonFile('$_db/invoices.json', list);
    return inv;
  }

  Future<Map<String,dynamic>> confirmInvoice(String id, String confirmedBy) async {
    final list = await graph.readJsonFile('$_db/invoices.json') as List;
    for (final x in list) {
      final m = x as Map<String,dynamic>;
      if (m['id'] == id) {
        m['status'] = 'confirmed';
        m['confirmed_by'] = confirmedBy;
        m['confirmed_at'] = DateTime.now().toIso8601String();
        await graph.writeJsonFile('$_db/invoices.json', list);
        return m;
      }
    }
    throw Exception('Invoice not found');
  }

  Future<Map<String,dynamic>> postInvoice(String id, String postedBy) async {
    final list = await graph.readJsonFile('$_db/invoices.json') as List;
    for (final x in list) {
      final m = x as Map<String,dynamic>;
      if (m['id'] == id) {
        if (m['status'] != 'confirmed') throw Exception('Invoice must be confirmed before posting');
        m['status'] = 'posted';
        m['posted_by'] = postedBy;
        m['posted_at'] = DateTime.now().toIso8601String();
        await graph.writeJsonFile('$_db/invoices.json', list);
        return m;
      }
    }
    throw Exception('Invoice not found');
  }

  // ─── Fuel Logs ─────────────────────────────────────────────────────────────
  Future<List> listFuelLogs({String? status, int limit=200}) async {
    final list = await graph.readJsonFile('$_db/fuel_logs.json') as List;
    var logs = list.cast<Map<String,dynamic>>();
    if (status != null) logs = logs.where((l) => l['status']==status).toList();
    logs.sort((a,b) => ((b['created_at'] as String?) ?? '').compareTo((a['created_at'] as String?) ?? ''));
    return logs.take(limit).toList();
  }

  Future<Map<String,dynamic>> createFuelLog({
    required String shiftDate, required String shiftCode,
    double receivedQty = 0.0,
    required double gen1Qty, required double gen2Qty,
    String? notes, required String createdBy,
  }) async {
    final list = await graph.readJsonFile('$_db/fuel_logs.json') as List;
    final log = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'shift_date': shiftDate, 'shift_code': shiftCode,
      'received_qty': receivedQty,
      'gen1_qty': gen1Qty, 'gen2_qty': gen2Qty,
      'total_issued': gen1Qty + gen2Qty,
      'notes': notes, 'status': 'pending',
      'created_by': createdBy,
      'created_at': DateTime.now().toIso8601String(),
      'confirmed_by': null, 'confirmed_at': null,
    };
    list.add(log);
    // Update diesel stock
    if (receivedQty > 0) {
      final inv = await graph.readJsonFile('$_db/inventory.json') as Map<String,dynamic>;
      for (final x in inv['items'] as List) {
        final m = x as Map<String,dynamic>;
        if (m['code'] == 'DIESEL') {
          final s = (m['stock'] as num?)?.toDouble() ?? 0.0;
          m['stock'] = s + receivedQty - (gen1Qty + gen2Qty);
          break;
        }
      }
      await graph.writeJsonFile('$_db/inventory.json', inv);
    }
    await graph.writeJsonFile('$_db/fuel_logs.json', list);
    return log;
  }

  Future<Map<String,dynamic>> confirmFuelLog(String id, String confirmedBy) async {
    final list = await graph.readJsonFile('$_db/fuel_logs.json') as List;
    for (final x in list) {
      final m = x as Map<String,dynamic>;
      if (m['id'] == id) {
        m['status'] = 'confirmed';
        m['confirmed_by'] = confirmedBy;
        m['confirmed_at'] = DateTime.now().toIso8601String();
        await graph.writeJsonFile('$_db/fuel_logs.json', list);
        return m;
      }
    }
    throw Exception('Fuel log not found');
  }

  Future<Map<String,dynamic>> postFuelLog(String id, String postedBy) async {
    final list = await graph.readJsonFile('$_db/fuel_logs.json') as List;
    for (final x in list) {
      final m = x as Map<String,dynamic>;
      if (m['id'] == id) {
        if (m['status'] != 'confirmed') throw Exception('Must be confirmed first');
        m['status'] = 'posted';
        m['posted_by'] = postedBy;
        m['posted_at'] = DateTime.now().toIso8601String();
        await graph.writeJsonFile('$_db/fuel_logs.json', list);
        return m;
      }
    }
    throw Exception('Fuel log not found');
  }

  Future<Map<String,dynamic>> postShift(String id, String postedBy) async {
    final s = await graph.readJsonFile('$_db/shifts.json') as List;
    for (final x in s) {
      final m = x as Map<String,dynamic>;
      if (m['id'] == id) {
        m['status'] = 'posted';
        m['posted_by'] = postedBy;
        m['posted_at'] = DateTime.now().toIso8601String();
        await graph.writeJsonFile('$_db/shifts.json', s);
        return m;
      }
    }
    throw Exception('Shift not found');
  }

  // ─── Stats ─────────────────────────────────────────────────────────────────
  Future<Map<String,dynamic>> getStats() async {
    final s = await graph.readJsonFile('$_db/shifts.json') as List;
    final transfers = await graph.readJsonFile('$_db/transfers.json') as List;
    final invoices = await graph.readJsonFile('$_db/invoices.json') as List;
    final fuelLogs = await graph.readJsonFile('$_db/fuel_logs.json') as List;
    return {
      'total_shifts': s.length,
      'open_shifts': s.where((x)=>(x as Map)['status']=='open').length,
      'submitted_shifts': s.where((x)=>(x as Map)['status']=='submitted').length,
      'approved_shifts': s.where((x)=>(x as Map)['status']=='approved').length,
      'pending_transfers': transfers.where((x)=>(x as Map)['status']=='pending').length,
      'pending_invoices': invoices.where((x)=>(x as Map)['status']=='pending').length,
      'pending_fuel_logs': fuelLogs.where((x)=>(x as Map)['status']=='pending').length,
    };
  }

  // ─── All pending for controller ────────────────────────────────────────────
  Future<Map<String,dynamic>> getAllPending() async {
    final shifts = await getShifts(status: 'submitted');
    final confirmedShifts = await getShifts(status: 'approved');
    final transfers = await listTransfers(status: 'confirmed');
    final invoices = await listInvoices(status: 'confirmed');
    final fuelLogs = await listFuelLogs(status: 'confirmed');
    return {
      'shifts_to_approve': shifts,
      'shifts_to_post': confirmedShifts,
      'transfers_to_post': transfers,
      'invoices_to_post': invoices,
      'fuel_logs_to_post': fuelLogs,
    };
  }
}
