/// مشرف صالة الإنتاج
/// This screen is a convenience hub for the production supervisor.
/// It wraps three concerns in tabs:
///   1. Shift reports   (reuses ShiftListScreen)
///   2. Transfer PROD → FG   (TransferForm)
///   3. PROD stock on hand
library;

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '_txn_form.dart';
import '_txn_list.dart';
import 'shift_list_screen.dart';

class ProductionSupervisorScreen extends StatefulWidget {
  const ProductionSupervisorScreen({super.key});

  @override
  State<ProductionSupervisorScreen> createState() =>
      _ProductionSupervisorScreenState();
}

class _ProductionSupervisorScreenState
    extends State<ProductionSupervisorScreen>
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
        title: Text(t.productionSupervisorDashboard),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(icon: const Icon(Icons.fact_check_outlined),   text: t.shifts),
            Tab(icon: const Icon(Icons.download_outlined),     text: t.receiveFromRM),
            Tab(icon: const Icon(Icons.swap_horiz_outlined),   text: t.transferToFG),
            Tab(icon: const Icon(Icons.list_alt_outlined),     text: t.transactions),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Tab 1: Shift reports (create + open + submit) ─────────────────
          const ShiftListScreen(embedded: true),

          // ── Tab 2: Receive RM into PROD (from raw warehouse transfer) ─────
          //          (production supervisor may book a RECEIVE in PROD to match
          //           the TRANSFER_IN that the raw keeper created)
          TxnForm(
            api: appState.api,
            warehouseCode: 'PROD',
            fixedTxnType: 'RECEIVE',
            title: t.receiveFromRM,
          ),

          // ── Tab 3: Transfer PROD → FG ─────────────────────────────────────
          TransferForm(
            api: appState.api,
            sourceWarehouseCode: 'PROD',
            targetWarehouseCode: 'FG',
            title: t.transferToFG,
          ),

          // ── Tab 4: PROD transactions ──────────────────────────────────────
          TxnList(api: appState.api, warehouseCode: 'PROD'),
        ],
          ),
    );
  }
}
