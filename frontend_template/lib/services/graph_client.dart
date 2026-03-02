import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GraphClient {
  static const _clientId = 'd3590ed6-52b3-4102-aeff-aad2292ab01c';
  static const _scope = 'Files.ReadWrite offline_access User.Read';
  static const _tenantId = 'common';
  static const _deviceCodeUrl = 'https://login.microsoftonline.com/common/oauth2/v2.0/devicecode';
  static const _tokenUrl = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';
  static const _graphBaseUrl = 'https://graph.microsoft.com/v1.0';
  static const _keyRefreshToken = 'ms_refresh_token';
  static const _keyAccessToken = 'ms_access_token';
  static const _keyTokenExpiry = 'ms_token_expiry';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _refreshToken = prefs.getString(_keyRefreshToken);
    _accessToken = prefs.getString(_keyAccessToken);
    final expiryMs = prefs.getInt(_keyTokenExpiry);
    if (expiryMs != null) _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    if (_refreshToken != null && (_accessToken == null || _isTokenExpired())) {
      try { await refreshAccessToken(); } catch (_) {}
    }
  }

  bool get isConnected => _refreshToken != null && _refreshToken!.isNotEmpty;
  bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)));
  }

  Future<Map<String, dynamic>> startDeviceCodeFlow() async {
    final res = await http.post(Uri.parse(_deviceCodeUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'client_id': _clientId, 'scope': _scope});
    if (res.statusCode != 200) throw Exception('Device code failed: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> pollDeviceCode(String deviceCode) async {
    final res = await http.post(Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'grant_type': 'urn:ietf:params:oauth:grant-type:device_code', 'client_id': _clientId, 'device_code': deviceCode});
    if (res.statusCode == 200) {
      final d = jsonDecode(res.body) as Map<String, dynamic>;
      await _saveTokens(accessToken: d['access_token'] as String, refreshToken: d['refresh_token'] as String, expiresIn: d['expires_in'] as int);
      return true;
    }
    final err = (jsonDecode(res.body) as Map)['error'] as String? ?? '';
    if (err == 'authorization_pending') return false;
    throw Exception('Auth failed: $err');
  }

  Future<void> refreshAccessToken() async {
    if (_refreshToken == null) throw Exception('No refresh token');
    final res = await http.post(Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'grant_type': 'refresh_token', 'client_id': _clientId, 'refresh_token': _refreshToken!, 'scope': _scope});
    if (res.statusCode != 200) { await disconnect(); throw Exception('Token refresh failed'); }
    final d = jsonDecode(res.body) as Map<String, dynamic>;
    await _saveTokens(accessToken: d['access_token'] as String, refreshToken: d['refresh_token'] as String? ?? _refreshToken!, expiresIn: d['expires_in'] as int);
  }

  Future<void> _saveTokens({required String accessToken, required String refreshToken, required int expiresIn}) async {
    _accessToken = accessToken; _refreshToken = refreshToken;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setInt(_keyTokenExpiry, _tokenExpiry!.millisecondsSinceEpoch);
  }

  Future<String> _getAccessToken() async {
    if (_accessToken == null || _isTokenExpired()) await refreshAccessToken();
    return _accessToken!;
  }

  Future<void> disconnect() async {
    _accessToken = null; _refreshToken = null; _tokenExpiry = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken); await prefs.remove(_keyRefreshToken); await prefs.remove(_keyTokenExpiry);
  }

  Future<dynamic> readJsonFile(String path) async {
    final token = await _getAccessToken();
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    final res = await http.get(Uri.parse('$_graphBaseUrl/me/drive/root:/$encoded:/content'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 404) throw Exception('File not found: $path');
    if (res.statusCode != 200) throw Exception('Read failed [$path]: ${res.statusCode}');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<void> writeJsonFile(String path, dynamic data) async {
    final token = await _getAccessToken();
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    final res = await http.put(Uri.parse('$_graphBaseUrl/me/drive/root:/$encoded:/content'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: utf8.encode(jsonEncode(data)));
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Write failed [$path]: ${res.statusCode}');
  }

  Future<List<Map<String, dynamic>>> listFiles(String folderPath) async {
    final token = await _getAccessToken();
    final encoded = folderPath.split('/').map(Uri.encodeComponent).join('/');
    final res = await http.get(Uri.parse('$_graphBaseUrl/me/drive/root:/$encoded:/children'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 404) return [];
    if (res.statusCode != 200) throw Exception('List failed: ${res.statusCode}');
    return List<Map<String, dynamic>>.from((jsonDecode(res.body) as Map)['value'] ?? []);
  }

  Future<Map<String, dynamic>> getMe() async {
    final token = await _getAccessToken();
    final res = await http.get(Uri.parse('$_graphBaseUrl/me'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) throw Exception('Profile failed');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
