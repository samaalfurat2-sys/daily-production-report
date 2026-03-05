import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/api_client.dart';
import 'services/sync_service.dart';
import 'services/background_sync.dart';

class AppState extends ChangeNotifier {
  static const _kServerUrl = 'server_url';
  static const _kToken = 'token';
  static const _kLocale = 'locale';

  // Default server URL — override at build time with:
  //   flutter build apk --dart-define=BASE_URL=http://YOUR_SERVER_IP:9000
  static const String _kDefaultServerUrl =
      String.fromEnvironment('BASE_URL', defaultValue: 'https://hold-compete-major-choice.trycloudflare.com');
  String serverUrl = _kDefaultServerUrl;
  String? token;
  Locale? locale;

  List<String> roles = [];
  Map<String, bool> unitPermissions = {};

  bool get isLoggedIn => token != null && token!.isNotEmpty;
  ApiClient get api => ApiClient(baseUrl: serverUrl, token: token);

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    serverUrl = prefs.getString(_kServerUrl) ?? serverUrl;
    token = prefs.getString(_kToken);
    final localeCode = prefs.getString(_kLocale);
    if (localeCode != null && localeCode.isNotEmpty) {
      locale = Locale(localeCode);
    }
    notifyListeners();
    if (isLoggedIn) {
      await refreshMe();
      await SyncService.instance.init(serverUrl: serverUrl, token: token!);
      await BackgroundSync.register();
    }
  }

  Future<void> setLocale(Locale? newLocale) async {
    locale = newLocale;
    final prefs = await SharedPreferences.getInstance();
    if (newLocale == null) {
      await prefs.remove(_kLocale);
    } else {
      await prefs.setString(_kLocale, newLocale.languageCode);
    }
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    serverUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerUrl, serverUrl);
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    token = await api.login(username: username, password: password);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token!);
    notifyListeners();
    await refreshMe();
    await SyncService.instance.init(serverUrl: serverUrl, token: token!);
    await BackgroundSync.register();
  }

  Future<void> refreshMe() async {
    final me = await api.getMe();
    roles = List<String>.from(me['roles'] ?? []);
    unitPermissions = Map<String, bool>.from(me['unit_permissions'] ?? {});
    final preferredLocale = me['preferred_locale']?.toString();
    if (preferredLocale == 'ar' || preferredLocale == 'en') {
      locale = Locale(preferredLocale!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocale, preferredLocale);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await SyncService.instance.dispose_sync();
    await BackgroundSync.cancel();
    token = null;
    roles = [];
    unitPermissions = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    notifyListeners();
  }

  // ── Role helpers ──────────────────────────────────────────────────────────

  bool hasRole(String role) => roles.contains(role);
  bool hasAnyRole(List<String> r) => r.any((x) => roles.contains(x));

  bool get isAdmin          => hasRole('admin');
  bool get isRawWhKeeper    => hasRole('raw_wh_keeper');
  bool get isProdSupervisor => hasRole('production_supervisor');
  bool get isFgWhKeeper     => hasRole('fg_wh_keeper');
  bool get isFuelWhKeeper   => hasRole('fuel_wh_keeper');
  bool get isWhAccountant   => hasRole('wh_accountant');
  bool get isController     => hasRole('accounts_controller');
  bool get isGeneralManager => hasRole('general_manager');
  bool get isAuditor        => hasRole('auditor');
  // Legacy
  bool get isSupervisor     => hasRole('supervisor');
  bool get isOperator       => hasRole('operator');
  bool get isViewer         => hasRole('viewer');

  /// Can see the production shift data-entry screens
  bool get canEnterShifts =>
      isAdmin || isSupervisor || isProdSupervisor || isOperator;

  /// Can approve / lock shifts
  bool get canApproveShifts =>
      isAdmin || isSupervisor || isController || hasRole('warehouse_supervisor');

  /// Can access raw-materials warehouse operations
  bool get canAccessRawWH =>
      isAdmin || isRawWhKeeper || hasRole('warehouse_clerk') || hasRole('warehouse_supervisor');

  /// Can access finished-goods warehouse operations
  bool get canAccessFgWH =>
      isAdmin || isFgWhKeeper || hasRole('warehouse_clerk') || hasRole('warehouse_supervisor');

  /// Can access fuel warehouse operations
  bool get canAccessFuelWH =>
      isAdmin || isFuelWhKeeper || hasRole('warehouse_clerk') || hasRole('warehouse_supervisor');

  /// Can see/review all warehouse transactions (accountant, controller, manager, auditor)
  bool get canReviewAll =>
      isAdmin || isWhAccountant || isController || isGeneralManager || isAuditor ||
      isSupervisor || hasRole('warehouse_supervisor');

  /// Legacy compatibility
  bool get canSeeWarehouse => canAccessRawWH || canAccessFgWH || canAccessFuelWH || canReviewAll;

  bool canEditUnit(String unitCode) {
    if (isAdmin || isSupervisor || isProdSupervisor) return true;
    return unitPermissions[unitCode] == true;
  }
}
