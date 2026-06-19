// lib/models/models.dart
// All data models for the SSH client

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ─────────────────────────────────────────────
// SERVER
// ─────────────────────────────────────────────

class Server extends Equatable {
  final String id;
  final String label;        // user-friendly name
  final String host;         // IP or domain
  final int port;
  final String username;
  final String? password;    // null when using key auth
  final String? privateKeyPath;
  final String? privateKeyPassphrase;
  final String? profileId;   // linked credential profile
  final DateTime? lastConnected;
  final String terminalType; // 'pty' | 'simple'

  const Server({
    required this.id,
    required this.label,
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKeyPath,
    this.privateKeyPassphrase,
    this.profileId,
    this.lastConnected,
    this.terminalType = 'pty',
  });

  factory Server.create({
    required String label,
    required String host,
    int port = 22,
    required String username,
    String? password,
    String? privateKeyPath,
    String? privateKeyPassphrase,
    String? profileId,
    String terminalType = 'pty',
  }) =>
      Server(
        id: _uuid.v4(),
        label: label,
        host: host,
        port: port,
        username: username,
        password: password,
        privateKeyPath: privateKeyPath,
        privateKeyPassphrase: privateKeyPassphrase,
        profileId: profileId,
        terminalType: terminalType,
      );

  Server copyWith({
    String? label,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKeyPath,
    String? privateKeyPassphrase,
    String? profileId,
    DateTime? lastConnected,
    String? terminalType,
  }) =>
      Server(
        id: id,
        label: label ?? this.label,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        password: password ?? this.password,
        privateKeyPath: privateKeyPath ?? this.privateKeyPath,
        privateKeyPassphrase: privateKeyPassphrase ?? this.privateKeyPassphrase,
        profileId: profileId ?? this.profileId,
        lastConnected: lastConnected ?? this.lastConnected,
        terminalType: terminalType ?? this.terminalType,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'private_key_path': privateKeyPath,
        'private_key_passphrase': privateKeyPassphrase,
        'profile_id': profileId,
        'last_connected': lastConnected?.toIso8601String(),
        'terminal_type': terminalType,
      };

  factory Server.fromMap(Map<String, dynamic> m) => Server(
        id: m['id'] as String,
        label: m['label'] as String,
        host: m['host'] as String,
        port: m['port'] as int,
        username: m['username'] as String,
        password: m['password'] as String?,
        privateKeyPath: m['private_key_path'] as String?,
        privateKeyPassphrase: m['private_key_passphrase'] as String?,
        profileId: m['profile_id'] as String?,
        lastConnected: m['last_connected'] != null
            ? DateTime.parse(m['last_connected'] as String)
            : null,
        terminalType: (m['terminal_type'] as String?) ?? 'pty',
      );

  @override
  List<Object?> get props => [
        id,
        label,
        host,
        port,
        username,
        password,
        privateKeyPath,
        privateKeyPassphrase,
        terminalType
      ];
}

// ─────────────────────────────────────────────
// CREDENTIAL PROFILE
// ─────────────────────────────────────────────

class CredentialProfile extends Equatable {
  final String id;
  final String name;
  final String username;
  final String? password;
  final String? privateKeyPath;
  final String? privateKeyPassphrase;
  final DateTime createdAt;

  const CredentialProfile({
    required this.id,
    required this.name,
    required this.username,
    this.password,
    this.privateKeyPath,
    this.privateKeyPassphrase,
    required this.createdAt,
  });

  factory CredentialProfile.create({
    required String name,
    required String username,
    String? password,
    String? privateKeyPath,
    String? privateKeyPassphrase,
  }) =>
      CredentialProfile(
        id: _uuid.v4(),
        name: name,
        username: username,
        password: password,
        privateKeyPath: privateKeyPath,
        privateKeyPassphrase: privateKeyPassphrase,
        createdAt: DateTime.now(),
      );

  CredentialProfile copyWith({
    String? name,
    String? username,
    String? password,
    String? privateKeyPath,
    String? privateKeyPassphrase,
  }) =>
      CredentialProfile(
        id: id,
        name: name ?? this.name,
        username: username ?? this.username,
        password: password ?? this.password,
        privateKeyPath: privateKeyPath ?? this.privateKeyPath,
        privateKeyPassphrase: privateKeyPassphrase ?? this.privateKeyPassphrase,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'username': username,
        'password': password,
        'private_key_path': privateKeyPath,
        'private_key_passphrase': privateKeyPassphrase,
        'created_at': createdAt.toIso8601String(),
      };

  factory CredentialProfile.fromMap(Map<String, dynamic> m) =>
      CredentialProfile(
        id: m['id'] as String,
        name: m['name'] as String,
        username: m['username'] as String,
        password: m['password'] as String?,
        privateKeyPath: m['private_key_path'] as String?,
        privateKeyPassphrase: m['private_key_passphrase'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, name, username];
}

// ─────────────────────────────────────────────
// KEYMAP BINDING
// ─────────────────────────────────────────────

class KeymapBinding extends Equatable {
  final String id;
  final String label;         // e.g. "Paste"
  final String action;        // e.g. "paste" | "copy" | "clear" | "send:<text>"
  final bool ctrl;
  final bool shift;
  final bool alt;
  final String key;           // e.g. "v", "c", "F1"
  final bool isDefault;       // built-in binding

  const KeymapBinding({
    required this.id,
    required this.label,
    required this.action,
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
    required this.key,
    this.isDefault = false,
  });

  factory KeymapBinding.create({
    required String label,
    required String action,
    bool ctrl = false,
    bool shift = false,
    bool alt = false,
    required String key,
  }) =>
      KeymapBinding(
        id: _uuid.v4(),
        label: label,
        action: action,
        ctrl: ctrl,
        shift: shift,
        alt: alt,
        key: key,
        isDefault: false,
      );

  KeymapBinding copyWith({
    String? label,
    String? action,
    bool? ctrl,
    bool? shift,
    bool? alt,
    String? key,
  }) =>
      KeymapBinding(
        id: id,
        label: label ?? this.label,
        action: action ?? this.action,
        ctrl: ctrl ?? this.ctrl,
        shift: shift ?? this.shift,
        alt: alt ?? this.alt,
        key: key ?? this.key,
        isDefault: isDefault,
      );

  String get shortcutLabel {
    final parts = <String>[];
    if (ctrl) parts.add('Ctrl');
    if (shift) parts.add('Shift');
    if (alt) parts.add('Alt');
    parts.add(key.toUpperCase());
    return parts.join('+');
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'action': action,
        'ctrl': ctrl ? 1 : 0,
        'shift': shift ? 1 : 0,
        'alt': alt ? 1 : 0,
        'key': key,
        'is_default': isDefault ? 1 : 0,
      };

  factory KeymapBinding.fromMap(Map<String, dynamic> m) => KeymapBinding(
        id: m['id'] as String,
        label: m['label'] as String,
        action: m['action'] as String,
        ctrl: (m['ctrl'] as int) == 1,
        shift: (m['shift'] as int) == 1,
        alt: (m['alt'] as int) == 1,
        key: m['key'] as String,
        isDefault: (m['is_default'] as int) == 1,
      );

  @override
  List<Object?> get props => [id, ctrl, shift, alt, key];
}

// Default keybindings shipped with the app
List<KeymapBinding> defaultKeybindings() => [
      KeymapBinding(
        id: 'default-copy',
        label: 'Copy',
        action: 'copy',
        ctrl: true,
        shift: true,
        key: 'c',
        isDefault: true,
      ),
      KeymapBinding(
        id: 'default-paste',
        label: 'Paste',
        action: 'paste',
        ctrl: true,
        shift: true,
        key: 'v',
        isDefault: true,
      ),
      KeymapBinding(
        id: 'default-paste-standard',
        label: 'Paste (Standard)',
        action: 'paste',
        ctrl: true,
        key: 'v',
        isDefault: true,
      ),
      KeymapBinding(
        id: 'default-clear',
        label: 'Clear screen',
        action: 'clear',
        ctrl: true,
        key: 'l',
        isDefault: true,
      ),
      KeymapBinding(
        id: 'default-interrupt',
        label: 'Interrupt (Ctrl+C)',
        action: 'send:\x03',
        ctrl: true,
        key: 'c',
        isDefault: true,
      ),
      KeymapBinding(
        id: 'default-copy-all',
        label: 'Copy all',
        action: 'copy_all',
        ctrl: true,
        key: 'a',
        isDefault: true,
      ),
    ];

// ─────────────────────────────────────────────
// COMMAND HISTORY ENTRY
// ─────────────────────────────────────────────

class CommandHistoryEntry extends Equatable {
  final String id;
  final String serverId;
  final String command;
  final String output;       // trimmed terminal output for this command
  final DateTime executedAt;
  final int exitCode;

  const CommandHistoryEntry({
    required this.id,
    required this.serverId,
    required this.command,
    required this.output,
    required this.executedAt,
    this.exitCode = 0,
  });

  factory CommandHistoryEntry.create({
    required String serverId,
    required String command,
    required String output,
    int exitCode = 0,
  }) =>
      CommandHistoryEntry(
        id: _uuid.v4(),
        serverId: serverId,
        command: command,
        output: output,
        executedAt: DateTime.now(),
        exitCode: exitCode,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'server_id': serverId,
        'command': command,
        'output': output,
        'executed_at': executedAt.toIso8601String(),
        'exit_code': exitCode,
      };

  factory CommandHistoryEntry.fromMap(Map<String, dynamic> m) =>
      CommandHistoryEntry(
        id: m['id'] as String,
        serverId: m['server_id'] as String,
        command: m['command'] as String,
        output: m['output'] as String,
        executedAt: DateTime.parse(m['executed_at'] as String),
        exitCode: (m['exit_code'] as int?) ?? 0,
      );

  @override
  List<Object?> get props => [id, command, executedAt];
}
