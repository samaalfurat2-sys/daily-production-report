import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

/// شاشة محاسب المخازن
/// يستلم التقارير والتحاويل والأوامر للمراجعة (قراءة + تأكيد)
class AccountantScreen extends StatefulWidget {
  const AccountantScreen({super.key});
  @override State<AccountantScreen> createState() => _AccountantScreenState();
}

class _AccountantScreenState extends State<AccountantScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;
  List<dynamic> _shifts = [];
  List<dynamic> _transfers = [];
  List<dynamic> _invoices = [];
  List<dynamic> _fuelLogs = [];
  String? _error;

  @override
  void initState() { super.initState(); _tab = TabController(length: 4, vsync: this); _load(); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db = context.read<AppState>().db;
      final results = await Future.wait([
        db.listShifts(),
        db.listTransfers(),
        db.listInvoices(),
        db.listFuelLogs(),
      ]);
      _shifts = results[0]; _transfers = results[1];
      _invoices = results[2]; _fuelLogs = results[3];
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _confirmTransfer(String id) async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await app.db.confirmTransfer(id, app.token ?? '');
      await _load();
      if (mounted) _showSnack('تم تأكيد التحويل ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _confirmInvoice(String id) async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await app.db.confirmInvoice(id, app.token ?? '');
      await _load();
      if (mounted) _showSnack('تم تأكيد أمر الصرف ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _confirmFuelLog(String id) async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await app.db.confirmFuelLog(id, app.token ?? '');
      await _load();
      if (mounted) _showSnack('تم تأكيد سجل الوقود ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  bool get _isReadOnly => context.read<AppState>().isAccountAuditor;

  void _showSnack(String msg, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.accountant),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(controller: _tab, tabs: const [
          Tab(icon: Icon(Icons.fact_check_outlined), text: 'تقارير'),
          Tab(icon: Icon(Icons.swap_horiz_outlined), text: 'تحاويل'),
          Tab(icon: Icon(Icons.receipt_outlined), text: 'فواتير'),
          Tab(icon: Icon(Icons.local_gas_station_outlined), text: 'وقود'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(controller: _tab, children: [
                  // ── تقارير الإنتاج ──
                  _buildShiftsTab(),
                  // ── التحاويل المخزنية ──
                  _buildTransfersTab(),
                  // ── فواتير الصرف ──
                  _buildInvoicesTab(),
                  // ── أوامر صرف الوقود ──
                  _buildFuelTab(),
                ]),
    );
  }

  Widget _buildShiftsTab() => ListView(padding: const EdgeInsets.all(12), children: [
    _sectionHeader('تقارير الإنتاج من مشرف صالة الإنتاج', Icons.fact_check, Colors.indigo),
    if (_shifts.isEmpty) const ListTile(title: Text('لا توجد تقارير')),
    ..._shifts.take(30).map((s) => _ShiftSummaryCard(s as Map<String,dynamic>)),
  ]);

  Widget _buildTransfersTab() => ListView(padding: const EdgeInsets.all(12), children: [
    _sectionHeader('التحاويل المخزنية', Icons.swap_horiz, Colors.orange),
    if (_transfers.isEmpty) const ListTile(title: Text('لا توجد تحاويل')),
    ..._transfers.take(30).map((tr) => _TransferConfirmCard(
      tr as Map<String,dynamic>,
      onConfirm: _isReadOnly ? null : _confirmTransfer,
    )),
  ]);

  Widget _buildInvoicesTab() => ListView(padding: const EdgeInsets.all(12), children: [
    _sectionHeader('أوامر صرف مخزن المنتج الجاهز', Icons.receipt, Colors.purple),
    if (_invoices.isEmpty) const ListTile(title: Text('لا توجد فواتير')),
    ..._invoices.take(30).map((inv) => _InvoiceConfirmCard(
      inv as Map<String,dynamic>,
      onConfirm: _isReadOnly ? null : _confirmInvoice,
    )),
  ]);

  Widget _buildFuelTab() => ListView(padding: const EdgeInsets.all(12), children: [
    _sectionHeader('أوامر صرف الديزل/سولار – كل وردية', Icons.local_gas_station, Colors.amber[800]!),
    if (_fuelLogs.isEmpty) const ListTile(title: Text('لا توجد سجلات وقود')),
    ..._fuelLogs.take(30).map((fl) => _FuelConfirmCard(
      fl as Map<String,dynamic>,
      onConfirm: _isReadOnly ? null : _confirmFuelLog,
    )),
  ]);
}

// ─── Cards ────────────────────────────────────────────────────────────────────
class _ShiftSummaryCard extends StatelessWidget {
  final Map<String,dynamic> s;
  const _ShiftSummaryCard(this.s);
  Color _c(String? st) => switch(st) {
    'posted' => Colors.green, 'approved' => Colors.blue,
    'submitted' => Colors.orange, _ => Colors.grey
  };
  String _l(String? st) => switch(st) {
    'posted' => 'مرحّل', 'approved' => 'معتمد',
    'submitted' => 'مُقدَّم', 'open' => 'مفتوح', _ => st ?? ''
  };
  @override Widget build(BuildContext context) {
    final status = s['status']?.toString();
    return Card(margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: Icon(Icons.fact_check, color: _c(status)),
        title: Text('${s['report_date'] ?? ''} – وردية ${s['shift_code'] ?? ''}'),
        subtitle: Text('بواسطة: ${s['created_by'] ?? ''}'),
        trailing: Chip(label: Text(_l(status)), backgroundColor: _c(status).withOpacity(0.15),
          labelStyle: TextStyle(color: _c(status)))));
  }
}

class _TransferConfirmCard extends StatelessWidget {
  final Map<String,dynamic> t;
  final Function(String)? onConfirm;
  const _TransferConfirmCard(this.t, {this.onConfirm});
  Color _c(String? s) => switch(s) { 'posted' => Colors.green, 'confirmed' => Colors.blue, 'pending' => Colors.orange, _ => Colors.grey };
  String _l(String? s) => switch(s) { 'posted' => 'مرحّل', 'confirmed' => 'مؤكد', 'pending' => 'معلق', _ => s ?? '' };
  @override Widget build(BuildContext context) {
    final status = t['status']?.toString();
    final items = (t['items'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    return Card(margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        ListTile(
          leading: Icon(Icons.swap_horiz, color: _c(status)),
          title: Text('${t['from_warehouse'] ?? ''} → ${t['to_warehouse'] ?? ''}'),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t['transfer_date']?.toString() ?? t['created_at']?.toString()?.substring(0,10) ?? ''),
            ...items.map((i) => Text('${i['item_code']}: ${i['qty']}')),
          ]),
          trailing: Chip(label: Text(_l(status)), backgroundColor: _c(status).withOpacity(0.15),
            labelStyle: TextStyle(color: _c(status)))),
        if (status == 'pending' && onConfirm != null)
          Padding(padding: const EdgeInsets.only(bottom: 8, right: 8, left: 8),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onConfirm!(t['id'].toString()),
                icon: const Icon(Icons.check), label: const Text('تأكيد الاستلام'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white)))),
      ]));
  }
}

class _InvoiceConfirmCard extends StatelessWidget {
  final Map<String,dynamic> inv;
  final Function(String)? onConfirm;
  const _InvoiceConfirmCard(this.inv, {this.onConfirm});
  Color _c(String? s) => switch(s) { 'posted' => Colors.green, 'confirmed' => Colors.blue, 'pending' => Colors.orange, _ => Colors.grey };
  String _l(String? s) => switch(s) { 'posted' => 'مرحّل', 'confirmed' => 'مؤكد', 'pending' => 'معلق', _ => s ?? '' };
  @override Widget build(BuildContext context) {
    final status = inv['status']?.toString();
    final items = (inv['items'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    return Card(margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        ListTile(
          leading: Icon(Icons.receipt, color: _c(status)),
          title: Text('فاتورة ${inv['invoice_no'] ?? ''} – ${inv['customer'] ?? ''}'),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(inv['invoice_date']?.toString() ?? ''),
            ...items.map((i) => Text('${i['item_code']}: ${i['qty']}')),
          ]),
          trailing: Chip(label: Text(_l(status)), backgroundColor: _c(status).withOpacity(0.15),
            labelStyle: TextStyle(color: _c(status)))),
        if (status == 'pending' && onConfirm != null)
          Padding(padding: const EdgeInsets.only(bottom: 8, right: 8, left: 8),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onConfirm!(inv['id'].toString()),
                icon: const Icon(Icons.check), label: const Text('تأكيد أمر الصرف'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white)))),
      ]));
  }
}

class _FuelConfirmCard extends StatelessWidget {
  final Map<String,dynamic> log;
  final Function(String)? onConfirm;
  const _FuelConfirmCard(this.log, {this.onConfirm});
  Color _c(String? s) => switch(s) { 'posted' => Colors.green, 'confirmed' => Colors.blue, 'pending' => Colors.orange, _ => Colors.grey };
  String _l(String? s) => switch(s) { 'posted' => 'مرحّل', 'confirmed' => 'مؤكد', 'pending' => 'معلق', _ => s ?? '' };
  @override Widget build(BuildContext context) {
    final status = log['status']?.toString();
    final g1 = (log['gen1_qty'] as num?)?.toDouble() ?? 0;
    final g2 = (log['gen2_qty'] as num?)?.toDouble() ?? 0;
    final recv = (log['received_qty'] as num?)?.toDouble() ?? 0;
    return Card(margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        ListTile(
          leading: Icon(Icons.local_gas_station, color: _c(status)),
          title: Text('${log['shift_date'] ?? ''} – وردية ${log['shift_code'] ?? ''}'),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (recv > 0) Text('وارد: ${recv.toStringAsFixed(1)} لتر', style: const TextStyle(color: Colors.green)),
            Text('مولد 1: ${g1.toStringAsFixed(1)} لتر  |  مولد 2: ${g2.toStringAsFixed(1)} لتر'),
            Text('إجمالي الصرف: ${(g1+g2).toStringAsFixed(1)} لتر', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          trailing: Chip(label: Text(_l(status)), backgroundColor: _c(status).withOpacity(0.15),
            labelStyle: TextStyle(color: _c(status)))),
        if (status == 'pending' && onConfirm != null)
          Padding(padding: const EdgeInsets.only(bottom: 8, right: 8, left: 8),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onConfirm!(log['id'].toString()),
                icon: const Icon(Icons.check), label: const Text('تأكيد سجل الوقود'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white)))),
      ]));
  }
}

Widget _sectionHeader(String title, IconData icon, Color color) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(children: [
    Icon(icon, color: color, size: 20), const SizedBox(width: 8),
    Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15))),
  ]));
