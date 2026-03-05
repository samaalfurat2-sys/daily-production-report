import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '_txn_form.dart';
import '_txn_list.dart';

/// أمين مخزن المواد الخام
/// Operations: RECEIVE raw materials | TRANSFER_OUT RM → PROD
class RawWarehouseScreen extends StatefulWidget {
  const RawWarehouseScreen({super.key});
  @override
  State<RawWarehouseScreen> createState() => _RawWarehouseScreenState();
}

class _RawWarehouseScreenState extends State<RawWarehouseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
        title: Text(t.rawWarehouse),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(icon: const Icon(Icons.download_outlined),  text: t.receiveGoods),
            Tab(icon: const Icon(Icons.swap_horiz_outlined), text: t.transferToProduction),
            Tab(icon: const Icon(Icons.list_alt_outlined),   text: t.transactions),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Tab 1: Receive raw materials ─────────────────────────────────
          TxnForm(
            api: appState.api,
            warehouseCode: 'RM',
            fixedTxnType: 'RECEIVE',
            title: t.receiveGoods,
          ),
          // ── Tab 2: Transfer RM → PROD ────────────────────────────────────
          TransferForm(
            api: appState.api,
            sourceWarehouseCode: 'RM',
            targetWarehouseCode: 'PROD',
            title: t.transferToProduction,
          ),
          // ── Tab 3: Transaction list ──────────────────────────────────────
          TxnList(api: appState.api, warehouseCode: 'RM'),
        ],
          ),
    );
  }
}
