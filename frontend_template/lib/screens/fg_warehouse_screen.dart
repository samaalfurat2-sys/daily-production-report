import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

/// شاشة أمين مخزن المنتج الجاهز
/// الصلاحيات: استلام من صالة الإنتاج + صرف بموجب فواتير
class FgWarehouseScreen extends StatefulWidget {
  const FgWarehouseScreen({super.key});
  @override State<FgWarehouseScreen> createState() => _FgWarehouseScreenState();
}

class _FgWarehouseScreenState extends State<FgWarehouseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;
  List<dynamic> _stock = [];
  List<dynamic> _transfers = [];
  List<dynamic> _invoices = [];
  List<dynamic> _items = [];
  String? _error;

  final _invNo = TextEditingController();
  final _customer = TextEditingController();
  final _qty = TextEditingController();
  final _note = TextEditingController();
  String _itemCode = 'WATER_500';

  @override
  void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); _load(); }
  @override
  void dispose() { _tab.dispose(); _invNo.dispose(); _customer.dispose(); _qty.dispose(); _note.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db = context.read<AppState>().db;
      final results = await Future.wait([
        db.listStock(warehouseCode: 'FG'),
        db.listTransfers(toWarehouse: 'FG'),
        db.listInvoices(),
        db.listItems(warehouseCode: 'FG'),
      ]);
      _stock = results[0]; _transfers = results[1];
      _invoices = results[2]; _items = results[3];
      if (_items.isNotEmpty) _itemCode = (_items.first as Map)['code'].toString();
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _confirmTransfer(String id) async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await app.db.confirmTransfer(id, app.token ?? '');
      await _load();
      if (mounted) _showSnack('تم تأكيد الاستلام من صالة الإنتاج ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _createInvoice() async {
    final qty = double.tryParse(_qty.text.trim()) ?? 0;
    if (qty <= 0 || _invNo.text.isEmpty || _customer.text.isEmpty) {
      _showSnack('يرجى ملء جميع الحقول المطلوبة', error: true); return;
    }
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await app.db.createInvoice(
        invoiceNo: _invNo.text.trim(),
        customer: _customer.text.trim(),
        items: [{'item_code': _itemCode, 'qty': qty}],
        invoiceDate: DateTime.now().toIso8601String().substring(0,10),
        notes: _note.text.trim().isEmpty ? null : _note.text.trim(),
        createdBy: app.token ?? '',
      );
      _invNo.clear(); _customer.clear(); _qty.clear(); _note.clear();
      await _load();
      if (mounted) _showSnack('تم إنشاء أمر الصرف بنجاح ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _showSnack(String msg, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.fgWarehouse),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(controller: _tab, tabs: const [
          Tab(icon: Icon(Icons.inventory_outlined), text: 'الرصيد'),
          Tab(icon: Icon(Icons.download_outlined), text: 'استلام'),
          Tab(icon: Icon(Icons.receipt_outlined), text: 'فواتير الصرف'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(controller: _tab, children: [
                  // ── رصيد ──
                  ListView(padding: const EdgeInsets.all(12), children: [
                    _sectionHeader('رصيد مخزن المنتج الجاهز', Icons.inventory, Colors.teal),
                    ..._stock.map((s) => _StockCard(s as Map<String,dynamic>)),
                    const SizedBox(height: 16),
                    _sectionHeader('التحاويل الواردة من صالة الإنتاج', Icons.swap_horiz, Colors.blue),
                    if (_transfers.isEmpty) const ListTile(title: Text('لا توجد تحاويل')),
                    ..._transfers.take(10).map((t) => _IncomingTransferCard(t as Map<String,dynamic>, onConfirm: _confirmTransfer)),
                  ]),
                  // ── استلام (تأكيد التحاويل المعلقة) ──
                  ListView(padding: const EdgeInsets.all(12), children: [
                    _sectionHeader('استلام من صالة الإنتاج', Icons.download, Colors.green),
                    const Padding(padding: EdgeInsets.all(8), child: Text(
                      'اضغط "تأكيد الاستلام" على كل تحويل وارد من صالة الإنتاج.',
                      style: TextStyle(color: Colors.grey))),
                    ..._transfers.where((t) => (t as Map)['status']=='pending')
                        .map((t) => _IncomingTransferCard(t as Map<String,dynamic>, onConfirm: _confirmTransfer)),
                    if (_transfers.where((t)=>(t as Map)['status']=='pending').isEmpty)
                      const ListTile(leading: Icon(Icons.check_circle, color: Colors.green),
                        title: Text('لا توجد تحاويل معلقة')),
                  ]),
                  // ── فواتير الصرف ──
                  ListView(padding: const EdgeInsets.all(12), children: [
                    _sectionHeader('أمر صرف جديد', Icons.add_circle, Colors.purple),
                    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                      DropdownButtonFormField<String>(
                        value: _itemCode,
                        decoration: const InputDecoration(labelText: 'الصنف', border: OutlineInputBorder()),
                        items: _items.map<DropdownMenuItem<String>>((i) {
                          final m = i as Map<String,dynamic>;
                          return DropdownMenuItem(value: m['code'].toString(), child: Text(m['name_ar']?.toString() ?? ''));
                        }).toList(),
                        onChanged: (v) => setState(() => _itemCode = v!),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: _invNo, decoration: const InputDecoration(labelText: 'رقم الفاتورة *', border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: _customer, decoration: const InputDecoration(labelText: 'العميل *', border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: _qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية *', border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity,
                        child: FilledButton.icon(onPressed: _createInvoice, icon: const Icon(Icons.receipt), label: const Text('إنشاء أمر الصرف'))),
                    ]))),
                    const SizedBox(height: 16),
                    _sectionHeader('أوامر الصرف السابقة', Icons.history, Colors.grey),
                    ..._invoices.take(20).map((inv) => _InvoiceCard(inv as Map<String,dynamic>)),
                  ]),
                ]),
    );
  }
}

class _StockCard extends StatelessWidget {
  final Map<String,dynamic> s;
  const _StockCard(this.s);
  @override Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      leading: const Icon(Icons.inventory, color: Colors.teal),
      title: Text(s['item_name_ar']?.toString() ?? s['item_code']?.toString() ?? ''),
      trailing: Chip(
        label: Text('${(s['qty_on_hand'] as num?)?.toStringAsFixed(1) ?? '0'} ${s['uom'] ?? ''}'),
        backgroundColor: Colors.teal.shade50,
      )));
}

class _IncomingTransferCard extends StatelessWidget {
  final Map<String,dynamic> t;
  final Function(String) onConfirm;
  const _IncomingTransferCard(this.t, {required this.onConfirm});
  Color _statusColor(String? s) => switch(s) {
    'posted' => Colors.green, 'confirmed' => Colors.blue,
    'pending' => Colors.orange, _ => Colors.grey,
  };
  String _statusLabel(String? s) => switch(s) {
    'posted' => 'مرحّل', 'confirmed' => 'مستلم', 'pending' => 'في الانتظار', _ => s ?? '',
  };
  @override Widget build(BuildContext context) {
    final status = t['status']?.toString();
    final items = (t['items'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    return Card(margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        ListTile(
          leading: Icon(Icons.swap_horiz, color: _statusColor(status)),
          title: Text('تحويل من ${t['from_warehouse'] ?? ''} – ${t['transfer_date'] ?? ''}'),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((i) => Text('${i['item_code']}: ${i['qty']}')).toList()),
          trailing: Chip(label: Text(_statusLabel(status)),
            backgroundColor: _statusColor(status).withOpacity(0.15),
            labelStyle: TextStyle(color: _statusColor(status))),
        ),
        if (status == 'pending') Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 8, left: 8),
          child: SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onConfirm(t['id'].toString()),
              icon: const Icon(Icons.check), label: const Text('تأكيد الاستلام'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)))),
      ]));
  }
}

class _InvoiceCard extends StatelessWidget {
  final Map<String,dynamic> inv;
  const _InvoiceCard(this.inv);
  Color _c(String? s) => switch(s) { 'posted' => Colors.green, 'confirmed' => Colors.blue, 'pending' => Colors.orange, _ => Colors.grey };
  String _l(String? s) => switch(s) { 'posted' => 'مرحّل', 'confirmed' => 'مؤكد', 'pending' => 'معلق', _ => s ?? '' };
  @override Widget build(BuildContext context) {
    final status = inv['status']?.toString();
    final items = (inv['items'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    return Card(margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: Icon(Icons.receipt, color: _c(status)),
        title: Text('فاتورة ${inv['invoice_no'] ?? ''} – ${inv['customer'] ?? ''}'),
        subtitle: Text(items.map((i) => '${i['item_code']}: ${i['qty']}').join(', ')),
        trailing: Chip(label: Text(_l(status)), backgroundColor: _c(status).withOpacity(0.15),
          labelStyle: TextStyle(color: _c(status)))));
  }
}

Widget _sectionHeader(String title, IconData icon, Color color) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(children: [
    Icon(icon, color: color, size: 20),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
  ]));
