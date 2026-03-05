/// background_sync.dart — v2.5
/// Android background sync using workmanager.
///
/// Registers a periodic task that:
///   1. Checks server reachability (GET /health)
///   2. Flushes the offline queue (POST /sync/batch)
///   3. Flushes queued shift unit updates (PUT /shifts/{id}/{unit})
///   4. Pulls a delta (GET /sync/delta)
///
/// Registration: call BackgroundSync.register() once after login.
/// Cancellation: call BackgroundSync.cancel() on logout.
///
/// Dependencies to add to pubspec.yaml:
///   workmanager: ^0.5.2
///
/// Android manifest additions (android/app/src/main/AndroidManifest.xml):
///   <uses-permission android:name="android.permission.INTERNET"/>
///   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
///
///   Inside <application>:
///   <service
///     android:name="be.tramckrijte.workmanager.BackgroundWorker"
///     android:permission="android.permission.BIND_JOB_SERVICE"
///     android:exported="true"/>
library background_sync;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'local_db.dart';

const _kTaskName = 'production_app_background_sync';
const _kTaskTag  = 'bg_sync';

/// Top-level callback required by workmanager (must be a global/static function).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await _runBackgroundSync();
      return true;
    } catch (e) {
      debugPrint('[BgSync] error: $e');
      return false;
    }
  });
}

Future<void> _runBackgroundSync() async {
  final prefs = await SharedPreferences.getInstance();
  final serverUrl = prefs.getString('server_url') ?? 'http://localhost:8000';
  final token = prefs.getString('token');
  if (token == null || token.isEmpty) return; // not logged in

  // ── 1. Health check ────────────────────────────────────────────────────────
  try {
    final health = await http
        .get(Uri.parse('$serverUrl/health'))
        .timeout(const Duration(seconds: 8));
    if (health.statusCode >= 500) return; // server down
  } catch (_) {
    return; // no network
  }

  final headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── 2. Flush offline queue ─────────────────────────────────────────────────
  final pending = await LocalDb.instance.pendingQueue();
  if (pending.isNotEmpty) {
    try {
      final res = await http
          .post(
            Uri.parse('$serverUrl/sync/batch'),
            headers: headers,
            body: jsonEncode(pending),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final results = jsonDecode(res.body) as List<dynamic>;
        for (final r in results) {
          final clientId = r['client_id'] as String?;
          final status = r['status'] as String?;
          if (clientId != null && (status == 'created' || status == 'duplicate')) {
            await LocalDb.instance.dequeue(clientId);
          }
        }
      }
    } catch (_) {
      // Will retry on next run
    }
  }

  // ── 3. Flush shift unit updates ───────────────────────────────────────────
  final pendingShiftUpdates = await LocalDb.instance.pendingShiftUpdates();
  for (final update in pendingShiftUpdates) {
    try {
      final shiftId = update['shift_id'] as String;
      final unit    = update['unit']     as String;
      final payload = jsonDecode(update['payload_json'] as String) as Map<String, dynamic>;
      final clientId = update['client_id'] as String;
      final res = await http
          .put(
            Uri.parse('$serverUrl/shifts/$shiftId/$unit'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 || res.statusCode == 409) {
        // 409 = already finalised – safe to drop
        await LocalDb.instance.dequeueShiftUpdate(clientId);
      }
    } catch (_) {
      // Will retry on next run
    }
  }

  // ── 4. Delta pull ──────────────────────────────────────────────────────────
  try {
    final since = await LocalDb.instance.getLastSyncAt();
    final uri = Uri.parse('$serverUrl/sync/delta')
        .replace(queryParameters: since != null ? {'since': since} : null);
    final res = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      for (final s in (data['shifts'] as List<dynamic>? ?? [])) {
        await LocalDb.instance.upsertShift(s as Map<String, dynamic>);
      }
      for (final t in (data['inventory_transactions'] as List<dynamic>? ?? [])) {
        await LocalDb.instance.upsertTxn(t as Map<String, dynamic>);
      }
      final serverTime = data['server_time'] as String?;
      if (serverTime != null) {
        await LocalDb.instance.setLastSyncAt(serverTime);
      }
    }
  } catch (_) {
    // Will retry on next run
  }
}

/// Helper class for registering / cancelling the background task.
class BackgroundSync {
  BackgroundSync._();

  /// Call once at app start (before any task registration).
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  /// Register a periodic sync task (min interval = 15 minutes on Android).
  static Future<void> register() async {
    await Workmanager().registerPeriodicTask(
      _kTaskName,
      _kTaskName,
      tag: _kTaskTag,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
    debugPrint('[BgSync] periodic task registered');
  }

  /// Cancel on logout.
  static Future<void> cancel() async {
    await Workmanager().cancelByTag(_kTaskTag);
    debugPrint('[BgSync] periodic task cancelled');
  }
}
