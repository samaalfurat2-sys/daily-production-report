import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '_txn_list.dart';
import 'shift_list_screen.dart';
import 'warehouse_screen.dart';

/// المدير العام + مدقق الحسابات
/// Read-only view of ALL operations: shifts, all warehouse transactions by status.
/// Auditor: same view, cannot approve/post anything (backend enforces this).
class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});
  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen>
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
    final appState = context.watch<AppState>();
    final isAuditor = appState.isAuditor;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAuditor ? t.auditorDashboard : t.managerDashboard),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(icon: const Icon(Icons.fact_check_outlined),  text: t.shiftReports),
            Tab(icon: const Icon(Icons.warehouse_outlined),    text: t.warehouses),
            Tab(icon: const Icon(Icons.pending_actions_outlined), text: t.pendingTransactions),
            Tab(icon: const Icon(Icons.done_all_outlined),     text: t.postedTransactions),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Tab 1: All shift reports (read-only for auditor)
          const ShiftListScreen(embedded: true),
          // Tab 2: Stock on hand + all warehouses
          const WarehouseScreen(),
          // Tab 3: All PENDING transactions
          TxnList(api: appState.api, filterStatus: 'PENDING'),
          // Tab 4: All POSTED transactions
          TxnList(api: appState.api, filterStatus: 'POSTED'),
        ],
          ),
    );
  }
}
