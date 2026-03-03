// lib/auth/onedrive_auth.dart
//
// EXAMPLE — flutter_appauth-based OneDrive / Microsoft Graph sign-in.
//
// This file demonstrates the recommended PKCE / authorization-code OAuth flow
// for Android.  The current app uses the device-code flow (graph_client.dart),
// which works on all platforms without browser redirects.  Integrate this file
// if you want a native "tap-to-sign-in" experience that opens the system
// browser (Chrome Custom Tabs) and redirects back automatically.
//
// ── Setup steps ─────────────────────────────────────────────────────────────
//
//  1. Add to pubspec.yaml (already done if you are reading this):
//       flutter_appauth: ^8.0.1
//
//  2. Register an Android redirect URI in Azure:
//       msauth://<your-package-name>/<url-encoded-base64-sha1>
//     Example (debug keystore):
//       msauth://com.example.production_report_app/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%3D
//     See README.md → "Android OneDrive Sign-In Setup" for the exact command
//     to obtain your SHA-1 fingerprint.
//
//  3. The AndroidManifest.xml intent-filter (already added by this project)
//     must use the same scheme + host:
//       <data android:scheme="msauth"
//             android:host="com.example.production_report_app"/>
//
//  4. Enable "Allow public client flows" for your Azure app registration so
//     the PKCE flow is accepted without a client secret.
//
// ── Usage ────────────────────────────────────────────────────────────────────
//
//   final auth = OneDriveAuth();
//   await auth.signIn();          // opens Chrome Custom Tabs / system browser
//   final token = auth.accessToken;
//   await auth.signOut();
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer' as dev;

import 'package:flutter_appauth/flutter_appauth.dart';

/// Wrapper around [FlutterAppAuth] for Microsoft OneDrive / Graph OAuth.
///
/// Replace [_clientId] and [_packageName] with the values from your Azure
/// App Registration before shipping.
class OneDriveAuth {
  // ── Azure App Registration values ──────────────────────────────────────────

  /// Application (client) ID from Azure Portal → App Registrations.
  static const _clientId = 'd2123462-2f0c-44f5-8f0e-ff2f489c7449';

  /// Must match the applicationId in android/app/build.gradle.
  static const _packageName = 'com.example.production_report_app';

  /// Issuer URL — use 'common' for both personal and work accounts.
  static const _issuer =
      'https://login.microsoftonline.com/common/v2.0';

  // ── Redirect URI ──────────────────────────────────────────────────────────
  //
  // Format: msauth://<package_name>/<url-encoded-base64-sha1>
  // Obtain the SHA-1 for your debug keystore with:
  //   keytool -list -v \
  //     -keystore ~/.android/debug.keystore \
  //     -alias androiddebugkey \
  //     -storepass android -keypass android
  // Then base64-encode and URL-encode the raw 20-byte fingerprint.
  // Register the SAME URI in Azure → Authentication → Add a platform →
  // Android → enter Package name and Signature hash.
  //
  // For TESTING you can use the loopback redirect supported by MSAL:
  //   https://login.microsoftonline.com/common/oauth2/nativeclient
  // but the msauth:// scheme is required for production Android.
  //
  // TODO: Replace the placeholder below with your actual base64-encoded SHA-1
  //       from Azure Portal before using this class in production.
  static const _sha1Placeholder = 'placeholder_replace_with_your_base64_sha1';
  static final _redirectUri = 'msauth://$_packageName/$_sha1Placeholder';

  static const _scopes = <String>[
    'https://graph.microsoft.com/Files.ReadWrite',
    'https://graph.microsoft.com/User.Read',
    'offline_access',
  ];

  // ── State ─────────────────────────────────────────────────────────────────

  final _appAuth = const FlutterAppAuth();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessTokenExpiry;

  String? get accessToken => _accessToken;
  bool get isSignedIn => _refreshToken != null && _refreshToken!.isNotEmpty;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Starts the interactive sign-in flow (opens system browser / CCT).
  ///
  /// Throws [PlatformException] or [Exception] on failure.
  Future<void> signIn() async {
    if (_redirectUri.contains('placeholder')) {
      throw Exception(
          'OneDriveAuth: redirectUri still contains the placeholder. '
          'Replace _sha1Placeholder in lib/auth/onedrive_auth.dart with '
          'the base64 SHA-1 from your Azure App Registration.');
    }
    dev.log('OneDriveAuth: starting authorization request', name: 'OneDriveAuth');
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUri,
          issuer: _issuer,
          scopes: _scopes,
          promptValues: ['select_account'],
        ),
      );
      if (result == null) {
        dev.log('OneDriveAuth: authorization cancelled by user', name: 'OneDriveAuth');
        throw Exception('Sign-in cancelled');
      }
      _accessToken = result.accessToken;
      _refreshToken = result.refreshToken;
      _accessTokenExpiry = result.accessTokenExpirationDateTime;
      dev.log('OneDriveAuth: sign-in successful, token expires $_accessTokenExpiry',
          name: 'OneDriveAuth');
    } catch (e) {
      dev.log('OneDriveAuth: sign-in error: $e', name: 'OneDriveAuth', error: e);
      rethrow;
    }
  }

  /// Refreshes the access token silently using the stored refresh token.
  Future<void> refreshToken() async {
    if (_refreshToken == null) throw Exception('No refresh token - call signIn() first');
    dev.log('OneDriveAuth: refreshing access token', name: 'OneDriveAuth');
    try {
      final result = await _appAuth.token(
        TokenRequest(
          _clientId,
          _redirectUri,
          issuer: _issuer,
          refreshToken: _refreshToken,
          scopes: _scopes,
        ),
      );
      if (result == null) throw Exception('Token refresh returned null');
      _accessToken = result.accessToken;
      _refreshToken = result.refreshToken ?? _refreshToken;
      _accessTokenExpiry = result.accessTokenExpirationDateTime;
      dev.log('OneDriveAuth: token refreshed, expires $_accessTokenExpiry',
          name: 'OneDriveAuth');
    } catch (e) {
      dev.log('OneDriveAuth: token refresh error: $e', name: 'OneDriveAuth', error: e);
      rethrow;
    }
  }

  /// Returns a valid access token, refreshing automatically if expired.
  Future<String> getAccessToken() async {
    final expiry = _accessTokenExpiry;
    final isExpired = expiry == null ||
        DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 5)));
    if (_accessToken == null || isExpired) {
      await refreshToken();
    }
    return _accessToken!;
  }

  /// Clears all stored tokens (effectively signs the user out locally).
  void signOut() {
    _accessToken = null;
    _refreshToken = null;
    _accessTokenExpiry = null;
    dev.log('OneDriveAuth: signed out', name: 'OneDriveAuth');
  }
}
