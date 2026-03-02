import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;
  List<dynamic> _warehouses = [];
  List<dynamic> _stock = [];
  List<dynamic> _transactions = [];
  List<dynamic> _items = [];
  String? _error;

  final _qty = TextEditingController();
  String _warehouseCode = 'RM';
  String _itemCode = 'RM_PREFORM_CARTON';
  String _txnType = 'RECEIVE';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db = context.read<AppState>().db;
      final results = await Future.wait([
        db.listWarehouses(),
        db.listStock(),
        db.listTransactions(),
        db.listItems(),
      ]);
      _warehouses = results[0];
      _stock = results[1];
      _transactions = results[2];
      _items = results[3];
      if (_warehouses.isNotEmpty) _warehouseCode = (_warehouses.first as Map<String, dynamic>)['code'].toString();
      if (_items.isNotEmpty) _itemCode = (_items.first as Map<String, dynamic>)['code'].toString();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _label(Map<String, dynamic> row, BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return isAr ? row['name_ar'].toString() : row['name_en'].toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.warehouses),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: t.stockOnHand),
            Tab(text: t.transactions),
            Tab(text: t.newTransaction),
          ],
        ),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tab,
                  children: [
                    _stockTab(t),
                    _transactionsTab(t),
                    _createTxnTab(t),
                  ],
                ),
    );
  }

  Widget _stockTab(AppLocalizations t) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _stock.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final row = _stock[i] as Map<String, dynamic>;
        final name = Localizations.localeOf(context).languageCode == 'ar' ? row['item_name_ar'] : row['item_name_en'];
        return ListTile(
          title: Text('${row['warehouse_code']} • $name'),
          subtitle: Text('${row['item_code']} • ${row['uom']}'),
          trailing: Text(row['qty_on_hand'].toString()),
        );
      },
    );
  }

  Widget _transactionsTab(AppLocalizations t) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final row = _transactions[i] as Map<String, dynamic>;
        final name = Localizations.localeOf(context).languageCode == 'ar' ? row['item_name_ar'] : row['item_name_en'];
        return ListTile(
          title: Text('${row['txn_date']} • ${row['warehouse_code']} • $name'),
          subtitle: Text('${row['txn_type']} • ${row['note'] ?? ''}'),
          trailing: Text(row['qty'].toString()),
        );
      },
    );
  }

  Widget _createTxnTab(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          DropdownButtonFormField<String>(
            value: _warehouseCode,
            items: _warehouses.map((e) {
              final m = e as Map<String, dynamic>;
              return DropdownMenuItem(value: m['code'].toString(), child: Text('${m['code']} • ${_label(m, context)}'));
            }).toList(),
            onChanged: (v) => setState(() => _warehouseCode = v ?? _warehouseCode),
            decoration: InputDecoration(labelText: t.warehouse, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _itemCode,
            items: _items.map((e) {
              final m = e as Map<String, dynamic>;
              final isAr = Localizations.localeOf(context).languageCode == 'ar';
              final label = isAr ? m['name_ar'].toString() : m['name_en'].toString();
              return DropdownMenuItem(value: m['code'].toString(), child: Text('${m['code']} • $label'));
            }).toList(),
            onChanged: (v) => setState(() => _itemCode = v ?? _itemCode),
            decoration: InputDecoration(labelText: t.item, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _txnType,
            items: const [
              DropdownMenuItem(value: 'RECEIVE', child: Text('RECEIVE')),
              DropdownMenuItem(value: 'ISSUE', child: Text('ISSUE')),
              DropdownMenuItem(value: 'ADJUST', child: Text('ADJUST')),
            ],
            onChanged: (v) => setState(() => _txnType = v ?? _txnType),
            decoration: InputDecoration(labelText: t.transactionType, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: t.quantity, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final qty = double.tryParse(_qty.text.trim()) ?? 0;
              if (qty <= 0) return;
              final now = DateTime.now();
              final dateText = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
              await context.read<AppState>().db.createTransaction(
                warehouseCode: _warehouseCode,
                itemCode: _itemCode,
                txnType: _txnType,
                txnDate: dateText,
                qty: qty,
              );
              _qty.clear();
              await _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.save)));
              }
            },
            child: Text(t.save),
          ),
        ],
      ),
    );
  }
}
