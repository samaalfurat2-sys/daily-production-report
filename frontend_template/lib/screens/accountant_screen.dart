import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '_txn_list.dart';

/// محاسب المخازن
/// Sees all PENDING transactions → acknowledges them.
/// Also views ACKNOWLEDGED and production shift reports.
class AccountantScreen extends StatefulWidget {
  const AccountantScreen({super.key});
  @override
  State<AccountantScreen> createState() => _AccountantScreenState();
}

class _AccountantScreenState extends State<AccountantScreen>
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

    Future<void> ack(String txnId) async {
      await appState.api.acknowledgeTransaction(txnId);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.accountantDashboard),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(icon: const Icon(Icons.pending_actions_outlined), text: t.pendingTransactions),
            Tab(icon: const Icon(Icons.check_circle_outline),     text: t.acknowledgedTransactions),
            Tab(icon: const Icon(Icons.list_alt_outlined),        text: t.allOperations),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Tab 1: PENDING – accountant can acknowledge
          TxnList(
            api: appState.api,
            filterStatus: 'PENDING',
            showActions: true,
            onAcknowledge: ack,
          ),
          // Tab 2: ACKNOWLEDGED
          TxnList(
            api: appState.api,
            filterStatus: 'ACKNOWLEDGED',
          ),
          // Tab 3: All transactions
          TxnList(api: appState.api),
        ],
          ),
    );
  }
}
