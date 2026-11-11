import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ticket.dart';

/// Durable local store: the ticket outbox, per-branch drafts, cached menus and settings.
class LocalDb {
  LocalDb._(this._db);
  final Database _db;

  static Future<LocalDb> open() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await getApplicationSupportDirectory();
    final path = p.join(directory.path, 'elrashedy_pos.db');
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tickets (
              client_id TEXT PRIMARY KEY,
              user_id INTEGER NOT NULL,
              branch_id INTEGER NOT NULL,
              placed_at TEXT NOT NULL,
              payload TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0,
              server_id INTEGER,
              error TEXT,
              attempts INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL
            )''');
          await db.execute('CREATE INDEX idx_tickets_pending ON tickets (user_id, synced, placed_at)');
          await db.execute('''
            CREATE TABLE drafts (
              key TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE menu_cache (
              key TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              cached_at TEXT NOT NULL
            )''');
          await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        },
      ),
    );
    return LocalDb._(db);
  }

  Future<void> close() => _db.close();

  Future<void> saveTicket(Ticket ticket) async {
    await _db.insert(
      'tickets',
      {
        'client_id': ticket.clientId,
        'user_id': ticket.userId,
        'branch_id': ticket.branchId,
        'placed_at': ticket.placedAt.toUtc().toIso8601String(),
        'payload': jsonEncode(ticket.toStorageJson()),
        'synced': ticket.synced ? 1 : 0,
        'server_id': ticket.serverId,
        'error': ticket.error,
        'attempts': ticket.attempts,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Ticket>> tickets(int userId, {bool? synced}) async {
    final rows = await _db.query(
      'tickets',
      where: synced == null ? 'user_id = ?' : 'user_id = ? AND synced = ?',
      whereArgs: synced == null ? [userId] : [userId, synced ? 1 : 0],
      orderBy: 'placed_at DESC',
    );
    return rows.map((row) => Ticket.fromStorageJson(jsonDecode(row['payload'] as String) as Map<String, dynamic>)).toList();
  }

  Future<List<Ticket>> pendingTickets(int userId) async {
    final rows = await _db.query(
      'tickets',
      where: 'user_id = ? AND synced = 0',
      whereArgs: [userId],
      orderBy: 'placed_at ASC',
    );
    return rows.map((row) => Ticket.fromStorageJson(jsonDecode(row['payload'] as String) as Map<String, dynamic>)).toList();
  }

  Future<Ticket?> ticketByClientId(String clientId) async {
    final rows = await _db.query('tickets', where: 'client_id = ?', whereArgs: [clientId], limit: 1);
    if (rows.isEmpty) return null;
    return Ticket.fromStorageJson(jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>);
  }

  Future<int> pendingCount(int userId) async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS c FROM tickets WHERE user_id = ? AND synced = 0', [userId]);
    return (result.first['c'] as num).toInt();
  }

  Future<void> saveDraft(String key, Map<String, dynamic> payload) async {
    await _db.insert(
      'drafts',
      {'key': key, 'payload': jsonEncode(payload), 'updated_at': DateTime.now().toUtc().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> readDraft(String key) async {
    final rows = await _db.query('drafts', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
  }

  Future<void> saveMenu(String key, List<Map<String, dynamic>> products) async {
    await _db.insert(
      'menu_cache',
      {'key': key, 'payload': jsonEncode(products), 'cached_at': DateTime.now().toUtc().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<({List<Map<String, dynamic>> products, String cachedAt})?> readMenu(String key) async {
    final rows = await _db.query('menu_cache', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return (
      products: (jsonDecode(rows.first['payload'] as String) as List<dynamic>).cast<Map<String, dynamic>>(),
      cachedAt: rows.first['cached_at'] as String,
    );
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<Map<String, String>> allSettings() async {
    final rows = await _db.query('settings');
    return {for (final row in rows) row['key'] as String: row['value'] as String};
  }
}