import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';

class ShiftDetailScreen extends StatefulWidget {
  const ShiftDetailScreen({super.key, required this.shiftId});
  final String shiftId;

  @override
  State<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends State<ShiftDetailScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic>? _shift;
  String? _error;

  late TabController _tab;

  // Controllers per unit
  final Map<String, TextEditingController> _blow = {};
  final Map<String, TextEditingController> _filling = {};
  final Map<String, TextEditingController> _label = {};
  final Map<String, TextEditingController> _shrink = {};
  final Map<String, TextEditingController> _diesel = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [..._blow.values, ..._filling.values, ..._label.values, ..._shrink.values, ..._diesel.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final appState = context.read<AppState>();
      final data = await appState.api.getShift(widget.shiftId);
      _shift = data;
      _bindControllersFromShift();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  void _bindControllersFromShift() {
    final blow = (_shift?['blow'] as Map?)?.cast<String, dynamic>() ?? {};
    final filling = (_shift?['filling'] as Map?)?.cast<String, dynamic>() ?? {};
    final label = (_shift?['label'] as Map?)?.cast<String, dynamic>() ?? {};
    final shrink = (_shift?['shrink'] as Map?)?.cast<String, dynamic>() ?? {};
    final diesel = (_shift?['diesel'] as Map?)?.cast<String, dynamic>() ?? {};

    void bind(Map<String, TextEditingController> target, Map<String, dynamic> src, List<String> keys) {
      for (final k in keys) {
        target.putIfAbsent(k, () => TextEditingController());
        target[k]!.text = (src[k] ?? '').toString();
      }
    }

    bind(_blow, blow, [
      'preforms_per_carton',
      'prev_cartons','received_cartons','next_cartons','product_cartons',
      'waste_preforms_pcs','waste_scrap_pcs','waste_bottles_pcs',
      'counter_value',
      'stock075_issued','stock075_received','stock15_issued','stock15_received'
    ]);

    bind(_filling, filling, [
      'caps_per_carton',
      'prev_cartons','received_cartons','next_cartons',
      'waste_caps_pcs','waste_scrap_pcs','waste_bottles_pcs',
      'counter_value',
      'stock_issued','stock_received'
    ]);

    bind(_label, label, [
      'labels_per_roll',
      'prev_rolls','received_rolls','next_rolls',
      'waste_grams',
      'stock075_issued','stock075_received','stock15_issued','stock15_received'
    ]);

    bind(_shrink, shrink, [
      'kg_per_roll','kg_per_carton',
      'prev_rolls','received_rolls','next_rolls',
      'waste_kg','screen_counter',
      'stock075_issued','stock075_received','stock15_issued','stock15_received'
    ]);

    bind(_diesel, diesel, [
      'generator1_total_reading','generator1_consumed',
      'generator2_total_reading','generator2_consumed',
      'main_tank_received'
    ]);
  }

  num? _numOrNull(String s) {
    final v = s.trim();
    if (v.isEmpty) return null;
    return num.tryParse(v);
  }

  int? _intOrNull(String s) {
    final v = s.trim();
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  Future<void> _saveUnit(String unit) async {
    final appState = context.read<AppState>();
    final t = AppLocalizations.of(context)!;

    try {
      Map<String, dynamic> payload = {};
      if (unit == 'blow') {
        payload = {
          'preforms_per_carton': _intOrNull(_blow['preforms_per_carton']!.text) ?? 1248,
          'prev_cartons': _numOrNull(_blow['prev_cartons']!.text),
          'received_cartons': _numOrNull(_blow['received_cartons']!.text),
          'next_cartons': _numOrNull(_blow['next_cartons']!.text),
          'product_cartons': _numOrNull(_blow['product_cartons']!.text),
          'waste_preforms_pcs': _intOrNull(_blow['waste_preforms_pcs']!.text),
          'waste_scrap_pcs': _intOrNull(_blow['waste_scrap_pcs']!.text),
          'waste_bottles_pcs': _intOrNull(_blow['waste_bottles_pcs']!.text),
          'counter_value': _intOrNull(_blow['counter_value']!.text),
          'stock075_issued': _numOrNull(_blow['stock075_issued']!.text),
          'stock075_received': _numOrNull(_blow['stock075_received']!.text),
          'stock15_issued': _numOrNull(_blow['stock15_issued']!.text),
          'stock15_received': _numOrNull(_blow['stock15_received']!.text),
        };
      } else if (unit == 'filling') {
        payload = {
          'caps_per_carton': _intOrNull(_filling['caps_per_carton']!.text) ?? 5500,
          'prev_cartons': _numOrNull(_filling['prev_cartons']!.text),
          'received_cartons': _numOrNull(_filling['received_cartons']!.text),
          'next_cartons': _numOrNull(_filling['next_cartons']!.text),
          'waste_caps_pcs': _intOrNull(_filling['waste_caps_pcs']!.text),
          'waste_scrap_pcs': _intOrNull(_filling['waste_scrap_pcs']!.text),
          'waste_bottles_pcs': _intOrNull(_filling['waste_bottles_pcs']!.text),
          'counter_value': _intOrNull(_filling['counter_value']!.text),
          'stock_issued': _numOrNull(_filling['stock_issued']!.text),
          'stock_received': _numOrNull(_filling['stock_received']!.text),
        };
      } else if (unit == 'label') {
        payload = {
          'labels_per_roll': _intOrNull(_label['labels_per_roll']!.text) ?? 23000,
          'prev_rolls': _numOrNull(_label['prev_rolls']!.text),
          'received_rolls': _numOrNull(_label['received_rolls']!.text),
          'next_rolls': _numOrNull(_label['next_rolls']!.text),
          'waste_grams': _numOrNull(_label['waste_grams']!.text),
          'stock075_issued': _numOrNull(_label['stock075_issued']!.text),
          'stock075_received': _numOrNull(_label['stock075_received']!.text),
          'stock15_issued': _numOrNull(_label['stock15_issued']!.text),
          'stock15_received': _numOrNull(_label['stock15_received']!.text),
        };
      } else if (unit == 'shrink') {
        payload = {
          'kg_per_roll': _numOrNull(_shrink['kg_per_roll']!.text) ?? 25,
          'kg_per_carton': _numOrNull(_shrink['kg_per_carton']!.text) ?? 0.055,
          'prev_rolls': _numOrNull(_shrink['prev_rolls']!.text),
          'received_rolls': _numOrNull(_shrink['received_rolls']!.text),
          'next_rolls': _numOrNull(_shrink['next_rolls']!.text),
          'waste_kg': _numOrNull(_shrink['waste_kg']!.text),
          'screen_counter': _intOrNull(_shrink['screen_counter']!.text),
          'stock075_issued': _numOrNull(_shrink['stock075_issued']!.text),
          'stock075_received': _numOrNull(_shrink['stock075_received']!.text),
          'stock15_issued': _numOrNull(_shrink['stock15_issued']!.text),
          'stock15_received': _numOrNull(_shrink['stock15_received']!.text),
        };
      } else if (unit == 'diesel') {
        payload = {
          'generator1_total_reading': _numOrNull(_diesel['generator1_total_reading']!.text),
          'generator1_consumed': _numOrNull(_diesel['generator1_consumed']!.text),
          'generator2_total_reading': _numOrNull(_diesel['generator2_total_reading']!.text),
          'generator2_consumed': _numOrNull(_diesel['generator2_consumed']!.text),
          'main_tank_received': _numOrNull(_diesel['main_tank_received']!.text),
        };
      }

      final updated = await appState.api.updateUnit(widget.shiftId, unit, payload);
      setState(() {
        _shift = updated;
      });
      _bindControllersFromShift();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.save)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _submit() async {
    final appState = context.read<AppState>();
    final t = AppLocalizations.of(context)!;
    try {
      final updated = await appState.api.submitShift(widget.shiftId);
      setState(() => _shift = updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.submit)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _approve() async {
    final appState = context.read<AppState>();
    final t = AppLocalizations.of(context)!;
    try {
      final updated = await appState.api.approveShift(widget.shiftId);
      setState(() => _shift = updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.approve)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _lock() async {
    final appState = context.read<AppState>();
    final t = AppLocalizations.of(context)!;
    try {
      final updated = await appState.api.lockShift(widget.shiftId);
      setState(() => _shift = updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.lock)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(appBar: AppBar(title: Text(t.shifts)), body: Center(child: Text(_error!)));
    }

    final shift = _shift!;
    final status = (shift['status'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('${shift['report_date']} • ${t.shiftCode}: ${shift['shift_code']}'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: [
            Tab(text: t.unitBlow),
            Tab(text: t.unitFilling),
            Tab(text: t.unitLabel),
            Tab(text: t.unitShrink),
            Tab(text: t.unitDiesel),
            Tab(text: t.unitSummary),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'submit') await _submit();
              if (v == 'approve') await _approve();
              if (v == 'lock') await _lock();
              if (v == 'refresh') await _load();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'refresh', child: Text(t.refresh)),
              PopupMenuItem(value: 'submit', child: Text(t.submit)),
              if (appState.hasRole('supervisor') || appState.hasRole('admin'))
                PopupMenuItem(value: 'approve', child: Text(t.approve)),
              if (appState.hasRole('supervisor') || appState.hasRole('admin'))
                PopupMenuItem(value: 'lock', child: Text(t.lock)),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _unitForm(
            title: t.unitBlow,
            unitCode: 'blow',
            controllers: _blow,
            fields: [
              _Field('preforms_per_carton', t.preformsPerCarton, keyboard: TextInputType.number),
              _Field('prev_cartons', '${t.prev} (${t.cartons})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('received_cartons', '${t.received} (${t.cartons})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('next_cartons', '${t.next} (${t.cartons})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('product_cartons', '${t.product} (${t.cartons})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('waste_preforms_pcs', '${t.waste} - ${t.pcs}', keyboard: TextInputType.number),
              _Field('waste_scrap_pcs', 'Scrap (${t.pcs})', keyboard: TextInputType.number),
              _Field('waste_bottles_pcs', 'Bottles (${t.pcs})', keyboard: TextInputType.number),
              _Field('counter_value', t.counter, keyboard: TextInputType.number),
            ],
            onSave: () => _saveUnit('blow'),
            computed: (shift['computed']?['blow'] as Map?)?.cast<String, dynamic>(),
          ),
          _unitForm(
            title: t.unitFilling,
            unitCode: 'filling',
            controllers: _filling,
            fields: [
              _Field('caps_per_carton', t.capsPerCarton, keyboard: TextInputType.number),
              _Field('prev_cartons', '${t.prev} (${t.cartons})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('received_cartons', '${t.received} (${t.cartons})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('next_cartons', '${t.next} (${t.cartons})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('waste_caps_pcs', '${t.waste} - Caps (${t.pcs})', keyboard: TextInputType.number),
              _Field('waste_scrap_pcs', 'Scrap (${t.pcs})', keyboard: TextInputType.number),
              _Field('waste_bottles_pcs', 'Bottles (${t.pcs})', keyboard: TextInputType.number),
              _Field('counter_value', t.counter, keyboard: TextInputType.number),
            ],
            onSave: () => _saveUnit('filling'),
            computed: (shift['computed']?['filling'] as Map?)?.cast<String, dynamic>(),
          ),
          _unitForm(
            title: t.unitLabel,
            unitCode: 'label',
            controllers: _label,
            fields: [
              _Field('labels_per_roll', t.labelsPerRoll, keyboard: TextInputType.number),
              _Field('prev_rolls', '${t.prev} (${t.rolls})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('received_rolls', '${t.received} (${t.rolls})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('next_rolls', '${t.next} (${t.rolls})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('waste_grams', '${t.waste} (${t.grams})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
            ],
            onSave: () => _saveUnit('label'),
            computed: (shift['computed']?['label'] as Map?)?.cast<String, dynamic>(),
          ),
          _unitForm(
            title: t.unitShrink,
            unitCode: 'shrink',
            controllers: _shrink,
            fields: [
              _Field('kg_per_roll', t.kgPerRoll, keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('kg_per_carton', t.kgPerCarton, keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('prev_rolls', '${t.prev} (${t.rolls})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('received_rolls', '${t.received} (${t.rolls})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('next_rolls', '${t.next} (${t.rolls})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('waste_kg', '${t.waste} (${t.kg})', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('screen_counter', t.counter, keyboard: TextInputType.number),
            ],
            onSave: () => _saveUnit('shrink'),
            computed: (shift['computed']?['shrink'] as Map?)?.cast<String, dynamic>(),
          ),
          _unitForm(
            title: t.unitDiesel,
            unitCode: 'diesel',
            controllers: _diesel,
            fields: [
              _Field('generator1_total_reading', '${t.generator1} - ${t.totalReading}', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('generator1_consumed', '${t.generator1} - ${t.consumedLiters}', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('generator2_total_reading', '${t.generator2} - ${t.totalReading}', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('generator2_consumed', '${t.generator2} - ${t.consumedLiters}', keyboard: const TextInputType.numberWithOptions(decimal: true)),
              _Field('main_tank_received', t.mainTankReceived, keyboard: const TextInputType.numberWithOptions(decimal: true)),
            ],
            onSave: () => _saveUnit('diesel'),
            computed: (shift['computed']?['diesel'] as Map?)?.cast<String, dynamic>(),
          ),
          _summaryTab(shift),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        child: Text('${t.status}: $status', textAlign: TextAlign.center),
      ),
    );
  }

  Widget _unitForm({
    required String title,
    required String unitCode,
    required Map<String, TextEditingController> controllers,
    required List<_Field> fields,
    required VoidCallback onSave,
    Map<String, dynamic>? computed,
  }) {
    final t = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    final canEdit = appState.canEditUnit(unitCode);
    final computedWidgets = <Widget>[];
    if (computed != null && computed.isNotEmpty) {
      computedWidgets.addAll([
        const SizedBox(height: 12),
        Text(t.summary, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _kv('Consumed', computed['consumed_cartons'] ?? computed['consumed_rolls'] ?? computed['consumed_kg']),
        _kv('Variance', computed['variance_cartons'] ?? computed['variance_rolls'] ?? computed['variance_kg']),
        _kv(t.wastePercent, computed['waste_pct']),
        _kv(t.shortagePercent, computed['shortage_pct']),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
              FilledButton.icon(
                onPressed: canEdit ? onSave : null,
                icon: const Icon(Icons.save_outlined),
                label: Text(t.save),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!canEdit) Text(t.permissionDenied, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          ...fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: controllers[f.key],
                  enabled: canEdit,
                  keyboardType: f.keyboard,
                  decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()),
                ),
              )),
          ...computedWidgets,
        ],
      ),
    );
  }

  Widget _summaryTab(Map<String, dynamic> shift) {
    final t = AppLocalizations.of(context)!;
    final computed = (shift['computed']?['summary'] as Map?)?.cast<String, dynamic>() ?? {};

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Text(t.unitSummary, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _kv('Blow consumed cartons', computed['blow_consumed_cartons']),
          _kv('Blow consumed preforms', computed['blow_consumed_preforms']),
          _kv('Filling consumed cartons', computed['filling_consumed_cartons']),
          _kv('Filling consumed caps', computed['filling_consumed_caps']),
          _kv('Label consumed rolls', computed['label_consumed_rolls']),
          _kv('Label consumed labels', computed['label_consumed_labels']),
          _kv('Shrink consumed rolls', computed['shrink_consumed_rolls']),
          _kv('Shrink consumed kg', computed['shrink_consumed_kg']),
          _kv('Shrink bottles equivalent', computed['shrink_bottles_equivalent']),
        ],
      ),
    );
  }

  Widget _kv(String k, dynamic v) {
    String text;
    if (v == null) {
      text = '-';
    } else if (v is num) {
      text = v.toStringAsFixed(3);
    } else {
      text = v.toString();
    }
    return ListTile(
      title: Text(k),
      trailing: Text(text),
    );
  }
}

class _Field {
  _Field(this.key, this.label, {required this.keyboard});
  final String key;
  final String label;
  final TextInputType keyboard;
}
