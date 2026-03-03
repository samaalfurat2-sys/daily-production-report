import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

/// شاشة مراقب الحسابات
/// يرحّل ويؤكد كل العمليات: تقارير الوردية، التحاويل، الفواتير، سجلات الوقود
class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});
  @override State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;
  Map<String, dynamic> _data = {};
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
        db.listShifts(status: 'submitted'),
        db.listShifts(status: 'approved'),
        db.listTransfers(status: 'confirmed'),
        db.listInvoices(status: 'confirmed'),
        db.listFuelLogs(status: 'confirmed'),
      ]);
      _data = {
        'shifts_to_approve': results[0],
        'shifts_to_post': results[1],
        'transfers_to_post': results[2],
        'invoices_to_post': results[3],
        'fuel_logs_to_post': results[4],
      };
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _approveShift(String id) async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await app.db.approveShift(id);
      await _load();
      if (mounted) _showSnack('تم اعتماد تقرير الوردية ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _postShift(String id) async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await app.db.postShift(id, app.token ?? '');
      await _load();
      if (mounted) _showSnack('تم ترحيل تقرير الوردية ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _postTransfer(String id) async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await app.db.postTransfer(id, app.token ?? '');
      await _load();
      if (mounted) _showSnack('تم ترحيل التحويل ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _postInvoice(String id) async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await app.db.postInvoice(id, app.token ?? '');
      await _load();
      if (mounted) _showSnack('تم ترحيل أمر الصرف ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _postFuelLog(String id) async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await app.db.postFuelLog(id, app.token ?? '');
      await _load();
      if (mounted) _showSnack('تم ترحيل سجل الوقود ✓');
    } catch (e) { if (mounted) _showSnack('خطأ: $e', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _showSnack(String msg, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green));

  List<dynamic> _list(String key) => (_data[key] as List?) ?? [];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final shiftsToApprove = _list('shifts_to_approve');
    final shiftsToPost = _list('shifts_to_post');
    final transfersToPost = _list('transfers_to_post');
    final invoicesToPost = _list('invoices_to_post');
    final fuelToPost = _list('fuel_logs_to_post');

    final totalPending = shiftsToApprove.length + shiftsToPost.length +
        transfersToPost.length + invoicesToPost.length + fuelToPost.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(t.controller),
          if (totalPending > 0) ...[
            const SizedBox(width: 8),
            Badge(label: Text('$totalPending'), backgroundColor: Colors.red),
          ]
        ]),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(controller: _tab, tabs: [
          Tab(icon: _badge(Icons.fact_check, shiftsToApprove.length + shiftsToPost.length), text: 'ورديات'),
          Tab(icon: _badge(Icons.swap_horiz, transfersToPost.length), text: 'تحاويل'),
          Tab(icon: _badge(Icons.receipt, invoicesToPost.length), text: 'فواتير'),
          Tab(icon: _badge(Icons.local_gas_station, fuelToPost.length), text: 'وقود'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(controller: _tab, children: [
                  // ── ترحيل الورديات ──
                  ListView(padding: const EdgeInsets.all(12), children: [
                    if (shiftsToApprove.isNotEmpty) ...[
                      _sectionHeader('تقارير تحتاج اعتماد (${shiftsToApprove.length})', Icons.pending, Colors.orange),
                      ...shiftsToApprove.map((s) => _ActionCard(
                        icon: Icons.fact_check, color: Colors.orange,
                        title: '${(s as Map)['report_date'] ?? ''} – وردية ${s['shift_code'] ?? ''}',
                        subtitle: 'أنشأ بواسطة: ${s['created_by'] ?? ''}',
                        statusLabel: 'مُقدَّم', statusColor: Colors.orange,
                        actionLabel: 'اعتماد', actionColor: Colors.blue,
                        onAction: () => _approveShift(s['id'].toString()),
                      )),
                    ],
                    if (shiftsToPost.isNotEmpty) ...[
                      _sectionHeader('تقارير تحتاج ترحيل (${shiftsToPost.length})', Icons.send, Colors.blue),
                      ...shiftsToPost.map((s) => _ActionCard(
                        icon: Icons.fact_check, color: Colors.blue,
                        title: '${(s as Map)['report_date'] ?? ''} – وردية ${s['shift_code'] ?? ''}',
                        subtitle: 'معتمد – بواسطة: ${s['created_by'] ?? ''}',
                        statusLabel: 'معتمد', statusColor: Colors.blue,
                        actionLabel: 'ترحيل', actionColor: Colors.green,
                        onAction: () => _postShift(s['id'].toString()),
                      )),
                    ],
                    if (shiftsToApprove.isEmpty && shiftsToPost.isEmpty)
                      const _EmptyState(label: 'لا توجد ورديات معلقة'),
                  ]),
                  // ── ترحيل التحاويل ──
                  ListView(padding: const EdgeInsets.all(12), children: [
                    _sectionHeader('تحاويل مخزنية جاهزة للترحيل (${transfersToPost.length})', Icons.swap_horiz, Colors.orange),
                    if (transfersToPost.isEmpty) const _EmptyState(label: 'لا توجد تحاويل'),
                    ...transfersToPost.map((tr) {
                      final m = tr as Map<String,dynamic>;
                      final items = (m['items'] as List?)?.cast<Map<String,dynamic>>() ?? [];
                      return _ActionCard(
                        icon: Icons.swap_horiz, color: Colors.orange,
                        title: '${m['from_warehouse'] ?? ''} → ${m['to_warehouse'] ?? ''}',
                        subtitle: items.map((i) => '${i['item_code']}: ${i['qty']}').join(', '),
                        statusLabel: 'مؤكد', statusColor: Colors.blue,
                        actionLabel: 'ترحيل', actionColor: Colors.green,
                        onAction: () => _postTransfer(m['id'].toString()),
                      );
                    }),
                  ]),
                  // ── ترحيل الفواتير ──
                  ListView(padding: const EdgeInsets.all(12), children: [
                    _sectionHeader('أوامر صرف جاهزة للترحيل (${invoicesToPost.length})', Icons.receipt, Colors.purple),
                    if (invoicesToPost.isEmpty) const _EmptyState(label: 'لا توجد فواتير'),
                    ...invoicesToPost.map((inv) {
                      final m = inv as Map<String,dynamic>;
                      final items = (m['items'] as List?)?.cast<Map<String,dynamic>>() ?? [];
                      return _ActionCard(
                        icon: Icons.receipt, color: Colors.purple,
                        title: 'فاتورة ${m['invoice_no'] ?? ''} – ${m['customer'] ?? ''}',
                        subtitle: items.map((i) => '${i['item_code']}: ${i['qty']}').join(', '),
                        statusLabel: 'مؤكد', statusColor: Colors.blue,
                        actionLabel: 'ترحيل', actionColor: Colors.green,
                        onAction: () => _postInvoice(m['id'].toString()),
                      );
                    }),
                  ]),
                  // ── ترحيل الوقود ──
                  ListView(padding: const EdgeInsets.all(12), children: [
                    _sectionHeader('سجلات وقود جاهزة للترحيل (${fuelToPost.length})', Icons.local_gas_station, Colors.amber[800]!),
                    if (fuelToPost.isEmpty) const _EmptyState(label: 'لا توجد سجلات وقود'),
                    ...fuelToPost.map((fl) {
                      final m = fl as Map<String,dynamic>;
                      final g1 = (m['gen1_qty'] as num?)?.toDouble() ?? 0;
                      final g2 = (m['gen2_qty'] as num?)?.toDouble() ?? 0;
                      return _ActionCard(
                        icon: Icons.local_gas_station, color: Colors.amber[800]!,
                        title: '${m['shift_date'] ?? ''} – وردية ${m['shift_code'] ?? ''}',
                        subtitle: 'مولد1: ${g1.toStringAsFixed(1)}  مولد2: ${g2.toStringAsFixed(1)}  إجمالي: ${(g1+g2).toStringAsFixed(1)} لتر',
                        statusLabel: 'مؤكد', statusColor: Colors.blue,
                        actionLabel: 'ترحيل', actionColor: Colors.green,
                        onAction: () => _postFuelLog(m['id'].toString()),
                      );
                    }),
                  ]),
                ]),
    );
  }

  Widget _badge(IconData icon, int count) {
    if (count == 0) return Icon(icon);
    return Stack(clipBehavior: Clip.none, children: [
      Icon(icon),
      Positioned(right: -6, top: -6,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10)))),
    ]);
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle, statusLabel, actionLabel;
  final Color statusColor, actionColor;
  final VoidCallback onAction;
  const _ActionCard({required this.icon, required this.color, required this.title,
    required this.subtitle, required this.statusLabel, required this.statusColor,
    required this.actionLabel, required this.actionColor, required this.onAction});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: Column(children: [
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Chip(label: Text(statusLabel), backgroundColor: statusColor.withOpacity(0.15),
          labelStyle: TextStyle(color: statusColor))),
      Padding(padding: const EdgeInsets.only(bottom: 8, right: 8, left: 8),
        child: SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.send, size: 16),
            label: Text(actionLabel),
            style: ElevatedButton.styleFrom(backgroundColor: actionColor, foregroundColor: Colors.white)))),
    ]));
}

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({required this.label});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.grey)),
    ]));
}

Widget _sectionHeader(String title, IconData icon, Color color) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(children: [
    Icon(icon, color: color, size: 20), const SizedBox(width: 8),
    Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15))),
  ]));
