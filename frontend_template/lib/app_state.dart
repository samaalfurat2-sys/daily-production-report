import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/graph_client.dart';
import 'services/onedrive_db.dart';

class AppState extends ChangeNotifier {
  static const _kToken = 'token';
  static const _kLocale = 'locale';
  String? token;
  Locale? locale;
  List<String> roles = [];
  Map<String, bool> unitPermissions = {};
  GraphClient? _graphClient;
  OneDriveDb? _db;

  bool get isLoggedIn => token != null && token!.isNotEmpty;
  bool get isConnectedToOneDrive => _graphClient?.isConnected ?? false;

  OneDriveDb get db { _graphClient ??= GraphClient(); _db ??= OneDriveDb(_graphClient!); return _db!; }
  GraphClient get graph { _graphClient ??= GraphClient(); return _graphClient!; }

  Future<void> loadFromStorage() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_kToken);
    final lc = p.getString(_kLocale);
    if (lc != null && lc.isNotEmpty) locale = Locale(lc);
    await graph.init();
    notifyListeners();
    if (isLoggedIn && isConnectedToOneDrive) try { await refreshMe(); } catch (_) {}
  }

  Future<void> setLocale(Locale? l) async {
    locale = l;
    final p = await SharedPreferences.getInstance();
    if (l == null) { await p.remove(_kLocale); } else { await p.setString(_kLocale, l.languageCode); }
    notifyListeners();
  }

  Future<Map<String, dynamic>> connectOneDrive() => graph.startDeviceCodeFlow();

  Future<bool> pollOneDriveConnection(String dc) async {
    final ok = await graph.pollDeviceCode(dc);
    if (ok) { await db.initialize(); notifyListeners(); }
    return ok;
  }

  Future<void> disconnectOneDrive() async { await graph.disconnect(); notifyListeners(); }

  Future<void> login(String username, String password) async {
    if (!isConnectedToOneDrive) throw Exception('OneDrive not connected');
    final user = await db.login(username, password);
    token = username;
    roles = List<String>.from(user['roles'] ?? []);
    unitPermissions = Map<String, bool>.from(user['unit_permissions'] ?? {});
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token!);
    notifyListeners();
  }

  Future<void> refreshMe() async {
    if (token == null || !isConnectedToOneDrive) return;
    final me = await db.getMe(token!);
    roles = List<String>.from(me['roles'] ?? []);
    unitPermissions = Map<String, bool>.from(me['unit_permissions'] ?? {});
    final pl = me['preferred_locale']?.toString();
    if (pl == 'ar' || pl == 'en') {
      locale = Locale(pl!);
      final p = await SharedPreferences.getInstance();
      await p.setString(_kLocale, pl);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    token = null; roles = []; unitPermissions = {};
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    notifyListeners();
  }

  bool hasRole(String r) => roles.contains(r);
  bool canEditUnit(String u) { if (hasRole('admin') || hasRole('supervisor')) return true; return unitPermissions[u] == true; }
  bool get canSeeWarehouse => hasRole('admin') || hasRole('warehouse_clerk') || hasRole('warehouse_supervisor') || hasRole('supervisor');
}
