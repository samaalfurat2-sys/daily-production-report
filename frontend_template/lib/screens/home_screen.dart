import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'dashboard_screen.dart';
import 'shift_list_screen.dart';
import 'approvals_screen.dart';
import 'warehouse_screen.dart';
import 'settings_screen.dart';
import 'onedrive_sync_screen.dart';
import 'onedrive_sync_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();

    final isAdminOrSupervisor =
        appState.hasRole('supervisor') || appState.hasRole('admin');

    final tabs = <Widget>[
      const DashboardScreen(),
      const ShiftListScreen(),
      if (isAdminOrSupervisor) const ApprovalsScreen(),
      if (appState.canSeeWarehouse) const WarehouseScreen(),
      if (isAdminOrSupervisor) const OneDriveSyncScreen(),
      const SettingsScreen(),
      if (appState.hasRole('admin') || appState.hasRole('supervisor')) const OneDriveSyncScreen(),
    ];

    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
          icon: const Icon(Icons.dashboard_outlined), label: t.dashboard),
      BottomNavigationBarItem(
          icon: const Icon(Icons.fact_check_outlined), label: t.shifts),
      if (isAdminOrSupervisor)
        BottomNavigationBarItem(
            icon: const Icon(Icons.verified_outlined), label: t.approvals),
      if (appState.canSeeWarehouse)
        BottomNavigationBarItem(
            icon: const Icon(Icons.warehouse_outlined), label: t.warehouses),
      if (isAdminOrSupervisor)
        BottomNavigationBarItem(
            icon: const Icon(Icons.cloud_sync_outlined), label: t.oneDrive),
      BottomNavigationBarItem(
          icon: const Icon(Icons.settings_outlined), label: t.settings),
    ];

    if (_index >= tabs.length) _index = 0;

    return Scaffold(
      body: SafeArea(child: tabs[_index]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: items,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
