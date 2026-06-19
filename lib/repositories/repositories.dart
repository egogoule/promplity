// lib/repositories/repositories.dart
// Thin repository wrappers over AppDatabase

import '../models/models.dart';
import 'database.dart';

class ServerRepository {
  final AppDatabase _db;
  ServerRepository(this._db);

  Future<List<Server>> getAll() => _db.getServers();
  Future<void> save(Server server) => _db.upsertServer(server);
  Future<void> delete(String id) => _db.deleteServer(id);
  Future<void> touch(String id) => _db.touchServerLastConnected(id);
}

class ProfileRepository {
  final AppDatabase _db;
  ProfileRepository(this._db);

  Future<List<CredentialProfile>> getAll() => _db.getProfiles();
  Future<void> save(CredentialProfile p) => _db.upsertProfile(p);
  Future<void> delete(String id) => _db.deleteProfile(id);
}

class KeymapRepository {
  final AppDatabase _db;
  KeymapRepository(this._db);

  Future<List<KeymapBinding>> getAll() => _db.getKeybindings();
  Future<void> save(KeymapBinding kb) => _db.upsertKeybinding(kb);
  Future<void> delete(String id) => _db.deleteKeybinding(id);
  Future<void> resetDefaults() => _db.resetDefaultKeybindings();
}

class HistoryRepository {
  final AppDatabase _db;
  HistoryRepository(this._db);

  Future<List<CommandHistoryEntry>> getForServer(String serverId, {int limit = 200}) =>
      _db.getHistory(serverId, limit: limit);
  Future<void> insert(CommandHistoryEntry entry) => _db.insertHistory(entry);
  Future<void> clearForServer(String serverId) => _db.clearHistory(serverId);
}
