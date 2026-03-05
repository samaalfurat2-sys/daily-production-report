import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '_txn_form.dart';
import '_txn_list.dart';

/// أمين مخزن المحروقات
/// Operations:
///   - RECEIVE diesel into FUEL warehouse
///   - ISSUE diesel to Generator 1 per shift
///   - ISSUE diesel to Generator 2 per shift
class FuelWarehouseScreen extends StatefulWidget {
  const FuelWarehouseScreen({super.key});
  @override
  State<FuelWarehouseScreen> createState() => _FuelWarehouseScreenState();
}

class _FuelWarehouseScreenState extends State<FuelWarehouseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final appState = context.read<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(t.fuelWarehouse),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(icon: const Icon(Icons.download_outlined),          text: t.receiveFuel),
            Tab(icon: const Icon(Icons.electric_bolt_outlined),     text: '${t.issueFuel} – ${t.generator1}'),
            Tab(icon: const Icon(Icons.electric_bolt_outlined),     text: '${t.issueFuel} – ${t.generator2}'),
            Tab(icon: const Icon(Icons.list_alt_outlined),          text: t.transactions),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Tab 1: Receive diesel ────────────────────────────────────────
          TxnForm(
            api: appState.api,
            warehouseCode: 'FUEL',
            fixedTxnType: 'RECEIVE',
            fixedItemCode: 'FUEL_DIESEL_LITER',
            title: t.receiveFuel,
          ),
          // ── Tab 2: Issue to Generator 1 ──────────────────────────────────
          TxnForm(
            api: appState.api,
            warehouseCode: 'FUEL',
            fixedTxnType: 'ISSUE',
            fixedItemCode: 'FUEL_DIESEL_LITER',
            title: '${t.issueFuel} – ${t.generator1}',
            noteHint: t.generator1,
          ),
          // ── Tab 3: Issue to Generator 2 ──────────────────────────────────
          TxnForm(
            api: appState.api,
            warehouseCode: 'FUEL',
            fixedTxnType: 'ISSUE',
            fixedItemCode: 'FUEL_DIESEL_LITER',
            title: '${t.issueFuel} – ${t.generator2}',
            noteHint: t.generator2,
          ),
          // ── Tab 4: Transaction list ──────────────────────────────────────
          TxnList(api: appState.api, warehouseCode: 'FUEL'),
        ],
          ),
    );
  }
}
