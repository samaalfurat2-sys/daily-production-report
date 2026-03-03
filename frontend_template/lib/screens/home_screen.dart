import 'package:flutter/material.dart';
import 'package:production_report_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'dashboard_screen.dart';
import 'shift_list_screen.dart';
import 'approvals_screen.dart';
import 'warehouse_screen.dart';
import 'raw_warehouse_screen.dart';
import 'fg_warehouse_screen.dart';
import 'fuel_warehouse_screen.dart';
import 'accountant_screen.dart';
import 'controller_screen.dart';
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
    final app = context.watch<AppState>();

    final tabs = <Widget>[];
    final items = <BottomNavigationBarItem>[];

    void add(Widget screen, IconData icon, String label) {
      tabs.add(screen);
      items.add(BottomNavigationBarItem(icon: Icon(icon), label: label));
    }

    // ── المدير العام / admin – يرى كل شيء ───────────────────────────────────
    if (app.isGeneralManager) {
      add(const DashboardScreen(), Icons.dashboard_outlined, t.dashboard);
      add(const ShiftListScreen(), Icons.fact_check_outlined, t.shifts);
      add(const ApprovalsScreen(), Icons.verified_outlined, t.approvals);
      add(const WarehouseScreen(), Icons.warehouse_outlined, t.warehouses);
      add(const AccountantScreen(), Icons.account_balance_outlined, t.accountant);
      add(const ControllerScreen(), Icons.verified_user_outlined, t.controller);
      add(const OneDriveSyncScreen(), Icons.cloud_sync_outlined, t.oneDrive);
      add(const SettingsScreen(), Icons.settings_outlined, t.settings);
      return _build(tabs, items);
    }

    // ── مدقق الحسابات – عرض فقط ─────────────────────────────────────────────
    if (app.isAccountAuditor) {
      add(const DashboardScreen(), Icons.dashboard_outlined, t.dashboard);
      add(const ShiftListScreen(), Icons.fact_check_outlined, t.shifts);
      add(const WarehouseScreen(), Icons.warehouse_outlined, t.warehouses);
      add(const AccountantScreen(), Icons.account_balance_outlined, t.accountant);
      add(const SettingsScreen(), Icons.settings_outlined, t.settings);
      return _build(tabs, items);
    }

    // ── مراقب الحسابات – يرحّل ويؤكد ────────────────────────────────────────
    if (app.isAuditorController) {
      add(const ControllerScreen(), Icons.verified_user_outlined, t.controller);
      add(const DashboardScreen(), Icons.dashboard_outlined, t.dashboard);
      add(const ShiftListScreen(), Icons.fact_check_outlined, t.shifts);
      add(const WarehouseScreen(), Icons.warehouse_outlined, t.warehouses);
      add(const SettingsScreen(), Icons.settings_outlined, t.settings);
      return _build(tabs, items);
    }

    // ── محاسب المخازن ─────────────────────────────────────────────────────────
    if (app.isWarehouseAccountant) {
      add(const AccountantScreen(), Icons.account_balance_outlined, t.accountant);
      add(const SettingsScreen(), Icons.settings_outlined, t.settings);
      return _build(tabs, items);
    }

    // ── أمين مخزن المواد الخام ───────────────────────────────────────────────
    if (app.isRawWarehouseKeeper) {
      add(const RawWarehouseScreen(), Icons.inventory_2_outlined, t.rawWarehouse);
      add(const SettingsScreen(), Icons.settings_outlined, t.settings);
      return _build(tabs, items);
    }

    // ── مشرف صالة الإنتاج ────────────────────────────────────────────────────
    if (app.isProductionSupervisor) {
      add(const DashboardScreen(), Icons.dashboard_outlined, t.dashboard);
      add(const ShiftListScreen(), Icons.fact_check_outlined, t.shifts);
      add(const SettingsScreen(), Icons.settings_outlined, t.settings);
      return _build(tabs, items);
    }

    // ── أمين مخزن المنتج الجاهز ──────────────────────────────────────────────
    if (app.isFgWarehouseKeeper) {
      add(const FgWarehouseScreen(), Icons.local_shipping_outlined, t.fgWarehouse);
      add(const SettingsScreen(), Icons.settings_outlined, t.settings);
      return _build(tabs, items);
    }

    // ── أمين مخزن المحروقات ───────────────────────────────────────────────────
    if (app.isFuelWarehouseKeeper) {
      add(const FuelWarehouseScreen(), Icons.local_gas_station_outlined, t.fuelWarehouse);
      add(const SettingsScreen(), Icons.settings_outlined, t.settings);
      return _build(tabs, items);
    }

    // ── fallback: لوحة التحكم + إعدادات ─────────────────────────────────────
    add(const DashboardScreen(), Icons.dashboard_outlined, t.dashboard);
    add(const SettingsScreen(), Icons.settings_outlined, t.settings);
    return _build(tabs, items);
  }

  Widget _build(List<Widget> tabs, List<BottomNavigationBarItem> items) {
    final safeIndex = _index < tabs.length ? _index : 0;
    return Scaffold(
      body: SafeArea(child: tabs[safeIndex]),
      bottomNavigationBar: items.length > 1
          ? BottomNavigationBar(
              currentIndex: safeIndex,
              onTap: (i) => setState(() => _index = i),
              items: items,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).colorScheme.primary,
            )
          : null,
    );
  }
}
