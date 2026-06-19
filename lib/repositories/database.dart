// lib/repositories/database.dart
// SQLite database setup + AES-256 encryption for sensitive fields

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../models/models.dart';

class AppDatabase {
  static AppDatabase? _instance;
  Database? _db;
  late enc.Encrypter _encrypter;
  late enc.IV _iv;

  AppDatabase._();
  static AppDatabase get instance => _instance ??= AppDatabase._();

  Future<void> init(String masterPassword) async {
    // Desktop SQLite init
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Derive AES-256 key from master password (SHA-256)
    final keyBytes = sha256.convert(utf8.encode(masterPassword)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));
    _iv = enc.IV(Uint8List.fromList(keyBytes.sublist(0, 16)));
    _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final dbPath = join(await getDatabasesPath(), 'ssh_client.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async {
        // Enable WAL mode to allow multiple processes (windows) to access the DB
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA synchronous = NORMAL');
      },
    );
  }

  /// Re-initialize for a standalone window. Now uses the same disk DB thanks to WAL mode.
  Future<void> initStandalone() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Use a fixed master key for now as in main init
    final keyBytes = sha256.convert(utf8.encode('default_master_key_123')).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));
    _iv = enc.IV(Uint8List.fromList(keyBytes.sublist(0, 16)));
    _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final dbPath = join(await getDatabasesPath(), 'ssh_client.db');
    _db = await openDatabase(
      dbPath,
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode = WAL');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE servers (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        host TEXT NOT NULL,
        port INTEGER NOT NULL DEFAULT 22,
        username TEXT NOT NULL,
        password TEXT,
        private_key_path TEXT,
        private_key_passphrase TEXT,
        profile_id TEXT,
        last_connected TEXT,
        terminal_type TEXT NOT NULL DEFAULT 'pty'
      )
    ''');

    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT,
        private_key_path TEXT,
        private_key_passphrase TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE keybindings (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        action TEXT NOT NULL,
        ctrl INTEGER NOT NULL DEFAULT 0,
        shift INTEGER NOT NULL DEFAULT 0,
        alt INTEGER NOT NULL DEFAULT 0,
        key TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE command_history (
        id TEXT PRIMARY KEY,
        server_id TEXT NOT NULL,
        command TEXT NOT NULL,
        output TEXT NOT NULL,
        executed_at TEXT NOT NULL,
        exit_code INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Insert default keybindings
    for (final kb in defaultKeybindings()) {
      await db.insert('keybindings', kb.toMap());
    }
  }

  Database get db {
    if (_db == null) throw StateError('Database not initialized. Call init() first.');
    return _db!;
  }

  // ── Encryption helpers ──────────────────────────────────────────────────

  String? _encrypt(String? value) {
    if (value == null || value.isEmpty) return null;
    return _encrypter.encrypt(value, iv: _iv).base64;
  }

  String? _decrypt(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return _encrypter.decrypt64(value, iv: _iv);
    } catch (_) {
      return null; // wrong master password or corrupt data
    }
  }

  Map<String, dynamic> _encryptServer(Map<String, dynamic> m) => {
        ...m,
        'password': _encrypt(m['password'] as String?),
        'private_key_passphrase': _encrypt(m['private_key_passphrase'] as String?),
      };

  Map<String, dynamic> _decryptServer(Map<String, dynamic> m) => {
        ...m,
        'password': _decrypt(m['password'] as String?),
        'private_key_passphrase': _decrypt(m['private_key_passphrase'] as String?),
      };

  Map<String, dynamic> _encryptProfile(Map<String, dynamic> m) => {
        ...m,
        'password': _encrypt(m['password'] as String?),
        'private_key_passphrase': _encrypt(m['private_key_passphrase'] as String?),
      };

  Map<String, dynamic> _decryptProfile(Map<String, dynamic> m) => {
        ...m,
        'password': _decrypt(m['password'] as String?),
        'private_key_passphrase': _decrypt(m['private_key_passphrase'] as String?),
      };

  // ── SERVERS ─────────────────────────────────────────────────────────────

  Future<List<Server>> getServers() async {
    final rows = await db.query('servers', orderBy: 'last_connected DESC');
    return rows.map((r) => Server.fromMap(_decryptServer(r))).toList();
  }

  Future<void> upsertServer(Server server) async {
    await db.insert(
      'servers',
      _encryptServer(server.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteServer(String id) async {
    await db.delete('servers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> touchServerLastConnected(String id) async {
    await db.update(
      'servers',
      {'last_connected': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── PROFILES ────────────────────────────────────────────────────────────

  Future<List<CredentialProfile>> getProfiles() async {
    final rows = await db.query('profiles', orderBy: 'name ASC');
    return rows.map((r) => CredentialProfile.fromMap(_decryptProfile(r))).toList();
  }

  Future<void> upsertProfile(CredentialProfile profile) async {
    await db.insert(
      'profiles',
      _encryptProfile(profile.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteProfile(String id) async {
    await db.delete('profiles', where: 'id = ?', whereArgs: [id]);
  }

  // ── KEYBINDINGS ─────────────────────────────────────────────────────────

  Future<List<KeymapBinding>> getKeybindings() async {
    final rows = await db.query('keybindings');
    return rows.map((r) => KeymapBinding.fromMap(r)).toList();
  }

  Future<void> upsertKeybinding(KeymapBinding kb) async {
    await db.insert(
      'keybindings',
      kb.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteKeybinding(String id) async {
    await db.delete('keybindings', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> resetDefaultKeybindings() async {
    await db.delete('keybindings', where: 'is_default = 1');
    for (final kb in defaultKeybindings()) {
      await db.insert('keybindings', kb.toMap());
    }
  }

  // ── COMMAND HISTORY ─────────────────────────────────────────────────────

  Future<List<CommandHistoryEntry>> getHistory(String serverId, {int limit = 200}) async {
    final rows = await db.query(
      'command_history',
      where: 'server_id = ?',
      whereArgs: [serverId],
      orderBy: 'executed_at DESC',
      limit: limit,
    );
    return rows.map((r) => CommandHistoryEntry.fromMap(r)).toList();
  }

  Future<void> insertHistory(CommandHistoryEntry entry) async {
    await db.insert('command_history', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearHistory(String serverId) async {
    await db.delete('command_history', where: 'server_id = ?', whereArgs: [serverId]);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
