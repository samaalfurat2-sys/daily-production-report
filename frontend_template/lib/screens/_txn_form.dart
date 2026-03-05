/// Shared transaction form widget used by all warehouse screens.
/// Supports simple RECEIVE / ISSUE / ADJUST and transfer pairs.
/// v2.5: offline-first — on network failure the payload is enqueued
/// via SyncService and auto-flushed when connectivity returns.
library;

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/api_client.dart';
import '../services/sync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Simple transaction (RECEIVE / ISSUE / ADJUST)
// ─────────────────────────────────────────────────────────────────────────────

class TxnForm extends StatefulWidget {
  const TxnForm({
    super.key,
    required this.api,
    required this.warehouseCode,
    required this.fixedTxnType,
    required this.title,
    this.fixedItemCode,
    this.noteHint,
    this.showInvoiceRef = false,
  });

  final ApiClient api;
  final String warehouseCode;
  final String fixedTxnType;
  final String title;
  final String? fixedItemCode;
  final String? noteHint;
  final bool showInvoiceRef;

  @override
  State<TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends State<TxnForm> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _items = [];
  String? _selectedItemCode;
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    if (widget.fixedItemCode == null) _loadItems();
    _selectedItemCode = widget.fixedItemCode;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final list = await widget.api.listItems();
      if (mounted) {
        setState(() {
          _items = list.cast<Map<String, dynamic>>();
          if (_items.isNotEmpty) _selectedItemCode = _items.first['code'] as String;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // true when the last save went to the offline queue instead of the server
  bool _savedOffline = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItemCode == null) return;
    setState(() { _loading = true; _error = null; _success = false; _savedOffline = false; });

    final payload = <String, dynamic>{
      'warehouse_code': widget.warehouseCode,
      'item_code': _selectedItemCode!,
      'txn_type': widget.fixedTxnType,
      'txn_date': _date.toIso8601String().substring(0, 10),
      'qty': double.parse(_qtyCtrl.text.trim()),
      if ((_noteCtrl.text.trim()).isNotEmpty) 'note': _noteCtrl.text.trim(),
    };

    try {
      // ── Try the live API first ──────────────────────────────────────────
      await widget.api.createTransaction(
        warehouseCode: widget.warehouseCode,
        itemCode: _selectedItemCode!,
        txnType: widget.fixedTxnType,
        txnDate: payload['txn_date'] as String,
        qty: payload['qty'] as double,
        note: payload['note'] as String?,
      );
      if (mounted) setState(() { _success = true; _qtyCtrl.clear(); _noteCtrl.clear(); });
    } catch (_) {
      // ── Network / server error → fall back to offline queue ────────────
      try {
        await SyncService.instance.enqueueTransaction(payload);
        if (mounted) setState(() { _savedOffline = true; _qtyCtrl.clear(); _noteCtrl.clear(); });
      } catch (eq) {
        if (mounted) setState(() => _error = eq.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(t.date),
              subtitle: Text(_date.toIso8601String().substring(0, 10)),
              onTap: _pickDate,
            ),
            const Divider(),

            // Item selector (hidden when fixedItemCode is set)
            if (widget.fixedItemCode == null) ...[
              DropdownButtonFormField<String>(
                value: _selectedItemCode,
                decoration: InputDecoration(labelText: t.item),
                items: _items
                    .map((it) => DropdownMenuItem<String>(
                          value: it['code'] as String,
                          child: Text('${it['code']} – ${it['name_ar']}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedItemCode = v),
                validator: (v) => v == null ? t.item : null,
              ),
              const SizedBox(height: 12),
            ],

            // Quantity
            TextFormField(
              controller: _qtyCtrl,
              decoration: InputDecoration(
                labelText: t.quantity,
                suffixText: 'وحدة',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return t.quantity;
                if (double.tryParse(v.trim()) == null) return '!';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Note / Invoice ref
            TextFormField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: widget.showInvoiceRef ? t.invoiceRef : (t.notes),
                hintText: widget.noteHint,
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_success)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(t.success, style: const TextStyle(color: Colors.green)),
              ),
            if (_savedOffline)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t.savedOffline, style: const TextStyle(color: Colors.orange))),
                ]),
              ),

            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(t.save),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transfer form (TRANSFER_OUT + TRANSFER_IN pair)
// ─────────────────────────────────────────────────────────────────────────────

class TransferForm extends StatefulWidget {
  const TransferForm({
    super.key,
    required this.api,
    required this.sourceWarehouseCode,
    required this.targetWarehouseCode,
    required this.title,
  });

  final ApiClient api;
  final String sourceWarehouseCode;
  final String targetWarehouseCode;
  final String title;

  @override
  State<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<TransferForm> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _items = [];
  String? _selectedItemCode;
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final list = await widget.api.listItems();
      if (mounted) {
        setState(() {
          _items = list.cast<Map<String, dynamic>>();
          if (_items.isNotEmpty) _selectedItemCode = _items.first['code'] as String;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool _savedOffline = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItemCode == null) return;
    setState(() { _loading = true; _error = null; _success = false; _savedOffline = false; });

    final txnDate = _date.toIso8601String().substring(0, 10);
    final qty = double.parse(_qtyCtrl.text.trim());
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    try {
      // ── Try live API first ──────────────────────────────────────────────
      await widget.api.createTransfer(
        sourceWarehouseCode: widget.sourceWarehouseCode,
        targetWarehouseCode: widget.targetWarehouseCode,
        itemCode: _selectedItemCode!,
        txnDate: txnDate,
        qty: qty,
        note: note,
      );
      if (mounted) setState(() { _success = true; _qtyCtrl.clear(); _noteCtrl.clear(); });
    } catch (_) {
      // ── Offline: enqueue as two legs (OUT + IN) ─────────────────────────
      // The batch endpoint handles individual InventoryTxnCreate objects, so
      // we store each leg separately; server-side pairing happens on flush.
      try {
        await SyncService.instance.enqueueTransaction({
          'warehouse_code': widget.sourceWarehouseCode,
          'item_code': _selectedItemCode!,
          'txn_type': 'TRANSFER_OUT',
          'txn_date': txnDate,
          'qty': qty,
          if (note != null) 'note': note,
        });
        await SyncService.instance.enqueueTransaction({
          'warehouse_code': widget.targetWarehouseCode,
          'item_code': _selectedItemCode!,
          'txn_type': 'TRANSFER_IN',
          'txn_date': txnDate,
          'qty': qty,
          if (note != null) 'note': note,
        });
        if (mounted) setState(() { _savedOffline = true; _qtyCtrl.clear(); _noteCtrl.clear(); });
      } catch (eq) {
        if (mounted) setState(() => _error = eq.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Source → Target indicator
            Card(
              child: ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text('${widget.sourceWarehouseCode} → ${widget.targetWarehouseCode}'),
                subtitle: Text('${t.sourceWarehouse}: ${widget.sourceWarehouseCode}  |  ${t.targetWarehouse}: ${widget.targetWarehouseCode}'),
              ),
            ),
            const SizedBox(height: 8),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(t.date),
              subtitle: Text(_date.toIso8601String().substring(0, 10)),
              onTap: _pickDate,
            ),
            const Divider(),

            DropdownButtonFormField<String>(
              value: _selectedItemCode,
              decoration: InputDecoration(labelText: t.item),
              items: _items
                  .map((it) => DropdownMenuItem<String>(
                        value: it['code'] as String,
                        child: Text('${it['code']} – ${it['name_ar']}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedItemCode = v),
              validator: (v) => v == null ? t.item : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _qtyCtrl,
              decoration: InputDecoration(labelText: t.transferQty),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return t.quantity;
                if (double.tryParse(v.trim()) == null) return '!';
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _noteCtrl,
              decoration: InputDecoration(labelText: t.notes),
            ),
            const SizedBox(height: 20),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_success)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(t.success, style: const TextStyle(color: Colors.green)),
              ),
            if (_savedOffline)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t.savedOffline, style: const TextStyle(color: Colors.orange))),
                ]),
              ),

            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.swap_horiz_outlined),
              label: Text(widget.title),
            ),
          ],
        ),
      ),
    );
  }
}
