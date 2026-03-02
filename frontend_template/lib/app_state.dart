import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/graph_client.dart';
import 'services/onedrive_db.dart';

class AppState extends ChangeNotifier {
  static const _kToken = 'token'; // Now stores username instead of JWT
  static const _kLocale = 'locale';

  String? token; // Username after login
  Locale? locale;

  List<String> roles = [];
  Map<String, bool> unitPermissions = {};

  // Lazy-initialized OneDrive services
  GraphClient? _graphClient;
  OneDriveDb? _db;

  bool get isLoggedIn => token != null && token!.isNotEmpty;
  bool get isConnectedToOneDrive => _graphClient?.isConnected ?? false;
  
  OneDriveDb get db {
    if (_db == null) {
      _graphClient ??= GraphClient();
      _db = OneDriveDb(_graphClient!);
    }
    return _db!;
  }
  
  GraphClient get graph {
    _graphClient ??= GraphClient();
    return _graphClient!;
  }

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_kToken);
    final localeCode = prefs.getString(_kLocale);
    if (localeCode != null && localeCode.isNotEmpty) {
      locale = Locale(localeCode);
    }
    
    // Initialize GraphClient
    await graph.init();
    
    notifyListeners();
    
    if (isLoggedIn && isConnectedToOneDrive) {
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

  /// Connect to OneDrive - starts device-code flow
  /// Returns device code info for user to complete auth
  Future<Map<String, dynamic>> connectOneDrive() async {
    return await graph.startDeviceCodeFlow();
  }
  
  /// Poll for OneDrive connection completion
  Future<bool> pollOneDriveConnection(String deviceCode) async {
    final success = await graph.pollDeviceCode(deviceCode);
    if (success) {
      await db.initialize();
      notifyListeners();
    }
    return success;
  }
  
  /// Disconnect from OneDrive
  Future<void> disconnectOneDrive() async {
    await graph.disconnect();
    notifyListeners();
  }

  /// Login with username/password (checked against OneDrive users.json)
  Future<void> login(String username, String password) async {
    if (!isConnectedToOneDrive) {
      throw Exception('OneDrive not connected. Please connect first.');
    }
    
    final user = await db.login(username, password);
    token = username;
    
    roles = List<String>.from(user['roles'] ?? []);
    unitPermissions = Map<String, bool>.from(user['unit_permissions'] ?? {});
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token!);
    
    notifyListeners();
  }

  Future<void> refreshMe() async {
    if (token == null || !isConnectedToOneDrive) return;
    
    final me = await db.getMe(token!);
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

  bool get canSeeWarehouse =>
      hasRole('admin') ||
      hasRole('warehouse_clerk') ||
      hasRole('warehouse_supervisor') ||
      hasRole('supervisor');
}
