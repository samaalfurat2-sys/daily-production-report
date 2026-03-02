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
    await _ensure('$_db/config.json', {'shift_order': ['A','B','C'], 'app_version': '2.2.0'});
  }

  Future<void> _ensure(String p, dynamic d) async {
    try { await graph.readJsonFile(p); } catch (_) { await graph.writeJsonFile(p, d); }
  }

  List _users() => [
    {'id':1,'username':'admin','password_hash':_h('Admin1234'),'roles':['admin'],'unit_permissions':{},'preferred_locale':'en'},
    {'id':2,'username':'supervisor','password_hash':_h('Supervisor123'),'roles':['supervisor','warehouse_supervisor'],'unit_permissions':{},'preferred_locale':'en'},
    {'id':3,'username':'operator','password_hash':_h('Operator123'),'roles':['operator'],'unit_permissions':{'blow':true,'filling':true,'label':true,'shrink':true,'diesel':true},'preferred_locale':'en'},
    {'id':4,'username':'viewer','password_hash':_h('Viewer123'),'roles':['viewer'],'unit_permissions':{},'preferred_locale':'en'},
  ];

  Map _inv() => {
    'warehouses': [
      {'code':'RAW','name':'Raw Materials','name_ar':'المواد الخام','name_en':'Raw Materials'},
      {'code':'FG','name':'Finished Goods','name_ar':'البضاعة الجاهزة','name_en':'Finished Goods'},
    ],
    'items': [
      {'code':'PREFORM','name':'Preforms','name_en':'Preforms','name_ar':'بريفورم','warehouse_code':'RAW','stock':0.0},
      {'code':'CAP','name':'Caps','name_en':'Caps','name_ar':'أغطية','warehouse_code':'RAW','stock':0.0},
      {'code':'LABEL','name':'Labels','name_en':'Labels','name_ar':'لاصقات','warehouse_code':'RAW','stock':0.0},
      {'code':'SHRINK','name':'Shrink Film','name_en':'Shrink Film','name_ar':'فيلم تقليص','warehouse_code':'RAW','stock':0.0},
      {'code':'WATER','name':'Bottled Water','name_en':'Bottled Water','name_ar':'مياه معبأة','warehouse_code':'FG','stock':0.0},
    ],
    'transactions': [],
  };

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
    final n = {'id':DateTime.now().millisecondsSinceEpoch.toString(),'report_date':reportDate,'shift_code':shiftCode,'status':'open','created_by':createdBy,'created_at':DateTime.now().toIso8601String(),'blow':null,'filling':null,'label':null,'shrink':null,'diesel':null};
    s.add(n); await graph.writeJsonFile('$_db/shifts.json', s); return n;
  }

  Future<Map<String,dynamic>> updateUnit(String id, String unit, Map<String,dynamic> p) async {
    final s = await graph.readJsonFile('$_db/shifts.json') as List;
    for (final x in s) { final m = x as Map<String,dynamic>; if (m['id']==id) { m[unit]=p; await graph.writeJsonFile('$_db/shifts.json',s); return m; } }
    throw Exception('Shift not found');
  }

  Future<Map<String,dynamic>> submitShift(String id) => _status(id,'submitted');
  Future<Map<String,dynamic>> approveShift(String id) => _status(id,'approved');
  Future<Map<String,dynamic>> lockShift(String id) => _status(id,'locked');

  Future<Map<String,dynamic>> _status(String id, String st) async {
    final s = await graph.readJsonFile('$_db/shifts.json') as List;
    for (final x in s) { final m = x as Map<String,dynamic>; if (m['id']==id) { m['status']=st; await graph.writeJsonFile('$_db/shifts.json',s); return m; } }
    throw Exception('Shift not found');
  }

  Future<List> getPendingApprovals() => getShifts(status:'submitted');

  Future<List> listWarehouses() async {
    final inv = await graph.readJsonFile('$_db/inventory.json') as Map;
    return (inv['warehouses'] as List? ?? []);
  }

  Future<List> listItems() async {
    final inv = await graph.readJsonFile('$_db/inventory.json') as Map;
    return (inv['items'] as List? ?? []);
  }

  Future<List> listStock() async {
    final inv = await graph.readJsonFile('$_db/inventory.json') as Map<String,dynamic>;
    final items = (inv['items'] as List? ?? []).cast<Map<String,dynamic>>();
    return items.map((item) => <String,dynamic>{
      'warehouse_code': item['warehouse_code'] ?? '',
      'item_code': item['code'] ?? '',
      'item_name_en': item['name_en'] ?? item['name'] ?? '',
      'item_name_ar': item['name_ar'] ?? item['name'] ?? '',
      'qty_on_hand': (item['stock'] as num?)?.toDouble() ?? 0.0,
      'uom': 'pcs',
    }).toList();
  }

  Future<List> listTransactions() async {
    final inv = await graph.readJsonFile('$_db/inventory.json') as Map<String,dynamic>;
    final txns = (inv['transactions'] as List? ?? []).cast<Map<String,dynamic>>();
    final items = (inv['items'] as List? ?? []).cast<Map<String,dynamic>>();
    return txns.map((txn) {
      final item = items.firstWhere((i) => i['code'] == txn['item_code'], orElse: () => <String,dynamic>{});
      return <String,dynamic>{
        ...txn,
        'item_name_en': item['name_en'] ?? item['name'] ?? txn['item_code'] ?? '',
        'item_name_ar': item['name_ar'] ?? item['name'] ?? txn['item_code'] ?? '',
      };
    }).toList();
  }

  Future<Map<String,dynamic>> createTransaction({required String warehouseCode, required String itemCode, required String txnType, required double qty, required String txnDate, String? note}) async {
    final inv = await graph.readJsonFile('$_db/inventory.json') as Map<String,dynamic>;
    final txns = inv['transactions'] as List;
    final t = {'id':DateTime.now().millisecondsSinceEpoch.toString(),'warehouse_code':warehouseCode,'item_code':itemCode,'txn_type':txnType,'qty':qty,'txn_date':txnDate,'note':note,'created_at':DateTime.now().toIso8601String()};
    txns.add(t);
    for (final x in inv['items'] as List) { final m = x as Map<String,dynamic>; if (m['code']==itemCode) { final s=(m['stock'] as num?)?.toDouble()??0.0; m['stock']=txnType=='in'?s+qty:s-qty; break; } }
    await graph.writeJsonFile('$_db/inventory.json',inv); return t;
  }

  Future<Map<String,dynamic>> getStats() async {
    final s = await graph.readJsonFile('$_db/shifts.json') as List;
    return {'total_shifts':s.length,'open_shifts':s.where((x)=>(x as Map)['status']=='open').length,'submitted_shifts':s.where((x)=>(x as Map)['status']=='submitted').length,'approved_shifts':s.where((x)=>(x as Map)['status']=='approved').length};
  }
}
