/// sync_service.dart — v2.4
/// ChangeNotifier that manages:
///   • Connectivity monitoring (online / offline banner)
///   • Offline queue flushing via POST /sync/batch
///   • Delta pull via GET /sync/delta?since=<ts>
///   • WebSocket subscription for real-time events
///
/// Usage (in AppState.login / loadFromStorage):
///   syncService.init(serverUrl: url, token: tok);
///
/// UI reads:
///   syncService.isOnline          → bool
///   syncService.pendingCount      → int
///   syncService.lastSyncAt        → DateTime?
///   syncService.isSyncing         → bool
library sync_service;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

import 'local_db.dart';

class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  // ── State ─────────────────────────────────────────────────────────────────

  bool isOnline = false;
  bool isSyncing = false;
  int pendingCount = 0;
  DateTime? lastSyncAt;
  String? _lastError;
  String? get lastError => _lastError;

  /// Items rejected by the server during the last batch flush.
  /// UI should watch this list and show [SyncConflictDialog] when non-empty.
  List<Map<String, dynamic>> rejectedItems = [];
  int pendingShiftUpdateCount = 0;

  // ── Config ────────────────────────────────────────────────────────────────

  String? _serverUrl;
  String? _token;

  // ── Internal ──────────────────────────────────────────────────────────────

  Timer? _connectivityTimer;
  Timer? _periodicSyncTimer;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  bool _wsConnected = false;

  static const _pingInterval = Duration(seconds: 25);
  static const _connectivityCheckInterval = Duration(seconds: 10);
  static const _periodicSyncInterval = Duration(minutes: 2);

  // ── Init / Dispose ────────────────────────────────────────────────────────

  /// Call after login or token refresh.
  Future<void> init({required String serverUrl, required String token}) async {
    _serverUrl = serverUrl;
    _token = token;
    pendingCount = await LocalDb.instance.queueLength();
    notifyListeners();
    _startConnectivityPolling();
    _startPeriodicSync();
    _connectWs();
  }

  /// Call on logout.
  Future<void> dispose_sync() async {
    _connectivityTimer?.cancel();
    _periodicSyncTimer?.cancel();
    await _disconnectWs();
    _serverUrl = null;
    _token = null;
    isOnline = false;
    pendingCount = 0;
    lastSyncAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _periodicSyncTimer?.cancel();
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  // ── Connectivity ──────────────────────────────────────────────────────────

  void _startConnectivityPolling() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(_connectivityCheckInterval, (_) => _checkConnectivity());
    _checkConnectivity(); // immediate first check
  }

  Future<void> _checkConnectivity() async {
    if (_serverUrl == null) return;
    try {
      final uri = _buildUri('/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      final wasOnline = isOnline;
      isOnline = res.statusCode < 500;
      if (!wasOnline && isOnline) {
        // Just came back online → flush queue + delta pull
        _flushAndSync();
        if (!_wsConnected) _connectWs();
      }
    } catch (_) {
      if (isOnline) {
        isOnline = false;
        notifyListeners();
      }
    }
    notifyListeners();
  }

  // ── Periodic sync ─────────────────────────────────────────────────────────

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(_periodicSyncInterval, (_) {
      if (isOnline) _flushAndSync();
    });
  }

  // ── Flush + Delta ─────────────────────────────────────────────────────────

  Future<void> _flushAndSync() async {
    await flushQueue();
    await flushShiftUpdates();
    await pullDelta();
  }

  /// Manually trigger a sync (e.g. pull-to-refresh in UI).
  Future<void> syncNow() async {
    if (!isOnline) {
      _lastError = 'Offline – sync not possible';
      notifyListeners();
      return;
    }
    await _flushAndSync();
  }

  // ── Batch flush ───────────────────────────────────────────────────────────

  /// Send all queued offline transactions to POST /sync/batch.
  Future<void> flushQueue() async {
    if (_serverUrl == null || _token == null) return;
    final items = await LocalDb.instance.pendingQueue();
    if (items.isEmpty) return;
    isSyncing = true;
    notifyListeners();
    try {
      final uri = _buildUri('/sync/batch');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(items),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final results = jsonDecode(res.body) as List<dynamic>;
        final newRejected = <Map<String, dynamic>>[];
        for (final r in results) {
          final clientId = r['client_id'] as String?;
          final status = r['status'] as String?;
          if (clientId != null && (status == 'created' || status == 'duplicate')) {
            await LocalDb.instance.dequeue(clientId);
          } else if (status == 'error') {
            // Enrich with original payload so UI can display details
            final originalPayload = items.firstWhere(
              (p) => p['client_id'] == clientId,
              orElse: () => <String, dynamic>{},
            );
            newRejected.add({
              ...Map<String, dynamic>.from(r as Map),
              'payload': originalPayload,
            });
          }
        }
        if (newRejected.isNotEmpty) {
          rejectedItems = newRejected;
        }
      } else {
        _lastError = 'Batch flush error: \${res.statusCode}';
      }
    } catch (e) {
      _lastError = 'Batch flush failed: $e';
    } finally {
      pendingCount = await LocalDb.instance.queueLength();
      isSyncing = false;
      notifyListeners();
    }
  }

  // ── Delta pull ────────────────────────────────────────────────────────────

  /// Fetch changes since last sync and upsert into local cache.
  Future<void> pullDelta() async {
    if (_serverUrl == null || _token == null) return;
    isSyncing = true;
    notifyListeners();
    try {
      final since = await LocalDb.instance.getLastSyncAt();
      final query = since != null ? {'since': since} : <String, String>{};
      final uri = _buildUri('/sync/delta', query);
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final shifts = data['shifts'] as List<dynamic>? ?? [];
        final txns = data['inventory_transactions'] as List<dynamic>? ?? [];
        final serverTime = data['server_time'] as String?;

        for (final s in shifts) {
          await LocalDb.instance.upsertShift(s as Map<String, dynamic>);
        }
        for (final t in txns) {
          await LocalDb.instance.upsertTxn(t as Map<String, dynamic>);
        }
        if (serverTime != null) {
          await LocalDb.instance.setLastSyncAt(serverTime);
          lastSyncAt = DateTime.tryParse(serverTime);
        }
        _lastError = null;
      } else {
        _lastError = 'Delta pull error: ${res.statusCode}';
      }
    } catch (e) {
      _lastError = 'Delta pull failed: $e';
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  // ── Enqueue offline transaction ───────────────────────────────────────────

  /// Queue a transaction payload (Map matching InventoryTxnCreate schema)
  /// for later flush. Returns the generated client_id.
  Future<String> enqueueTransaction(Map<String, dynamic> payload) async {
    const uuid = Uuid();
    final clientId = uuid.v4();
    final payloadWithId = {...payload, 'client_id': clientId};
    await LocalDb.instance.enqueue(clientId, payloadWithId);
    pendingCount = await LocalDb.instance.queueLength();
    notifyListeners();
    // Attempt immediate flush if online
    if (isOnline) flushQueue();
    return clientId;
  }


  /// Named-parameter convenience wrapper around [enqueueTransaction].
  Future<String> enqueueInventoryTransaction({
    required String warehouseCode,
    required String itemCode,
    required String txnType,
    required String txnDate,
    required double qty,
    String? note,
  }) {
    return enqueueTransaction({
      'warehouse_code': warehouseCode,
      'item_code': itemCode,
      'txn_type': txnType,
      'txn_date': txnDate,
      'qty': qty,
      if (note != null) 'note': note,
    });
  }

  // ── WebSocket ─────────────────────────────────────────────────────────────

  // ── Shift-unit offline queue ──────────────────────────────────────────────

  /// Queue a shift unit update for offline replay.
  Future<String> enqueueShiftUnitUpdate({
    required String shiftId,
    required String unit,
    required Map<String, dynamic> payload,
  }) async {
    const uuid = Uuid();
    final clientId = uuid.v4();
    await LocalDb.instance.enqueueShiftUpdate(clientId, shiftId, unit, payload);
    pendingShiftUpdateCount = await LocalDb.instance.shiftUpdateQueueLength();
    notifyListeners();
    if (isOnline) flushShiftUpdates();
    return clientId;
  }

  /// Replay all queued shift unit updates against the server.
  Future<void> flushShiftUpdates() async {
    if (_serverUrl == null || _token == null) return;
    final pending = await LocalDb.instance.pendingShiftUpdates();
    if (pending.isEmpty) return;

    final client = http.Client();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
    for (final item in pending) {
      final clientId = item['client_id'] as String;
      final shiftId  = item['shift_id']  as String;
      final unit     = item['unit']      as String;
      final payload  = item['payload']   as Map<String, dynamic>;
      try {
        final res = await client.put(
          Uri.parse('$_serverUrl/shifts/$shiftId/$unit'),
          headers: headers,
          body: jsonEncode(payload),
        );
        if (res.statusCode < 300) {
          await LocalDb.instance.dequeueShiftUpdate(clientId);
        }
      } catch (_) {
        // Will retry next sync cycle
      }
    }
    client.close();
    pendingShiftUpdateCount = await LocalDb.instance.shiftUpdateQueueLength();
    notifyListeners();
  }

  void _connectWs() {
    if (_serverUrl == null || _token == null) return;
    _disconnectWs();
    try {
      final wsUri = _buildWsUri('/ws', {'token': _token!});
      _wsChannel = WebSocketChannel.connect(wsUri);
      _wsConnected = true;
      _wsSub = _wsChannel!.stream.listen(
        _onWsMessage,
        onError: (_) => _handleWsClose(),
        onDone: _handleWsClose,
      );
      // Heartbeat
      Timer.periodic(_pingInterval, (t) {
        if (!_wsConnected) {
          t.cancel();
          return;
        }
        try {
          _wsChannel?.sink.add(jsonEncode({'ping': true}));
        } catch (_) {
          t.cancel();
        }
      });
    } catch (_) {
      _wsConnected = false;
    }
  }

  Future<void> _disconnectWs() async {
    _wsConnected = false;
    await _wsSub?.cancel();
    _wsSub = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void _handleWsClose() {
    _wsConnected = false;
    // Reconnect after 5 s if still online
    Future.delayed(const Duration(seconds: 5), () {
      if (isOnline && _token != null) _connectWs();
    });
  }

  void _onWsMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = msg['event'] as String?;
      if (event == null) return;

      switch (event) {
        case 'txn_created':
        case 'txn_status_changed':
          final data = msg['data'] as Map<String, dynamic>?;
          if (data != null) {
            LocalDb.instance.upsertTxn(data);
            notifyListeners();
          }
          break;
        case 'shift_status_changed':
          final data = msg['data'] as Map<String, dynamic>?;
          if (data != null) {
            LocalDb.instance.upsertShift(data);
            notifyListeners();
          }
          break;
        case 'pong':
          break; // heartbeat ack
        default:
          break;
      }
    } catch (_) {
      // malformed message – ignore
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(_serverUrl!);
    return base.replace(
      path: '${base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path}$path',
      queryParameters: (query != null && query.isNotEmpty) ? query : null,
    );
  }

  Uri _buildWsUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(_serverUrl!);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '${base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path}$path',
      queryParameters: (query != null && query.isNotEmpty) ? query : null,
    );
  }
}
