import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Microsoft Graph API client for OneDrive access
/// Handles OAuth2 device-code flow, token refresh, and file operations
class GraphClient {
  static const _clientId = 'd3590ed6-52b3-4102-aeff-aad2292ab01c';
  static const _scope = 'Files.ReadWrite offline_access User.Read';
  static const _tenantId = 'common'; // Support personal and work accounts
  
  // Token endpoints
  static const _deviceCodeUrl = 'https://login.microsoftonline.com/\$_tenantId/oauth2/v2.0/devicecode';
  static const _tokenUrl = 'https://login.microsoftonline.com/\$_tenantId/oauth2/v2.0/token';
  static const _graphBaseUrl = 'https://graph.microsoft.com/v1.0';
  
  // SharedPreferences keys
  static const _keyRefreshToken = 'ms_refresh_token';
  static const _keyAccessToken = 'ms_access_token';
  static const _keyTokenExpiry = 'ms_token_expiry';
  
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  
  /// Initialize and load tokens from storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _refreshToken = prefs.getString(_keyRefreshToken);
    _accessToken = prefs.getString(_keyAccessToken);
    final expiryMs = prefs.getInt(_keyTokenExpiry);
    if (expiryMs != null) {
      _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    }
    
    // If we have a refresh token but access token expired, refresh it
    if (_refreshToken != null && (_accessToken == null || _isTokenExpired())) {
      await refreshAccessToken();
    }
  }
  
  bool get isConnected => _refreshToken != null;
  
  bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)));
  }
  
  /// Start device-code authentication flow
  /// Returns: {user_code, device_code, verification_uri, expires_in}
  Future<Map<String, dynamic>> startDeviceCodeFlow() async {
    final response = await http.post(
      Uri.parse(_deviceCodeUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'scope': _scope,
      },
    );
    
    if (response.statusCode != 200) {
      throw Exception('Device code request failed: \${response.body}');
    }
    
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  /// Poll for token after user completes device code flow
  /// Call this repeatedly until it succeeds or times out
  /// Returns: true if token acquired, false if still pending
  Future<bool> pollDeviceCode(String deviceCode) async {
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        'client_id': _clientId,
        'device_code': deviceCode,
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        expiresIn: data['expires_in'] as int,
      );
      return true;
    }
    
    // Check error response
    final error = jsonDecode(response.body) as Map<String, dynamic>;
    final errorCode = error['error'] as String?;
    
    if (errorCode == 'authorization_pending') {
      // User hasn't completed auth yet, keep polling
      return false;
    } else if (errorCode == 'slow_down' || errorCode == 'authorization_declined' || errorCode == 'expired_token') {
      throw Exception('Device code flow failed: \$errorCode');
    }
    
    throw Exception('Token poll failed: \${response.body}');
  }
  
  /// Refresh access token using stored refresh token
  Future<void> refreshAccessToken() async {
    if (_refreshToken == null) {
      throw Exception('No refresh token available');
    }
    
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': _clientId,
        'refresh_token': _refreshToken!,
        'scope': _scope,
      },
    );
    
    if (response.statusCode != 200) {
      throw Exception('Token refresh failed: \${response.body}');
    }
    
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await _saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String? ?? _refreshToken!,
      expiresIn: data['expires_in'] as int,
    );
  }
  
  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setInt(_keyTokenExpiry, _tokenExpiry!.millisecondsSinceEpoch);
  }
  
  /// Ensure we have a valid access token
  Future<String> _getAccessToken() async {
    if (_accessToken == null || _isTokenExpired()) {
      await refreshAccessToken();
    }
    return _accessToken!;
  }
  
  /// Disconnect (clear tokens)
  Future<void> disconnect() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyTokenExpiry);
  }
  
  /// Read JSON file from OneDrive
  /// path: e.g. "ProductionReports/db/users.json"
  /// Returns: decoded JSON (Map or List)
  /// Throws: if file doesn't exist or can't be parsed
  Future<dynamic> readJsonFile(String path) async {
    final token = await _getAccessToken();
    final encodedPath = Uri.encodeComponent(path);
    final url = '\$_graphBaseUrl/me/drive/root:/\$encodedPath:/content';
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer \$token'},
    );
    
    if (response.statusCode == 404) {
      throw Exception('File not found: \$path');
    }
    
    if (response.statusCode != 200) {
      throw Exception('Failed to read file \$path: \${response.statusCode} \${response.body}');
    }
    
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
  
  /// Write JSON file to OneDrive
  /// path: e.g. "ProductionReports/db/shifts.json"
  /// data: Map or List to be JSON encoded
  Future<void> writeJsonFile(String path, dynamic data) async {
    final token = await _getAccessToken();
    final encodedPath = Uri.encodeComponent(path);
    final url = '\$_graphBaseUrl/me/drive/root:/\$encodedPath:/content';
    
    final jsonContent = jsonEncode(data);
    final bytes = utf8.encode(jsonContent);
    
    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer \$token',
        'Content-Type': 'application/json',
      },
      body: bytes,
    );
    
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to write file \$path: \${response.statusCode} \${response.body}');
    }
  }
  
  /// List files in a OneDrive folder
  /// folderPath: e.g. "ProductionReports/db"
  /// Returns: List of file metadata Maps
  Future<List<Map<String, dynamic>>> listFiles(String folderPath) async {
    final token = await _getAccessToken();
    final encodedPath = Uri.encodeComponent(folderPath);
    final url = '\$_graphBaseUrl/me/drive/root:/\$encodedPath:/children';
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer \$token'},
    );
    
    if (response.statusCode == 404) {
      return []; // Folder doesn't exist yet
    }
    
    if (response.statusCode != 200) {
      throw Exception('Failed to list files in \$folderPath: \${response.statusCode}');
    }
    
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['value'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>();
  }
  
  /// Get current user info
  Future<Map<String, dynamic>> getMe() async {
    final token = await _getAccessToken();
    final url = '\$_graphBaseUrl/me';
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer \$token'},
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to get user info: \${response.statusCode}');
    }
    
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
