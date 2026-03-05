import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'dashboard_screen.dart';
import 'shift_list_screen.dart';
import 'approvals_screen.dart';
import 'warehouse_screen.dart';
import 'settings_screen.dart';
// New role-specific screens
import 'raw_warehouse_screen.dart';
import 'production_supervisor_screen.dart';
import 'fg_warehouse_screen.dart';
import 'fuel_warehouse_screen.dart';
import 'accountant_screen.dart';
import 'controller_screen.dart';
import 'manager_screen.dart';
import '../widgets/sync_status_bar.dart';

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

    // Build role-specific navigation tabs ─────────────────────────────────────
    final tabs = <_NavTab>[];

    // ── ADMIN / GENERAL MANAGER: full dashboard + all tabs ──────────────────
    if (appState.isAdmin || appState.isGeneralManager) {
      tabs.addAll([
        _NavTab(Icons.dashboard_outlined,     t.dashboard,       const DashboardScreen()),
        _NavTab(Icons.fact_check_outlined,    t.shifts,          const ShiftListScreen()),
        _NavTab(Icons.verified_outlined,      t.approvals,       const ApprovalsScreen()),
        _NavTab(Icons.warehouse_outlined,     t.warehouses,      const WarehouseScreen()),
        _NavTab(Icons.assessment_outlined,    t.allOperations,   const ManagerScreen()),
        _NavTab(Icons.settings_outlined,      t.settings,        const SettingsScreen()),
      ]);
    }

    // ── AUDITOR: read-only view of all operations ────────────────────────────
    else if (appState.isAuditor) {
      tabs.addAll([
        _NavTab(Icons.assessment_outlined,    t.auditorDashboard,  const ManagerScreen()),
        _NavTab(Icons.settings_outlined,      t.settings,          const SettingsScreen()),
      ]);
    }

    // ── ACCOUNTS CONTROLLER: approvals + post warehouse transactions ─────────
    else if (appState.isController) {
      tabs.addAll([
        _NavTab(Icons.verified_outlined,      t.approvals,           const ApprovalsScreen()),
        _NavTab(Icons.post_add_outlined,      t.controllerDashboard, const ControllerScreen()),
        _NavTab(Icons.warehouse_outlined,     t.allWarehouses,       const WarehouseScreen()),
        _NavTab(Icons.settings_outlined,      t.settings,            const SettingsScreen()),
      ]);
    }

    // ── WH ACCOUNTANT: acknowledge all pending warehouse transactions ────────
    else if (appState.isWhAccountant) {
      tabs.addAll([
        _NavTab(Icons.pending_actions_outlined, t.accountantDashboard, const AccountantScreen()),
        _NavTab(Icons.warehouse_outlined,       t.allWarehouses,       const WarehouseScreen()),
        _NavTab(Icons.fact_check_outlined,      t.shiftReports,        const ShiftListScreen()),
        _NavTab(Icons.settings_outlined,        t.settings,            const SettingsScreen()),
      ]);
    }

    // ── PRODUCTION SUPERVISOR: shift entry + transfer PROD→FG ─────────────────
    else if (appState.isProdSupervisor) {
      tabs.addAll([
        _NavTab(Icons.engineering_outlined,   t.productionSupervisorDashboard, const ProductionSupervisorScreen()),
        _NavTab(Icons.settings_outlined,      t.settings,                      const SettingsScreen()),
      ]);
    }

    // ── LEGACY SUPERVISOR: shift entry + approvals ────────────────────────────
    else if (appState.isSupervisor) {
      tabs.addAll([
        _NavTab(Icons.fact_check_outlined,    t.shifts,              const ShiftListScreen()),
        _NavTab(Icons.warehouse_outlined,     t.warehouseMovements,  const WarehouseScreen()),
        if (appState.canApproveShifts)
          _NavTab(Icons.verified_outlined,    t.approvals,           const ApprovalsScreen()),
        _NavTab(Icons.settings_outlined,      t.settings,            const SettingsScreen()),
      ]);
    }

    // ── RAW WAREHOUSE KEEPER ──────────────────────────────────────────────────
    else if (appState.isRawWhKeeper) {
      tabs.addAll([
        _NavTab(Icons.inventory_outlined,       t.rawWarehouse,       const RawWarehouseScreen()),
        _NavTab(Icons.settings_outlined,        t.settings,           const SettingsScreen()),
      ]);
    }

    // ── FINISHED GOODS WAREHOUSE KEEPER ──────────────────────────────────────
    else if (appState.isFgWhKeeper) {
      tabs.addAll([
        _NavTab(Icons.inventory_2_outlined,     t.fgWarehouse,        const FgWarehouseScreen()),
        _NavTab(Icons.settings_outlined,        t.settings,           const SettingsScreen()),
      ]);
    }

    // ── FUEL WAREHOUSE KEEPER ─────────────────────────────────────────────────
    else if (appState.isFuelWhKeeper) {
      tabs.addAll([
        _NavTab(Icons.local_gas_station_outlined, t.fuelWarehouse,    const FuelWarehouseScreen()),
        _NavTab(Icons.settings_outlined,          t.settings,         const SettingsScreen()),
      ]);
    }

    // ── OPERATOR (legacy) ────────────────────────────────────────────────────
    else if (appState.isOperator) {
      tabs.addAll([
        _NavTab(Icons.fact_check_outlined,    t.shifts,         const ShiftListScreen()),
        _NavTab(Icons.settings_outlined,      t.settings,       const SettingsScreen()),
      ]);
    }

    // ── VIEWER / FALLBACK ─────────────────────────────────────────────────────
    else {
      tabs.addAll([
        _NavTab(Icons.dashboard_outlined,  t.dashboard,   const DashboardScreen()),
        _NavTab(Icons.settings_outlined,   t.settings,    const SettingsScreen()),
      ]);
    }

    if (_index >= tabs.length) _index = 0;

    return Scaffold(
      body: Column(
        children: [
          const SyncStatusBar(),
          Expanded(child: SafeArea(child: tabs[_index].screen)),
        ],
      ),
      bottomNavigationBar: tabs.length > 1
          ? BottomNavigationBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              type: BottomNavigationBarType.fixed,
              items: tabs
                  .map((t) => BottomNavigationBarItem(
                        icon: Icon(t.icon),
                        label: t.label,
                      ))
                  .toList(),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavTab {
  const _NavTab(this.icon, this.label, this.screen);
  final IconData icon;
  final String label;
  final Widget screen;
}
