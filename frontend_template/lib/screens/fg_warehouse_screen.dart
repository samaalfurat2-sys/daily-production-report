import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '_txn_form.dart';
import '_txn_list.dart';

/// أمين مخزن المنتج الجاهز
/// Operations: RECEIVE finished goods (from PROD) | ISSUE per invoice
class FgWarehouseScreen extends StatefulWidget {
  const FgWarehouseScreen({super.key});
  @override
  State<FgWarehouseScreen> createState() => _FgWarehouseScreenState();
}

class _FgWarehouseScreenState extends State<FgWarehouseScreen>
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
        title: Text(t.fgWarehouse),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(icon: const Icon(Icons.download_outlined),   text: t.receiveFinished),
            Tab(icon: const Icon(Icons.upload_outlined),      text: t.issueGoods),
            Tab(icon: const Icon(Icons.list_alt_outlined),    text: t.transactions),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Tab 1: Receive FG from production ────────────────────────────
          TxnForm(
            api: appState.api,
            warehouseCode: 'FG',
            fixedTxnType: 'RECEIVE',
            title: t.receiveFinished,
          ),
          // ── Tab 2: Issue finished goods per invoice ──────────────────────
          TxnForm(
            api: appState.api,
            warehouseCode: 'FG',
            fixedTxnType: 'ISSUE',
            title: t.issueGoods,
            showInvoiceRef: true,
          ),
          // ── Tab 3: Transaction list ──────────────────────────────────────
          TxnList(api: appState.api, warehouseCode: 'FG'),
        ],
          ),
    );
  }
}
