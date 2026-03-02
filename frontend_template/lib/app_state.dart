import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/api_client.dart';

class AppState extends ChangeNotifier {
  static const _kServerUrl = 'server_url';
  static const _kToken = 'token';
  static const _kLocale = 'locale';

  String serverUrl = 'http://localhost:8000';
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
    token = null;
    roles = [];
    unitPermissions = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    notifyListeners();
  }

  bool hasRole(String role) => roles.contains(role);

  bool canEditUnit(String unitCode) {
    if (hasRole('admin') || hasRole('supervisor')) return true;
    return unitPermissions[unitCode] == true;
  }

  bool get canSeeWarehouse => hasRole('admin') || hasRole('warehouse_clerk') || hasRole('warehouse_supervisor') || hasRole('supervisor');
}
