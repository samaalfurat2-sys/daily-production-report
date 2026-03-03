// lib/auth/onedrive_auth.dart
//
// EXAMPLE — flutter_appauth-based OneDrive / Microsoft Graph sign-in (PKCE flow).
//
// PURPOSE:
//   This file provides a native "tap-to-sign-in" experience on Android that
//   opens the system browser (Chrome Custom Tabs), lets the user authenticate,
//   then automatically redirects back to the app.
//
//   The app's DEFAULT flow is the device-code flow in graph_client.dart, which
//   works on all platforms without any browser redirect setup.  Use THIS file
//   when you want one-tap Android sign-in instead.
//
// ── SETUP (one-time per environment) ────────────────────────────────────────
//
//  Step 1 — Add flutter_appauth to pubspec.yaml (already done):
//    flutter_appauth: ^8.0.1
//
//  Step 2 — Get your SHA-1 signing fingerprint.
//    Debug keystore:
//      keytool -list -v \
//        -keystore ~/.android/debug.keystore \
//        -alias androiddebugkey \
//        -storepass android -keypass android
//    Release keystore:
//      keytool -list -v \
//        -keystore /path/to/release.jks \
//        -alias YOUR_KEY_ALIAS \
//        -storepass YOUR_STORE_PASSWORD
//    Copy the "SHA1:" line from the output.
//
//  Step 3 — Register the redirect URI in Azure.
//    Azure Portal → App Registrations → your app →
//    Authentication → Add a platform → Android.
//    Enter:
//      Package name:    com.example.production_report_app  ← your applicationId
//      Signature hash:  <paste SHA-1 from Step 2>
//    Azure generates:
//      msauth://com.example.production_report_app/<base64-sha1>
//    Copy the full URI.
//
//  Step 4 — Replace the placeholder below.
//    Change _sha1Placeholder to the base64-sha1 segment from the URI above.
//
//  Step 5 — Enable "Allow public client flows" for your Azure app registration
//    so the PKCE flow is accepted without a client secret.
//
//  Step 6 — Verify AndroidManifest.xml has the msauth:// intent-filter
//    (already present in this project for the default package name).
//
// ── USAGE ────────────────────────────────────────────────────────────────────
//
//   final auth = OneDriveAuth();
//   await auth.signIn();               // opens browser, returns after redirect
//   final token = await auth.getAccessToken();
//   // ... use token with Microsoft Graph API ...
//   auth.signOut();                    // clears tokens locally
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer' as dev;

import 'package:flutter_appauth/flutter_appauth.dart';

/// Wrapper around [FlutterAppAuth] for Microsoft OneDrive / Graph OAuth.
///
/// Before using this class in production, replace [_sha1Placeholder] with the
/// base64-encoded SHA-1 from your Azure App Registration (see file header).
class OneDriveAuth {
  // ── Azure App Registration ──────────────────────────────────────────────────

  /// Application (client) ID from Azure Portal → App Registrations.
  /// This is a public identifier; it is safe to commit to source control.
  // TODO: Replace with YOUR Application (client) ID if you create a new Azure app.
  static const _clientId = 'd2123462-2f0c-44f5-8f0e-ff2f489c7449';

  /// Must match the applicationId in android/app/build.gradle.
  // TODO: Replace with your actual package name if you rename the app.
  static const _packageName = 'com.example.production_report_app';

  /// Tenant — use 'common' to support both personal (MSA) and work/school accounts.
  static const _issuer = 'https://login.microsoftonline.com/common/v2.0';

  // ── Redirect URI ──────────────────────────────────────────────────────────
  //
  // Format:  msauth://<packageName>/<url-encoded-base64-sha1>
  //
  // TODO: Replace _sha1Placeholder with the base64-sha1 segment from the
  //       redirect URI shown in Azure Portal after completing Step 3 above.
  //       Do NOT commit your actual SHA-1 fingerprint value to source control.
  static const _sha1Placeholder = 'placeholder_replace_with_your_base64_sha1';

  static final _redirectUri = 'msauth://$_packageName/$_sha1Placeholder';

  // ── OAuth Scopes ──────────────────────────────────────────────────────────

  /// Scopes required for reading/writing files and identifying the user.
  static const _scopes = <String>[
    'https://graph.microsoft.com/Files.ReadWrite',
    'https://graph.microsoft.com/User.Read',
    'offline_access', // enables refresh token issuance
  ];

  // ── State ─────────────────────────────────────────────────────────────────

  final _flutterAppAuth = const FlutterAppAuth();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessTokenExpiry;

  /// The most recently obtained access token, or null if not signed in.
  String? get accessToken => _accessToken;

  /// True when a refresh token is stored (user previously signed in).
  bool get isSignedIn => _refreshToken != null && _refreshToken!.isNotEmpty;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Starts the interactive PKCE sign-in flow (opens system browser / CCT).
  ///
  /// Throws an [Exception] if [_sha1Placeholder] has not been replaced, or on
  /// authentication failure.  Throws [PlatformException] if the user cancels.
  Future<void> signIn() async {
    // Guard: prevent accidental use before the placeholder is replaced.
    if (_sha1Placeholder == 'placeholder_replace_with_your_base64_sha1') {
      throw Exception(
        'OneDriveAuth: _sha1Placeholder has not been replaced. '
        'Replace _sha1Placeholder in lib/auth/onedrive_auth.dart with '
        'the base64 SHA-1 from your Azure App Registration (see file header).',
      );
    }

    dev.log('OneDriveAuth: starting authorization request', name: 'OneDriveAuth');
    try {
      final result = await _flutterAppAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUri,
          issuer: _issuer,
          scopes: _scopes,
          // promptValues: forces account picker so multi-account users can choose.
          promptValues: ['select_account'],
        ),
      );
      if (result == null) {
        dev.log('OneDriveAuth: authorization cancelled by user', name: 'OneDriveAuth');
        throw Exception('Sign-in cancelled by user');
      }
      _accessToken = result.accessToken;
      _refreshToken = result.refreshToken;
      _accessTokenExpiry = result.accessTokenExpirationDateTime;
      dev.log(
        'OneDriveAuth: sign-in successful, token expires $_accessTokenExpiry',
        name: 'OneDriveAuth',
      );
    } catch (e) {
      dev.log('OneDriveAuth: sign-in error: $e', name: 'OneDriveAuth', error: e);
      rethrow;
    }
  }

  /// Silently refreshes the access token using the stored refresh token.
  ///
  /// Call this if [getAccessToken] is not sufficient (e.g., you need to force
  /// a refresh before an important background operation).
  Future<void> refreshToken() async {
    if (_refreshToken == null) {
      throw Exception('OneDriveAuth: no refresh token — call signIn() first');
    }
    dev.log('OneDriveAuth: refreshing access token', name: 'OneDriveAuth');
    try {
      final result = await _flutterAppAuth.token(
        TokenRequest(
          _clientId,
          _redirectUri,
          issuer: _issuer,
          refreshToken: _refreshToken,
          scopes: _scopes,
        ),
      );
      if (result == null) throw Exception('OneDriveAuth: token refresh returned null');
      _accessToken = result.accessToken;
      _refreshToken = result.refreshToken ?? _refreshToken; // keep old if not rotated
      _accessTokenExpiry = result.accessTokenExpirationDateTime;
      dev.log(
        'OneDriveAuth: token refreshed, expires $_accessTokenExpiry',
        name: 'OneDriveAuth',
      );
    } catch (e) {
      dev.log('OneDriveAuth: token refresh error: $e', name: 'OneDriveAuth', error: e);
      rethrow;
    }
  }

  /// Returns a valid access token, refreshing automatically when near expiry.
  ///
  /// Refreshes proactively 5 minutes before the token expires to avoid
  /// 401 errors mid-request.
  Future<String> getAccessToken() async {
    final expiry = _accessTokenExpiry;
    final isExpired = expiry == null ||
        DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 5)));
    if (_accessToken == null || isExpired) {
      await refreshToken();
    }
    return _accessToken!;
  }

  /// Clears all stored tokens (signs the user out locally).
  ///
  /// Does NOT revoke tokens on the server side.  To fully sign out, also
  /// open https://login.microsoftonline.com/common/oauth2/v2.0/logout in
  /// the system browser.
  void signOut() {
    _accessToken = null;
    _refreshToken = null;
    _accessTokenExpiry = null;
    dev.log('OneDriveAuth: tokens cleared (local sign-out)', name: 'OneDriveAuth');
  }
}
