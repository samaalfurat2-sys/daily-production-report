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

    // Build tabs and nav items together to guarantee index alignment
    final tabs = <Widget>[];
    final items = <BottomNavigationBarItem>[];

    // 1. Dashboard — always visible
    tabs.add(const DashboardScreen());
    items.add(BottomNavigationBarItem(
        icon: const Icon(Icons.dashboard_outlined), label: t.dashboard));

    // 2. Shifts — always visible
    tabs.add(const ShiftListScreen());
    items.add(BottomNavigationBarItem(
        icon: const Icon(Icons.fact_check_outlined), label: t.shifts));

    // 3. Approvals — admin / supervisor only
    if (isAdminOrSupervisor) {
      tabs.add(const ApprovalsScreen());
      items.add(BottomNavigationBarItem(
          icon: const Icon(Icons.verified_outlined), label: t.approvals));
    }

    // 4. Warehouse — roles with warehouse access
    if (appState.canSeeWarehouse) {
      tabs.add(const WarehouseScreen());
      items.add(BottomNavigationBarItem(
          icon: const Icon(Icons.warehouse_outlined), label: t.warehouses));
    }

    // 5. OneDrive — admin / supervisor only
    if (isAdminOrSupervisor) {
      tabs.add(const OneDriveSyncScreen());
      items.add(BottomNavigationBarItem(
          icon: const Icon(Icons.cloud_sync_outlined), label: t.oneDrive));
    }

    // 6. Settings — always visible
    tabs.add(const SettingsScreen());
    items.add(BottomNavigationBarItem(
        icon: const Icon(Icons.settings_outlined), label: t.settings));

    // Guard against stale index after role change
    final safeIndex = _index < tabs.length ? _index : 0;

    return Scaffold(
      body: SafeArea(child: tabs[safeIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (i) => setState(() => _index = i),
        items: items,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
