import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

/// شاشة أمين مخزن المحروقات النفطية
/// الصلاحيات: استلام الديزل + صرف للمولد 1 والمولد 2 مع كل وردية
class FuelWarehouseScreen extends StatefulWidget {
  const FuelWarehouseScreen({super.key});
  @override State<FuelWarehouseScreen> createState() => _FuelWarehouseScreenState();
}

class _FuelWarehouseScreenState extends State<FuelWarehouseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;
  List<dynamic> _logs = [];
  List<dynamic> _stock = [];
  String? _error;

  final _receivedQty = TextEditingController();
  final _gen1Qty = TextEditingController();
  final _gen2Qty = TextEditingController();
  final _note = TextEditingController();
  String _shiftCode = 'A';
  DateTime _shiftDate = DateTime.now();

  @override
  void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); _load(); }
  @override
  void dispose() { _tab.dispose(); _receivedQty.dispose(); _gen1Qty.dispose(); _gen2Qty.dispose(); _note.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db = context.read<AppState>().db;
      _logs = (await db.listFuelLogs()) as List;
      _stock = (await db.listStock(warehouseCode: 'FUEL')) as List;
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _saveFuelLog({bool receiveOnly = false}) async {
    final g1 = double.tryParse(_gen1Qty.text.trim()) ?? 0;
    final g2 = double.tryParse(_gen2Qty.text.trim()) ?? 0;
    final recv = double.tryParse(_receivedQty.text.trim()) ?? 0;
    if (!receiveOnly && g1 + g2 <= 0) { _showSnack('أدخل كمية المولد 1 أو المولد 2', error: true); return; }
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      final dateStr = '${_shiftDate.year}-${_shiftDate.month.toString().padLeft(2,'0')}-${_shiftDate.day.toString().padLeft(2,'0')}';
      await app.db.createFuelLog(
        shiftDate: dateStr, shiftCode: _shiftCode,
        receivedQty: recv, gen1Qty: g1, gen2Qty: g2,
        notes: _note.text.trim().isEmpty ? null : _note.text.trim(),
        createdBy: app.token ?? '',
      );
      _gen1Qty.clear(); _gen2Qty.clear(); _receivedQty.clear(); _note.clear();
      await _load();
      if (mounted) _showSnack('تم تسجيل حركة الوقود بنجاح ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _showSnack(String msg, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final dateText = '${_shiftDate.year}-${_shiftDate.month.toString().padLeft(2,'0')}-${_shiftDate.day.toString().padLeft(2,'0')}';
    return Scaffold(
      appBar: AppBar(
        title: Text(t.fuelWarehouse),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(controller: _tab, tabs: const [
          Tab(icon: Icon(Icons.local_gas_station_outlined), text: 'الرصيد'),
          Tab(icon: Icon(Icons.add_box_outlined), text: 'استلام ديزل'),
          Tab(icon: Icon(Icons.power_outlined), text: 'صرف وردية'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(controller: _tab, children: [
                  // ── رصيد الوقود ──
                  ListView(padding: const EdgeInsets.all(12), children: [
                    _sectionHeader('رصيد مخزن المحروقات', Icons.local_gas_station, Colors.amber[800]!),
                    ..._stock.map((s) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.local_gas_station, color: Colors.amber),
                        title: Text((s as Map)['item_name_ar']?.toString() ?? ''),
                        trailing: Chip(
                          label: Text('${(s['qty_on_hand'] as num?)?.toStringAsFixed(1) ?? '0'} لتر'),
                          backgroundColor: Colors.amber.shade50)))),
                    const SizedBox(height: 16),
                    _sectionHeader('آخر سجلات الوقود', Icons.history, Colors.grey),
                    ..._logs.take(15).map((l) => _FuelLogCard(l as Map<String,dynamic>)),
                  ]),
                  // ── استلام ديزل ──
                  ListView(padding: const EdgeInsets.all(12), children: [
                    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                      _sectionHeader('استلام كمية ديزل/سولار', Icons.download, Colors.green),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final p = await showDatePicker(context: context,
                            firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _shiftDate);
                          if (p != null) setState(() => _shiftDate = p);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'التاريخ', border: OutlineInputBorder()),
                          child: Text(dateText))),
                      const SizedBox(height: 12),
                      TextField(controller: _receivedQty, keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'الكمية المستلمة (لتر) *', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final recv = double.tryParse(_receivedQty.text.trim()) ?? 0;
                            if (recv <= 0) { _showSnack('أدخل الكمية المستلمة', error: true); return; }
                            _gen1Qty.text = '0'; _gen2Qty.text = '0';
                            await _saveFuelLog(receiveOnly: true);
                          },
                          icon: const Icon(Icons.add), label: const Text('تسجيل الاستلام'))),
                    ]))),
                    const SizedBox(height: 16),
                    _sectionHeader('سجلات الاستلام', Icons.history, Colors.grey),
                    ..._logs.where((l) => ((l as Map)['received_qty'] as num? ?? 0) > 0)
                        .take(10).map((l) => _FuelLogCard(l as Map<String,dynamic>)),
                  ]),
                  // ── صرف وردية ──
                  ListView(padding: const EdgeInsets.all(12), children: [
                    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                      _sectionHeader('صرف الديزل – وردية إنتاج', Icons.power, Colors.deepOrange),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final p = await showDatePicker(context: context,
                            firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _shiftDate);
                          if (p != null) setState(() => _shiftDate = p);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'تاريخ الوردية', border: OutlineInputBorder()),
                          child: Text(dateText))),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _shiftCode,
                        decoration: const InputDecoration(labelText: 'رمز الوردية', border: OutlineInputBorder()),
                        items: ['A','B','C'].map((s) => DropdownMenuItem(value: s, child: Text('وردية $s'))).toList(),
                        onChanged: (v) => setState(() => _shiftCode = v!),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _gen1Qty, keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'المولد 1 (لتر)', prefixIcon: Icon(Icons.electric_bolt), border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: _gen2Qty, keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'المولد 2 (لتر)', prefixIcon: Icon(Icons.electric_bolt_outlined), border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () { _receivedQty.text = '0'; _saveFuelLog(); },
                          icon: const Icon(Icons.send), label: const Text('تسجيل صرف الوردية'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange))),
                    ]))),
                    const SizedBox(height: 16),
                    _sectionHeader('سجلات الصرف', Icons.history, Colors.grey),
                    ..._logs.take(15).map((l) => _FuelLogCard(l as Map<String,dynamic>)),
                  ]),
                ]),
    );
  }
}

class _FuelLogCard extends StatelessWidget {
  final Map<String,dynamic> log;
  const _FuelLogCard(this.log);
  Color _c(String? s) => switch(s) { 'posted' => Colors.green, 'confirmed' => Colors.blue, 'pending' => Colors.orange, _ => Colors.grey };
  String _l(String? s) => switch(s) { 'posted' => 'مرحّل', 'confirmed' => 'مؤكد', 'pending' => 'معلق', _ => s ?? '' };
  @override Widget build(BuildContext context) {
    final status = log['status']?.toString();
    final recv = (log['received_qty'] as num?)?.toDouble() ?? 0;
    final g1 = (log['gen1_qty'] as num?)?.toDouble() ?? 0;
    final g2 = (log['gen2_qty'] as num?)?.toDouble() ?? 0;
    return Card(margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: Icon(Icons.local_gas_station, color: _c(status)),
        title: Text('${log['shift_date'] ?? ''} – وردية ${log['shift_code'] ?? ''}'),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (recv > 0) Text('وارد: ${recv.toStringAsFixed(1)} لتر', style: const TextStyle(color: Colors.green)),
          if (g1 > 0) Text('مولد 1: ${g1.toStringAsFixed(1)} لتر'),
          if (g2 > 0) Text('مولد 2: ${g2.toStringAsFixed(1)} لتر'),
          Text('الإجمالي المصروف: ${(g1+g2).toStringAsFixed(1)} لتر', style: const TextStyle(color: Colors.red)),
        ]),
        trailing: Chip(label: Text(_l(status)), backgroundColor: _c(status).withOpacity(0.15),
          labelStyle: TextStyle(color: _c(status)))));
  }
}

Widget _sectionHeader(String title, IconData icon, Color color) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(children: [
    Icon(icon, color: color, size: 20), const SizedBox(width: 8),
    Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
  ]));
