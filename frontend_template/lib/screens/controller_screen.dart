import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '_txn_list.dart';
import 'approvals_screen.dart';

/// مراقب الحسابات
/// - Posts ACKNOWLEDGED warehouse transactions → POSTED
/// - Approves / Locks production shift reports
class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});
  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen>
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

    Future<void> postTxn(String txnId) async {
      await appState.api.postTransaction(txnId);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.controllerDashboard),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(icon: const Icon(Icons.fact_check_outlined),  text: t.approvals),
            Tab(icon: const Icon(Icons.post_add_outlined),    text: t.acknowledgedTransactions),
            Tab(icon: const Icon(Icons.done_all_outlined),    text: t.postedTransactions),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Tab 1: Approve / lock production shifts
          const ApprovalsScreen(),
          // Tab 2: ACKNOWLEDGED transactions → can post
          TxnList(
            api: appState.api,
            filterStatus: 'ACKNOWLEDGED',
            showActions: true,
            onPost: postTxn,
          ),
          // Tab 3: POSTED transactions (read-only)
          TxnList(
            api: appState.api,
            filterStatus: 'POSTED',
          ),
        ],
          ),
    );
  }
}
