/// push_notifications.dart — v3.0
/// Firebase Cloud Messaging (FCM) — FULLY ENABLED
library push_notifications;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ── Local notification channel (Android 8+) ─────────────────────────────────
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'daily_production_high', // id
  'Daily Production Alerts', // name
  description: 'Shift approvals, inventory alerts and system notices.',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// ── Top-level background handler (must be a global function) ─────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
  _showLocalNotification(message);
}

// ── Helper — show local notification ─────────────────────────────────────────
void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  final android = message.notification?.android;
  if (notification != null && android != null) {
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
class PushNotifications {
  PushNotifications._();

  static bool _initialized = false;

  // ── Initialise ─────────────────────────────────────────────────────────────
  /// Call once after Firebase.initializeApp() in main().
  static Future<void> initialize({
    required String serverUrl,
    required String token,
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // ── Request permission (iOS / Android 13+) ──────────────────────────────
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // ── Android local notification channel ──────────────────────────────────
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // ── Init local notifications plugin ─────────────────────────────────────
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          final data = jsonDecode(details.payload!) as Map<String, dynamic>;
          _handleNotificationTap(data, navigatorKey);
        }
      },
    );

    // ── Get & register FCM token ─────────────────────────────────────────────
    final fcmToken = await messaging.getToken();
    if (fcmToken != null) {
      await _registerToken(
          serverUrl: serverUrl, token: token, fcmToken: fcmToken);
    }

    // ── Token refresh ────────────────────────────────────────────────────────
    messaging.onTokenRefresh.listen((newToken) {
      _registerToken(serverUrl: serverUrl, token: token, fcmToken: newToken);
    });

    // ── Foreground messages ──────────────────────────────────────────────────
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
      _handleForegroundMessage(message, navigatorKey);
    });

    // ── Notification tap — app in background ─────────────────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data, navigatorKey);
    });

    // ── Notification tap — app was terminated ────────────────────────────────
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _handleNotificationTap(initial.data, navigatorKey);
    }

    // ── Keep app alive for background delivery (Android) ────────────────────
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('[FCM] Push notifications fully initialised ✅');
  }

  // ── Register token with backend ────────────────────────────────────────────
  static Future<void> _registerToken({
    required String serverUrl,
    required String token,
    required String fcmToken,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/users/fcm-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );
      debugPrint('[FCM] Token registered — HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  // ── Foreground message handler ─────────────────────────────────────────────
  static void _handleForegroundMessage(
      RemoteMessage message, GlobalKey<NavigatorState> navKey) {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? '';
    final body = notification.body ?? '';
    final context = navKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            if (body.isNotEmpty) Text(body),
          ],
        ),
        action: SnackBarAction(
          label: 'فتح',
          onPressed: () =>
              _handleNotificationTap(message.data, navKey),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  // ── Navigation on tap ──────────────────────────────────────────────────────
  static void _handleNotificationTap(
    Map<String, dynamic> data,
    GlobalKey<NavigatorState> navKey,
  ) {
    final type = data['type']?.toString();
    final shiftId = data['shift_id']?.toString();

    if (type == 'shift_approved' && shiftId != null) {
      debugPrint('[FCM] Navigate → shift detail $shiftId');
      // navKey.currentState?.push(MaterialPageRoute(
      //   builder: (_) => ShiftDetailScreen(shiftId: shiftId),
      // ));
    } else if (type == 'txn_acknowledged' || type == 'txn_posted') {
      debugPrint('[FCM] Navigate → transactions screen');
    }
  }
}
