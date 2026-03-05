/// local_db.dart — v2.4
/// SQLite cache for offline-first operation (sqflite).
///
/// Tables
/// ──────
/// offline_queue  – transactions queued while offline
/// cached_txns    – mirror of server inventory_transactions
/// cached_shifts  – mirror of server shift records
/// sync_meta              – single-row key/value: last_sync_at (ISO8601)
/// pending_shift_updates  – queued shift unit saves for replay when back online
library local_db;

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  // ── Schema ─────────────────────────────────────────────────────────────────

  static const _ddl = [
    '''
    CREATE TABLE IF NOT EXISTS offline_queue (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id   TEXT    NOT NULL UNIQUE,
      payload_json TEXT   NOT NULL,
      created_at  TEXT    NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS cached_txns (
      id            TEXT PRIMARY KEY,
      data_json     TEXT NOT NULL,
      updated_at    TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS cached_shifts (
      id            TEXT PRIMARY KEY,
      data_json     TEXT NOT NULL,
      updated_at    TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS sync_meta (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS pending_shift_updates (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id   TEXT    NOT NULL UNIQUE,
      shift_id    TEXT    NOT NULL,
      unit        TEXT    NOT NULL,
      payload_json TEXT   NOT NULL,
      created_at  TEXT    NOT NULL
    )
    ''',
  ];

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), 'production_app_v24.db');
    return openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, _) async {
        for (final ddl in _ddl) {
          await db.execute(ddl);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pending_shift_updates (
              id          INTEGER PRIMARY KEY AUTOINCREMENT,
              client_id   TEXT    NOT NULL UNIQUE,
              shift_id    TEXT    NOT NULL,
              unit        TEXT    NOT NULL,
              payload_json TEXT   NOT NULL,
              created_at  TEXT    NOT NULL
            )
          ''');
        }
      },
    );
  }

  // ── Offline queue ──────────────────────────────────────────────────────────

  /// Enqueue a transaction payload for later sync.
  Future<void> enqueue(String clientId, Map<String, dynamic> payload) async {
    final d = await db;
    await d.insert(
      'offline_queue',
      {
        'client_id': clientId,
        'payload_json': jsonEncode(payload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // idempotent
    );
  }

  /// Return all queued items in insertion order.
  Future<List<Map<String, dynamic>>> pendingQueue() async {
    final d = await db;
    final rows = await d.query('offline_queue', orderBy: 'id ASC');
    return rows
        .map((r) => jsonDecode(r['payload_json'] as String) as Map<String, dynamic>)
        .toList();
  }

  /// Remove a successfully synced item by client_id.
  Future<void> dequeue(String clientId) async {
    final d = await db;
    await d.delete('offline_queue', where: 'client_id = ?', whereArgs: [clientId]);
  }

  /// Number of items still queued.
  Future<int> queueLength() async {
    final d = await db;
    final result = await d.rawQuery('SELECT COUNT(*) AS cnt FROM offline_queue');
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ── Cached transactions ────────────────────────────────────────────────────

  Future<void> upsertTxn(Map<String, dynamic> data) async {
    final d = await db;
    await d.insert(
      'cached_txns',
      {
        'id': data['id'] as String,
        'data_json': jsonEncode(data),
        'updated_at': (data['created_at'] ?? DateTime.now().toUtc().toIso8601String()) as String,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCachedTxns() async {
    final d = await db;
    final rows = await d.query('cached_txns', orderBy: 'updated_at DESC');
    return rows.map((r) => jsonDecode(r['data_json'] as String) as Map<String, dynamic>).toList();
  }

  // ── Cached shifts ──────────────────────────────────────────────────────────

  Future<void> upsertShift(Map<String, dynamic> data) async {
    final d = await db;
    await d.insert(
      'cached_shifts',
      {
        'id': data['id'] as String,
        'data_json': jsonEncode(data),
        'updated_at': (data['updated_at'] ?? data['created_at'] ?? DateTime.now().toUtc().toIso8601String()) as String,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCachedShifts() async {
    final d = await db;
    final rows = await d.query('cached_shifts', orderBy: 'updated_at DESC');
    return rows.map((r) => jsonDecode(r['data_json'] as String) as Map<String, dynamic>).toList();
  }

  // ── Sync metadata ──────────────────────────────────────────────────────────

  Future<String?> getLastSyncAt() async {
    final d = await db;
    final rows = await d.query('sync_meta', where: 'key = ?', whereArgs: ['last_sync_at']);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setLastSyncAt(String isoTimestamp) async {
    final d = await db;
    await d.insert(
      'sync_meta',
      {'key': 'last_sync_at', 'value': isoTimestamp},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Pending shift-unit updates ────────────────────────────────────────────

  /// Queue a shift unit update for replay when back online.
  Future<void> enqueueShiftUpdate(String clientId, String shiftId, String unit, Map<String, dynamic> payload) async {
    final d = await db;
    await d.insert(
      'pending_shift_updates',
      {
        'client_id': clientId,
        'shift_id': shiftId,
        'unit': unit,
        'payload_json': jsonEncode(payload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Return all pending shift updates in insertion order.
  Future<List<Map<String, dynamic>>> pendingShiftUpdates() async {
    final d = await db;
    final rows = await d.query('pending_shift_updates', orderBy: 'id ASC');
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      m['payload'] = jsonDecode(m['payload_json'] as String) as Map<String, dynamic>;
      return m;
    }).toList();
  }

  /// Remove a flushed shift update.
  Future<void> dequeueShiftUpdate(String clientId) async {
    final d = await db;
    await d.delete('pending_shift_updates', where: 'client_id = ?', whereArgs: [clientId]);
  }

  /// Count pending shift updates.
  Future<int> shiftUpdateQueueLength() async {
    final d = await db;
    final result = await d.rawQuery('SELECT COUNT(*) as c FROM pending_shift_updates');
    return (result.first['c'] as int?) ?? 0;
  }

  Future<void> clearCache() async {
    final d = await db;
    await d.delete('cached_txns');
    await d.delete('cached_shifts');
    await d.delete('sync_meta');
    await d.delete('pending_shift_updates');
  }
}
