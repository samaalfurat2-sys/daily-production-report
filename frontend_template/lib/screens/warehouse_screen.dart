import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/sync_service.dart';
import '../services/local_db.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;
  List<dynamic> _warehouses = [];
  List<dynamic> _stock = [];
  List<dynamic> _transactions = [];
  List<dynamic> _items = [];
  String? _error;

  // ── Create-transaction form state ─────────────────────────────────────────
  final _qty = TextEditingController();
  String _warehouseCode = 'RM';
  String _itemCode = 'RM_PREFORM_CARTON';
  String _txnType = 'RECEIVE';
  bool _submitting = false;
  String? _submitError;
  bool _savedOffline = false;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AppState>().api;
      final results = await Future.wait([
        api.listWarehouses(),
        api.listStock(),
        api.listTransactions(),
        api.listItems(),
      ]);
      _warehouses = results[0];
      _stock = results[1];
      _transactions = results[2];
      _items = results[3];
      if (_warehouses.isNotEmpty) {
        _warehouseCode =
            (_warehouses.first as Map<String, dynamic>)['code'].toString();
      }
      if (_items.isNotEmpty) {
        _itemCode =
            (_items.first as Map<String, dynamic>)['code'].toString();
      }
    } catch (e) {
      // Offline fallback — serve cached transactions from SQLite
      try {
        final cachedTxns = await LocalDb.instance.getCachedTxns();
        if (cachedTxns.isNotEmpty) {
          _transactions = cachedTxns;
          // Keep warehouses/stock/items empty if network failed
        } else {
          _error = e.toString();
        }
      } catch (_) {
        _error = e.toString();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _label(Map<String, dynamic> row, BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return isAr ? row['name_ar'].toString() : row['name_en'].toString();
  }

  Future<void> _submitTxn() async {
    final qty = double.tryParse(_qty.text.trim()) ?? 0;
    if (qty <= 0) return;

    setState(() {
      _submitting = true;
      _submitError = null;
      _savedOffline = false;
    });

    final now = DateTime.now();
    final dateText =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final appState = context.read<AppState>();
    final sync = SyncService.instance;

    try {
      await appState.api.createInventoryTransaction(
        warehouseCode: _warehouseCode,
        itemCode: _itemCode,
        txnType: _txnType,
        txnDate: dateText,
        qty: qty,
      );
      _qty.clear();
      await _load();
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.save)));
      }
    } catch (_) {
      // Offline: enqueue for background flush
      await sync.enqueueTransaction({
        'warehouse_code': _warehouseCode,
        'item_code': _itemCode,
        'txn_type': _txnType,
        'txn_date': dateText,
        'qty': qty,
      });
      _qty.clear();
      if (mounted) setState(() => _savedOffline = true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _stock.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final row = _stock[i] as Map<String, dynamic>;
          final name = Localizations.localeOf(context).languageCode == 'ar'
              ? row['item_name_ar']
              : row['item_name_en'];
          return ListTile(
            title: Text('${row['warehouse_code']} • $name'),
            subtitle: Text('${row['item_code']} • ${row['uom']}'),
            trailing: Text(row['qty_on_hand'].toString()),
          );
        },
      ),
    );
  }

  Widget _transactionsTab(AppLocalizations t) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final row = _transactions[i] as Map<String, dynamic>;
          final name = Localizations.localeOf(context).languageCode == 'ar'
              ? row['item_name_ar']
              : row['item_name_en'];
          return ListTile(
            title: Text(
                '${row['txn_date']} • ${row['warehouse_code']} • $name'),
            subtitle:
                Text('${row['txn_type']} • ${row['note'] ?? ''}'),
            trailing: Text(row['qty'].toString()),
          );
        },
      ),
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
              return DropdownMenuItem(
                value: m['code'].toString(),
                child: Text('${m['code']} • ${_label(m, context)}'),
              );
            }).toList(),
            onChanged: (v) =>
                setState(() => _warehouseCode = v ?? _warehouseCode),
            decoration: InputDecoration(
              labelText: t.warehouse,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _itemCode,
            items: _items.map((e) {
              final m = e as Map<String, dynamic>;
              final isAr =
                  Localizations.localeOf(context).languageCode == 'ar';
              final label = isAr
                  ? m['name_ar'].toString()
                  : m['name_en'].toString();
              return DropdownMenuItem(
                value: m['code'].toString(),
                child: Text('${m['code']} • $label'),
              );
            }).toList(),
            onChanged: (v) =>
                setState(() => _itemCode = v ?? _itemCode),
            decoration: InputDecoration(
              labelText: t.item,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _txnType,
            items: const [
              DropdownMenuItem(value: 'RECEIVE', child: Text('RECEIVE')),
              DropdownMenuItem(value: 'ISSUE', child: Text('ISSUE')),
              DropdownMenuItem(value: 'ADJUST', child: Text('ADJUST')),
            ],
            onChanged: (v) =>
                setState(() => _txnType = v ?? _txnType),
            decoration: InputDecoration(
              labelText: t.transactionType,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qty,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: t.quantity,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // ── Feedback row ────────────────────────────────────────────────
          if (_submitError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_submitError!,
                  style: const TextStyle(color: Colors.red)),
            ),
          if (_savedOffline)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.cloud_off, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Text(t.savedOffline,
                    style: const TextStyle(color: Colors.orange)),
              ]),
            ),
          // ── Submit button ────────────────────────────────────────────────
          FilledButton(
            onPressed: _submitting ? null : _submitTxn,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.save),
          ),
        ],
      ),
    );
  }
}
