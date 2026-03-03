import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

/// شاشة أمين مخزن المواد الخام
/// الصلاحيات: استلام المواد الخام + تحويلها إلى صالة الإنتاج
class RawWarehouseScreen extends StatefulWidget {
  const RawWarehouseScreen({super.key});
  @override State<RawWarehouseScreen> createState() => _RawWarehouseScreenState();
}

class _RawWarehouseScreenState extends State<RawWarehouseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;
  List<dynamic> _stock = [];
  List<dynamic> _txns = [];
  List<dynamic> _transfers = [];
  List<dynamic> _items = [];
  String? _error;

  final _qty = TextEditingController();
  final _note = TextEditingController();
  final _transferQty = TextEditingController();
  String _itemCode = 'PREFORM';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tab.dispose(); _qty.dispose(); _note.dispose(); _transferQty.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db = context.read<AppState>().db;
      _stock = (await db.listStock(warehouseCode: 'RAW')) as List;
      _txns = (await db.listTransactions(warehouseCode: 'RAW')) as List;
      _transfers = (await db.listTransfers(fromWarehouse: 'RAW')) as List;
      _items = (await db.listItems(warehouseCode: 'RAW')) as List;
      if (_items.isNotEmpty) _itemCode = (_items.first as Map)['code'].toString();
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _receive() async {
    final qty = double.tryParse(_qty.text.trim()) ?? 0;
    if (qty <= 0) return;
    setState(() => _loading = true);
    try {
      final db = context.read<AppState>().db;
      final app = context.read<AppState>();
      await db.createTransaction(
        warehouseCode: 'RAW', itemCode: _itemCode,
        txnType: 'RECEIVE', qty: qty,
        txnDate: DateTime.now().toIso8601String().substring(0,10),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        createdBy: app.token,
      );
      _qty.clear(); _note.clear();
      await _load();
      if (mounted) _showSnack('تم استلام المواد بنجاح ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _transfer() async {
    final qty = double.tryParse(_transferQty.text.trim()) ?? 0;
    if (qty <= 0) return;
    setState(() => _loading = true);
    try {
      final db = context.read<AppState>().db;
      final app = context.read<AppState>();
      await db.createTransfer(
        fromWarehouse: 'RAW', toWarehouse: 'HALL',
        items: [{'item_code': _itemCode, 'qty': qty}],
        transferDate: DateTime.now().toIso8601String().substring(0,10),
        notes: _note.text.trim().isEmpty ? null : _note.text.trim(),
        createdBy: app.token ?? '',
      );
      _transferQty.clear(); _note.clear();
      await _load();
      if (mounted) _showSnack('تم إرسال طلب التحويل لصالة الإنتاج ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.rawWarehouse),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(controller: _tab, tabs: const [
          Tab(icon: Icon(Icons.inventory_2_outlined), text: 'الرصيد'),
          Tab(icon: Icon(Icons.download_outlined), text: 'استلام'),
          Tab(icon: Icon(Icons.swap_horiz_outlined), text: 'تحويل'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(controller: _tab, children: [
                  _StockTab(stock: _stock, transfers: _transfers),
                  _ReceiveTab(items: _items, itemCode: _itemCode, qty: _qty, note: _note,
                    onItemChanged: (v) => setState(() => _itemCode = v!),
                    onReceive: _receive, txns: _txns),
                  _TransferTab(items: _items, itemCode: _itemCode, qty: _transferQty, note: _note,
                    onItemChanged: (v) => setState(() => _itemCode = v!),
                    onTransfer: _transfer, transfers: _transfers),
                ]),
    );
  }
}

// ── الرصيد ──────────────────────────────────────────────────────────────────
class _StockTab extends StatelessWidget {
  final List stock;
  final List transfers;
  const _StockTab({required this.stock, required this.transfers});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
    _sectionHeader('الرصيد الحالي – مخزن المواد الخام', Icons.inventory_2, Colors.blue),
    ...stock.map((s) => _StockCard(s as Map<String,dynamic>)),
    const SizedBox(height: 16),
    _sectionHeader('التحاويل المرسلة لصالة الإنتاج', Icons.swap_horiz, Colors.orange),
    if (transfers.isEmpty) const ListTile(title: Text('لا توجد تحاويل')),
    ...transfers.map((t) => _TransferCard(t as Map<String,dynamic>)),
  ]);
}

// ── الاستلام ─────────────────────────────────────────────────────────────────
class _ReceiveTab extends StatelessWidget {
  final List items;
  final String itemCode;
  final TextEditingController qty, note;
  final ValueChanged<String?> onItemChanged;
  final VoidCallback onReceive;
  final List txns;
  const _ReceiveTab({required this.items, required this.itemCode, required this.qty,
    required this.note, required this.onItemChanged, required this.onReceive, required this.txns});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      _sectionHeader('استلام مواد خام', Icons.download, Colors.green),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: itemCode, decoration: const InputDecoration(labelText: 'الصنف', border: OutlineInputBorder()),
        items: items.map<DropdownMenuItem<String>>((i) {
          final m = i as Map<String,dynamic>;
          return DropdownMenuItem(value: m['code'].toString(), child: Text(m['name_ar']?.toString() ?? m['code'].toString()));
        }).toList(),
        onChanged: onItemChanged,
      ),
      const SizedBox(height: 12),
      TextField(controller: qty, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity,
        child: FilledButton.icon(onPressed: onReceive, icon: const Icon(Icons.add), label: const Text('تسجيل الاستلام'))),
    ]))),
    const SizedBox(height: 16),
    _sectionHeader('آخر الحركات', Icons.history, Colors.grey),
    ...txns.take(20).map((t) => _TxnCard(t as Map<String,dynamic>)),
  ]);
}

// ── التحويل ──────────────────────────────────────────────────────────────────
class _TransferTab extends StatelessWidget {
  final List items;
  final String itemCode;
  final TextEditingController qty, note;
  final ValueChanged<String?> onItemChanged;
  final VoidCallback onTransfer;
  final List transfers;
  const _TransferTab({required this.items, required this.itemCode, required this.qty,
    required this.note, required this.onItemChanged, required this.onTransfer, required this.transfers});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      _sectionHeader('تحويل إلى صالة الإنتاج', Icons.swap_horiz, Colors.orange),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: itemCode, decoration: const InputDecoration(labelText: 'الصنف', border: OutlineInputBorder()),
        items: items.map<DropdownMenuItem<String>>((i) {
          final m = i as Map<String,dynamic>;
          return DropdownMenuItem(value: m['code'].toString(), child: Text(m['name_ar']?.toString() ?? m['code'].toString()));
        }).toList(),
        onChanged: onItemChanged,
      ),
      const SizedBox(height: 12),
      TextField(controller: qty, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'الكمية المحولة', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity,
        child: FilledButton.icon(onPressed: onTransfer, icon: const Icon(Icons.send), label: const Text('إرسال تحويل'))),
    ]))),
    const SizedBox(height: 16),
    _sectionHeader('التحاويل السابقة', Icons.history, Colors.grey),
    ...transfers.take(20).map((t) => _TransferCard(t as Map<String,dynamic>)),
  ]);
}

// ─── Shared Cards ────────────────────────────────────────────────────────────
Widget _sectionHeader(String title, IconData icon, Color color) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(children: [
    Icon(icon, color: color, size: 20),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
  ]),
);

class _StockCard extends StatelessWidget {
  final Map<String,dynamic> s;
  const _StockCard(this.s);
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      leading: const Icon(Icons.inventory_2, color: Colors.blue),
      title: Text(s['item_name_ar']?.toString() ?? s['item_code']?.toString() ?? ''),
      trailing: Chip(
        label: Text('${(s['qty_on_hand'] as num?)?.toStringAsFixed(1) ?? '0'} ${s['uom'] ?? ''}'),
        backgroundColor: Colors.blue.shade50,
      ),
    ));
}

class _TxnCard extends StatelessWidget {
  final Map<String,dynamic> t;
  const _TxnCard(this.t);
  @override
  Widget build(BuildContext context) {
    final isIn = t['txn_type'] == 'RECEIVE' || t['txn_type'] == 'TRANSFER_IN';
    return Card(margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: Icon(isIn ? Icons.add_circle : Icons.remove_circle,
          color: isIn ? Colors.green : Colors.orange),
        title: Text(t['item_code']?.toString() ?? ''),
        subtitle: Text(t['txn_date']?.toString() ?? ''),
        trailing: Text('${isIn ? '+' : '-'}${t['qty']}',
          style: TextStyle(color: isIn ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
      ));
  }
}

class _TransferCard extends StatelessWidget {
  final Map<String,dynamic> t;
  const _TransferCard(this.t);
  Color _statusColor(String? s) => switch(s) {
    'posted' => Colors.green, 'confirmed' => Colors.blue,
    'pending' => Colors.orange, _ => Colors.grey,
  };
  String _statusLabel(String? s) => switch(s) {
    'posted' => 'مرحّل', 'confirmed' => 'مؤكد',
    'pending' => 'معلق', _ => s ?? '',
  };
  @override
  Widget build(BuildContext context) {
    final status = t['status']?.toString();
    final items = (t['items'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    return Card(margin: const EdgeInsets.symmetric(vertical: 3),
      child: ExpansionTile(
        leading: Icon(Icons.swap_horiz, color: _statusColor(status)),
        title: Text('${t['from_warehouse']} ← ${t['to_warehouse']}'),
        subtitle: Text(t['transfer_date']?.toString() ?? t['created_at']?.toString()?.substring(0,10) ?? ''),
        trailing: Chip(
          label: Text(_statusLabel(status)),
          backgroundColor: _statusColor(status).withOpacity(0.15),
          labelStyle: TextStyle(color: _statusColor(status)),
        ),
        children: items.map((i) => ListTile(
          dense: true,
          title: Text(i['item_code']?.toString() ?? ''),
          trailing: Text('${i['qty']}'),
        )).toList(),
      ));
  }
}
