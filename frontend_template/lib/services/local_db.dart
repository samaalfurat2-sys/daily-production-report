import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Local JSON-file database (offline-first).
/// Mirrors the public API of OneDriveDb so AppState can swap transparently.
class LocalDb {
  static const _dir = 'ProductionReports/db';
  LocalDb();
  String _h(String s) => sha256.convert(utf8.encode(s)).toString();

  Future<Directory> _dbDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_dir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String name) async {
    final dir = await _dbDir();
    return File('${dir.path}/$name');
  }

  Future<dynamic> _read(String name) async {
    final f = await _file(name);
    if (!await f.exists()) return null;
    return json.decode(await f.readAsString());
  }

  Future<void> _write(String name, dynamic data) async {
    final f = await _file(name);
    await f.writeAsString(json.encode(data));
  }

  Future<void> _ensure(String name, dynamic defaultValue) async {
    final f = await _file(name);
    if (!await f.exists()) await _write(name, defaultValue);
  }

  // ─── Initialize ────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    await _ensure('users.json', _users());
    await _ensure('shifts.json', []);
    await _ensure('inventory.json', _inv());
    await _ensure('transfers.json', []);
    await _ensure('invoices.json', []);
    await _ensure('fuel_logs.json', []);
    await _ensure('config.json', {'shift_order': ['A','B','C'], 'app_version': '3.0.0'});
  }

  List _users() => [
    {'id':1,'username':'admin','password_hash':_h('Admin1234'),'roles':['admin','general_manager'],'unit_permissions':{},'preferred_locale':'ar'},
    {'id':2,'username':'supervisor','password_hash':_h('Supervisor123'),'roles':['auditor_controller'],'unit_permissions':{},'preferred_locale':'ar'},
    {'id':3,'username':'operator','password_hash':_h('Operator123'),'roles':['production_supervisor'],'unit_permissions':{'blow':true,'filling':true,'label':true,'shrink':true,'diesel':true},'preferred_locale':'ar'},
    {'id':4,'username':'viewer','password_hash':_h('Viewer123'),'roles':['account_auditor'],'unit_permissions':{},'preferred_locale':'ar'},
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
      {'code':'PREFORM','name_en':'Preforms','name_ar':'بريفورم','warehouse_code':'RAW','stock':0.0,'uom':'pcs'},
      {'code':'CAP','name_en':'Caps','name_ar':'أغطية','warehouse_code':'RAW','stock':0.0,'uom':'pcs'},
      {'code':'LABEL','name_en':'Labels','name_ar':'لاصقات','warehouse_code':'RAW','stock':0.0,'uom':'roll'},
      {'code':'SHRINK','name_en':'Shrink Film','name_ar':'فيلم تقليص','warehouse_code':'RAW','stock':0.0,'uom':'kg'},
      {'code':'WATER_500','name_en':'Water 500ml','name_ar':'مياه 500مل','warehouse_code':'FG','stock':0.0,'uom':'carton'},
      {'code':'WATER_1500','name_en':'Water 1500ml','name_ar':'مياه 1500مل','warehouse_code':'FG','stock':0.0,'uom':'carton'},
      {'code':'DIESEL','name_en':'Diesel','name_ar':'ديزل/سولار','warehouse_code':'FUEL','stock':0.0,'uom':'litre'},
    ],
    'transactions': [],
  };

  // ─── Auth ──────────────────────────────────────────────────────────────────
  Future<Map<String,dynamic>> login(String u, String p) async {
    final users = (await _read('users.json') as List?) ?? _users();
    final h = _h(p);
    for (final x in users) { final m = x as Map<String,dynamic>; if (m['username']==u && m['password_hash']==h) return m; }
    throw Exception('Invalid credentials');
  }

  Future<Map<String,dynamic>> getMe(String u) async {
    final users = (await _read('users.json') as List?) ?? _users();
    for (final x in users) { final m = x as Map<String,dynamic>; if (m['username']==u) return m; }
    throw Exception('User not found');
  }

  // ─── Shifts ────────────────────────────────────────────────────────────────
  Future<List> getShifts({String? status, int limit=100}) async {
    var s = ((await _read('shifts.json')) as List?) ?? [];
    if (status != null) s = s.where((x) => (x as Map)['status']==status).toList();
    s.sort((a,b) => ((b as Map)['report_date']??'').compareTo((a as Map)['report_date']??''));
    return s.take(limit).toList();
  }
  Future<List> listShifts({String? status, int limit=100}) => getShifts(status: status, limit: limit);

  Future<Map<String,dynamic>> getShift(String id) async {
    final s = ((await _read('shifts.json')) as List?) ?? [];
    for (final x in s) { if ((x as Map)['id']==id) return x as Map<String,dynamic>; }
    throw Exception('Shift not found');
  }

  Future<Map<String,dynamic>> createShift({required String reportDate, required String shiftCode, required String createdBy}) async {
    final s = ((await _read('shifts.json')) as List?) ?? [];
    final n = {'id':DateTime.now().millisecondsSinceEpoch.toString(),'report_date':reportDate,'shift_code':shiftCode,'status':'open','created_by':createdBy,'created_at':DateTime.now().toIso8601String(),'blow':null,'filling':null,'label':null,'shrink':null,'diesel':null};
    s.add(n); await _write('shifts.json', s); return n;
  }

  Future<Map<String,dynamic>> updateUnit(String id, String unit, Map<String,dynamic> p) async {
    final s = ((await _read('shifts.json')) as List?) ?? [];
    for (final x in s) { final m = x as Map<String,dynamic>; if (m['id']==id) { m[unit]=p; await _write('shifts.json',s); return m; } }
    throw Exception('Shift not found');
  }

  Future<Map<String,dynamic>> submitShift(String id) => _setStatus(id,'submitted');
  Future<Map<String,dynamic>> approveShift(String id) => _setStatus(id,'approved');
  Future<Map<String,dynamic>> lockShift(String id) => _setStatus(id,'locked');

  Future<Map<String,dynamic>> _setStatus(String id, String st) async {
    final s = ((await _read('shifts.json')) as List?) ?? [];
    for (final x in s) { final m = x as Map<String,dynamic>; if (m['id']==id) { m['status']=st; await _write('shifts.json',s); return m; } }
    throw Exception('Shift not found');
  }

  Future<Map<String,dynamic>> postShift(String id, String postedBy) async {
    final s = ((await _read('shifts.json')) as List?) ?? [];
    for (final x in s) { final m = x as Map<String,dynamic>; if (m['id']==id) { m['status']='posted'; m['posted_by']=postedBy; m['posted_at']=DateTime.now().toIso8601String(); await _write('shifts.json',s); return m; } }
    throw Exception('Shift not found');
  }

  Future<List> getPendingApprovals() => getShifts(status:'submitted');

  // ─── Inventory ─────────────────────────────────────────────────────────────
  Future<List> listWarehouses() async {
    final inv = (await _read('inventory.json') as Map?) ?? _inv();
    return (inv['warehouses'] as List? ?? []);
  }

  Future<List> listItems({String? warehouseCode}) async {
    final inv = (await _read('inventory.json') as Map?) ?? _inv();
    var items = (inv['items'] as List? ?? []).cast<Map<String,dynamic>>();
    if (warehouseCode != null) items = items.where((i) => i['warehouse_code']==warehouseCode).toList();
    return items;
  }

  Future<List> listStock({String? warehouseCode}) async {
    final inv = (await _read('inventory.json') as Map?) ?? _inv();
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
    final inv = (await _read('inventory.json') as Map?) ?? _inv();
    var txns = (inv['transactions'] as List? ?? []).cast<Map<String,dynamic>>();
    if (warehouseCode != null) txns = txns.where((t) => t['warehouse_code']==warehouseCode).toList();
    txns.sort((a,b) => ((b['created_at'] as String?) ?? '').compareTo((a['created_at'] as String?) ?? ''));
    return txns.take(limit).toList();
  }

  Future<Map<String,dynamic>> createTransaction({required String warehouseCode, required String itemCode, required String txnType, required double qty, required String txnDate, String? note, String? createdBy}) async {
    final inv = (await _read('inventory.json') as Map<String,dynamic>?) ?? Map<String,dynamic>.from(_inv());
    final txns = inv['transactions'] as List;
    final t = {'id':DateTime.now().millisecondsSinceEpoch.toString(),'warehouse_code':warehouseCode,'item_code':itemCode,'txn_type':txnType,'qty':qty,'txn_date':txnDate,'note':note,'created_by':createdBy,'created_at':DateTime.now().toIso8601String(),'status':'pending'};
    txns.add(t);
    final isIn = (txnType=='RECEIVE'||txnType=='TRANSFER_IN');
    for (final x in inv['items'] as List) { final m = x as Map<String,dynamic>; if (m['code']==itemCode && m['warehouse_code']==warehouseCode) { final s=(m['stock'] as num?)?.toDouble()??0.0; m['stock']=isIn?s+qty:(s-qty).clamp(0.0,double.infinity); break; } }
    await _write('inventory.json', inv); return t;
  }

  // ─── Transfers ─────────────────────────────────────────────────────────────
  Future<List> listTransfers({String? status, String? fromWarehouse, String? toWarehouse, int limit=200}) async {
    var list = ((await _read('transfers.json')) as List?) ?? [];
    var transfers = list.cast<Map<String,dynamic>>();
    if (status != null) transfers = transfers.where((t) => t['status']==status).toList();
    if (fromWarehouse != null) transfers = transfers.where((t) => t['from_warehouse']==fromWarehouse).toList();
    if (toWarehouse != null) transfers = transfers.where((t) => t['to_warehouse']==toWarehouse).toList();
    transfers.sort((a,b) => ((b['created_at'] as String?)??'').compareTo((a['created_at'] as String?)??''));
    return transfers.take(limit).toList();
  }

  Future<Map<String,dynamic>> createTransfer({required String fromWarehouse, required String toWarehouse, required List<Map<String,dynamic>> items, required String transferDate, String? shiftCode, String? notes, required String createdBy}) async {
    final list = ((await _read('transfers.json')) as List?) ?? [];
    final t = {'id':DateTime.now().millisecondsSinceEpoch.toString(),'from_warehouse':fromWarehouse,'to_warehouse':toWarehouse,'items':items,'transfer_date':transferDate,'shift_code':shiftCode,'notes':notes,'status':'pending','created_by':createdBy,'created_at':DateTime.now().toIso8601String(),'confirmed_by':null,'confirmed_at':null};
    list.add(t); await _write('transfers.json', list); return t;
  }

  Future<Map<String,dynamic>> confirmTransfer(String id, String confirmedBy) async {
    final list = ((await _read('transfers.json')) as List?) ?? [];
    for (final x in list) { final m = x as Map<String,dynamic>; if (m['id']==id) { m['status']='confirmed'; m['confirmed_by']=confirmedBy; m['confirmed_at']=DateTime.now().toIso8601String(); await _write('transfers.json',list); return m; } }
    throw Exception('Transfer not found');
  }

  Future<Map<String,dynamic>> postTransfer(String id, String postedBy) async {
    final list = ((await _read('transfers.json')) as List?) ?? [];
    for (final x in list) { final m = x as Map<String,dynamic>; if (m['id']==id) { if (m['status']!='confirmed') throw Exception('Transfer must be confirmed'); m['status']='posted'; m['posted_by']=postedBy; m['posted_at']=DateTime.now().toIso8601String(); await _applyTransferStock(m); await _write('transfers.json',list); return m; } }
    throw Exception('Transfer not found');
  }

  Future<void> _applyTransferStock(Map<String,dynamic> transfer) async {
    final inv = (await _read('inventory.json') as Map<String,dynamic>?) ?? Map<String,dynamic>.from(_inv());
    final items = (inv['items'] as List).cast<Map<String,dynamic>>();
    for (final ti in (transfer['items'] as List).cast<Map<String,dynamic>>()) {
      final code = ti['item_code'] as String; final qty = (ti['qty'] as num).toDouble();
      for (final item in items) {
        if (item['code']==code && item['warehouse_code']==transfer['from_warehouse']) { item['stock']=((item['stock'] as num?)?.toDouble()??0.0-qty).clamp(0.0,double.infinity); }
        if (item['code']==code && item['warehouse_code']==transfer['to_warehouse']) { item['stock']=((item['stock'] as num?)?.toDouble()??0.0)+qty; }
      }
    }
    await _write('inventory.json', inv);
  }

  // ─── Invoices ──────────────────────────────────────────────────────────────
  Future<List> listInvoices({String? status, int limit=200}) async {
    var list = ((await _read('invoices.json')) as List?) ?? [];
    var invoices = list.cast<Map<String,dynamic>>();
    if (status != null) invoices = invoices.where((i) => i['status']==status).toList();
    invoices.sort((a,b) => ((b['created_at'] as String?)??'').compareTo((a['created_at'] as String?)??''));
    return invoices.take(limit).toList();
  }

  Future<Map<String,dynamic>> createInvoice({required String invoiceNo, required String customer, required List<Map<String,dynamic>> items, required String invoiceDate, String? notes, required String createdBy}) async {
    final list = ((await _read('invoices.json')) as List?) ?? [];
    final inv = {'id':DateTime.now().millisecondsSinceEpoch.toString(),'invoice_no':invoiceNo,'customer':customer,'items':items,'invoice_date':invoiceDate,'notes':notes,'status':'pending','created_by':createdBy,'created_at':DateTime.now().toIso8601String(),'confirmed_by':null};
    list.add(inv); await _write('invoices.json', list); return inv;
  }

  Future<Map<String,dynamic>> confirmInvoice(String id, String confirmedBy) async {
    final list = ((await _read('invoices.json')) as List?) ?? [];
    for (final x in list) { final m = x as Map<String,dynamic>; if (m['id']==id) { m['status']='confirmed'; m['confirmed_by']=confirmedBy; m['confirmed_at']=DateTime.now().toIso8601String(); await _write('invoices.json',list); return m; } }
    throw Exception('Invoice not found');
  }

  Future<Map<String,dynamic>> postInvoice(String id, String postedBy) async {
    final list = ((await _read('invoices.json')) as List?) ?? [];
    for (final x in list) { final m = x as Map<String,dynamic>; if (m['id']==id) { if (m['status']!='confirmed') throw Exception('Invoice must be confirmed'); m['status']='posted'; m['posted_by']=postedBy; m['posted_at']=DateTime.now().toIso8601String(); await _write('invoices.json',list); return m; } }
    throw Exception('Invoice not found');
  }

  // ─── Fuel Logs ─────────────────────────────────────────────────────────────
  Future<List> listFuelLogs({String? status, int limit=200}) async {
    var list = ((await _read('fuel_logs.json')) as List?) ?? [];
    var logs = list.cast<Map<String,dynamic>>();
    if (status != null) logs = logs.where((l) => l['status']==status).toList();
    logs.sort((a,b) => ((b['created_at'] as String?)??'').compareTo((a['created_at'] as String?)??''));
    return logs.take(limit).toList();
  }

  Future<Map<String,dynamic>> createFuelLog({required String shiftDate, required String shiftCode, double receivedQty=0.0, required double gen1Qty, required double gen2Qty, String? notes, required String createdBy}) async {
    final list = ((await _read('fuel_logs.json')) as List?) ?? [];
    final log = {'id':DateTime.now().millisecondsSinceEpoch.toString(),'shift_date':shiftDate,'shift_code':shiftCode,'received_qty':receivedQty,'gen1_qty':gen1Qty,'gen2_qty':gen2Qty,'total_issued':gen1Qty+gen2Qty,'notes':notes,'status':'pending','created_by':createdBy,'created_at':DateTime.now().toIso8601String(),'confirmed_by':null,'confirmed_at':null};
    list.add(log); await _write('fuel_logs.json', list); return log;
  }

  Future<Map<String,dynamic>> confirmFuelLog(String id, String confirmedBy) async {
    final list = ((await _read('fuel_logs.json')) as List?) ?? [];
    for (final x in list) { final m = x as Map<String,dynamic>; if (m['id']==id) { m['status']='confirmed'; m['confirmed_by']=confirmedBy; m['confirmed_at']=DateTime.now().toIso8601String(); await _write('fuel_logs.json',list); return m; } }
    throw Exception('Fuel log not found');
  }

  Future<Map<String,dynamic>> postFuelLog(String id, String postedBy) async {
    final list = ((await _read('fuel_logs.json')) as List?) ?? [];
    for (final x in list) { final m = x as Map<String,dynamic>; if (m['id']==id) { if (m['status']!='confirmed') throw Exception('Must be confirmed'); m['status']='posted'; m['posted_by']=postedBy; m['posted_at']=DateTime.now().toIso8601String(); await _write('fuel_logs.json',list); return m; } }
    throw Exception('Fuel log not found');
  }

  // ─── Stats ─────────────────────────────────────────────────────────────────
  Future<Map<String,dynamic>> getStats() async {
    final s = ((await _read('shifts.json')) as List?) ?? [];
    final transfers = ((await _read('transfers.json')) as List?) ?? [];
    final invoices = ((await _read('invoices.json')) as List?) ?? [];
    final fuelLogs = ((await _read('fuel_logs.json')) as List?) ?? [];
    return {
      'total_shifts':s.length,'open_shifts':s.where((x)=>(x as Map)['status']=='open').length,
      'submitted_shifts':s.where((x)=>(x as Map)['status']=='submitted').length,
      'approved_shifts':s.where((x)=>(x as Map)['status']=='approved').length,
      'pending_transfers':transfers.where((x)=>(x as Map)['status']=='pending').length,
      'pending_invoices':invoices.where((x)=>(x as Map)['status']=='pending').length,
      'pending_fuel_logs':fuelLogs.where((x)=>(x as Map)['status']=='pending').length,
    };
  }

  Future<Map<String,dynamic>> getAllPending() async {
    return {
      'shifts_to_approve': await getShifts(status:'submitted'),
      'shifts_to_post': await getShifts(status:'approved'),
      'transfers_to_post': await listTransfers(status:'confirmed'),
      'invoices_to_post': await listInvoices(status:'confirmed'),
      'fuel_logs_to_post': await listFuelLogs(status:'confirmed'),
    };
  }
}
