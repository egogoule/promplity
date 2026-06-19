// lib/services/ssh_service.dart
// SSH connection management: dartssh2, PTY, key auth, simple mode
// Handles all SSH/SFTP session lifecycle, terminal I/O, and command history tracking

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

import '../models/models.dart';

enum SshConnectionState { disconnected, connecting, connected, error }

/// Represents a single SSH session to a server.
/// Holds the SSH client, PTY session, terminal emulator, SFTP client,
/// and command history buffer for one connected server.
class SshSession {
  final Server server;
  final SSHClient client;
  SSHSession? ptySession;
  Terminal? terminal;
  SftpClient? sftp;

  // Simple-mode stream
  StreamController<String>? simpleOutput;

  SshConnectionState _state = SshConnectionState.connecting;
  String? errorMessage;
  DateTime? connectedAt;

  final _stateController = StreamController<SshConnectionState>.broadcast();
  Stream<SshConnectionState> get stateStream => _stateController.stream;

  SshConnectionState get state => _state;
  set state(SshConnectionState value) {
    if (_state == value) return;
    _state = value;
    if (!_stateController.isClosed) {
      _stateController.add(value);
    }
  }

  // Command history buffer: last command + accumulated output
  String _pendingCommand = '';
  final StringBuffer _outputBuffer = StringBuffer();
  final _historyController = StreamController<({String command, String output})>.broadcast();
  Timer? _flushTimer;

  Stream<({String command, String output})> get historyStream => _historyController.stream;

  SshSession({required this.server, required this.client});

  /// Called when user types a command (on Enter press).
  /// Flushes any previous pending command, then stores the new one.
  void notifyCommand(String cmd) {
    if (_pendingCommand.isNotEmpty) flushHistory();
    _pendingCommand = cmd.trim();
    _outputBuffer.clear();
    _outputStarted = false;
  }

  bool _outputStarted = false;

  /// Appends server output to the current command's output buffer.
  /// Strips ANSI escape sequences and detects prompt to skip prompt lines.
  void appendOutput(String chunk) {
    if (_pendingCommand.isEmpty) return;

    final cleaned = _stripAnsi(chunk);

    if (!_outputStarted) {
      final lines = cleaned.split('\n');
      for (final line in lines) {
        final trimmed = line.trimRight();
        if (trimmed.endsWith('#') || trimmed.endsWith('\$') || trimmed.endsWith('%')) {
          _outputStarted = true;
          continue;
        }
        if (trimmed.isNotEmpty && _outputStarted) {
          _outputBuffer.write(cleaned);
          _restartFlushTimer();
          return;
        }
      }
      if (!_outputStarted) {
        _outputBuffer.write(cleaned);
        _restartFlushTimer();
      }
    } else {
      _outputBuffer.write(cleaned);
      _restartFlushTimer();
    }
  }

  String _stripAnsi(String input) {
    return input
        .replaceAll(RegExp(r'\x1b\[[0-9;]*[a-zA-Z]'), '')
        .replaceAll(RegExp(r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)'), '')
        .replaceAll(RegExp(r'\x1b\[[\?\d;]*[a-zA-Z]'), '')
        .replaceAll(RegExp(r'\x1b[()][AB012]'), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
        .replaceAll(RegExp(r'\r\n'), '\n')
        .replaceAll(RegExp(r'\r'), '');
  }

  void _restartFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 1500), () {
      flushHistory();
    });
  }

  void flushHistory() {
    _flushTimer?.cancel();
    if (_pendingCommand.isNotEmpty) {
      final output = _outputBuffer.toString();
      _historyController.add((
        command: _pendingCommand,
        output: output.trim(),
      ));
      _pendingCommand = '';
      _outputBuffer.clear();
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _historyController.close();
    _stateController.close();
    simpleOutput?.close();
    ptySession?.close();
    sftp?.close();
    client.close();
  }
}

/// Manages all SSH connections. Each server gets one session tracked by server ID.
/// Handles connection, disconnection, terminal setup, and SFTP client caching.
class SshService {
  final Map<String, SshSession> _sessions = {};

  // ── Connect ─────────────────────────────────────────────────────────────

  /// Establishes SSH connection to a server.
  /// Creates socket, authenticates (password or key), starts terminal session,
  /// and stores the session in _sessions map.
  Future<SshSession> connect(Server server) async {
    // Build socket
    final socket = await SSHSocket.connect(server.host, server.port,
        timeout: const Duration(seconds: 15));

    // Determine auth method
    final List<SSHKeyPair> identities = [];

    if (server.privateKeyPath != null) {
      final keyContent = await File(server.privateKeyPath!).readAsString();
      identities.addAll(SSHKeyPair.fromPem(keyContent));
    }

    final client = SSHClient(
      socket,
      username: server.username,
      identities: identities,
      onPasswordRequest: server.password != null ? () => server.password : null,
    );

    await client.authenticated;

    final session = SshSession(server: server, client: client);
    session.state = SshConnectionState.connected;
    session.connectedAt = DateTime.now();

    // Both PTY and Simple now use xterm terminal emulator
    await _startTerminalSession(session, usePty: server.terminalType == 'pty');

    _sessions[server.id] = session;
    return session;
  }

  // ── Terminal Session (PTY or Simple) ────────────────────────────────────

  Future<void> _startTerminalSession(SshSession session, {required bool usePty}) async {
    final terminal = Terminal(maxLines: 10000);
    session.terminal = terminal;

    if (!usePty) {
      session.simpleOutput = StreamController<String>.broadcast();
    }

    final sshSession = await session.client.shell(
      pty: usePty
          ? SSHPtyConfig(
              type: 'xterm-256color',
              width: 220,
              height: 50,
            )
          : null,
    );
    session.ptySession = sshSession;

    // SSH → Terminal
    sshSession.stdout.cast<List<int>>().transform(utf8.decoder).listen((text) {
      terminal.write(text);
      session.appendOutput(text);
      if (!usePty) session.simpleOutput?.add(text);
    });

    sshSession.stderr.cast<List<int>>().transform(utf8.decoder).listen((text) {
      terminal.write(text);
      if (!usePty) session.simpleOutput?.add(text);
    });

    // Terminal → SSH
    final StringBuffer inputBuffer = StringBuffer();
    int escState = 0;
    terminal.onOutput = (data) {
      sshSession.stdin.add(utf8.encode(data));

      scheduleMicrotask(() {
        for (int i = 0; i < data.length; i++) {
          final char = data[i];
          final code = char.codeUnitAt(0);

          if (escState == 3) {
            escState = 0;
            continue;
          }

          if (escState == 2) {
            if (code >= 0x40 && code <= 0x7E) {
              escState = 0;
            }
            continue;
          }

          if (escState == 1) {
            if (char == '[') {
              escState = 2;
            } else if (char == 'O') {
              escState = 3;
            } else if (code >= 0x40 && code <= 0x7E) {
              escState = 0;
            }
            continue;
          }

          if (code == 0x1B) {
            escState = 1;
            continue;
          }

          if (char == '\r' || char == '\n') {
            final command = inputBuffer.toString().trim();
            if (command.isNotEmpty) {
              session.notifyCommand(command);
            }
            inputBuffer.clear();
          } else if (code == 127 || code == 8) {
            final s = inputBuffer.toString();
            if (s.isNotEmpty) {
              inputBuffer.clear();
              inputBuffer.write(s.substring(0, s.length - 1));
            }
          } else if (code >= 32) {
            inputBuffer.write(char);
          }
        }
      });
    };

    sshSession.done.then((_) {
      final wasConnected = session.state == SshConnectionState.connected;
      session.state = SshConnectionState.disconnected;
      session.flushHistory();
      if (!usePty) session.simpleOutput?.close();

      // Simple auto-reconnect if it was connected and we still have it in sessions
      if (wasConnected && _sessions.containsKey(session.server.id)) {
        Future.delayed(const Duration(seconds: 2), () {
          if (_sessions[session.server.id] == session) {
             connect(session.server);
          }
        });
      }
    });
  }

  // ── Send input ───────────────────────────────────────────────────────────

  void sendInput(String serverId, String data) {
    final session = _sessions[serverId];
    if (session == null || session.ptySession == null) return;
    session.ptySession!.stdin.add(Uint8List.fromList(data.codeUnits));
  }

  void sendCommand(String serverId, String command) {
    final session = _sessions[serverId];
    if (session == null) return;
    session.notifyCommand(command);
    sendInput(serverId, '$command\n');
  }

  // ── Resize PTY ──────────────────────────────────────────────────────────

  void resizePty(String serverId, int width, int height) {
    final session = _sessions[serverId];
    session?.ptySession?.resizeTerminal(width, height);
  }

  /// Returns cached SFTP client or creates a new one.
  /// Pings existing client with timeout to detect stale connections.
  Future<SftpClient> getSftp(String serverId) async {
    final session = _sessions[serverId];
    if (session == null) throw Exception('No active session for $serverId');
    
    // Cache the SFTP client to make subsequent opens instant
    if (session.sftp != null) {
      try {
        // Ping with timeout to check if still alive
        await session.sftp!.listdir('/').timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception('SFTP timeout'),
        ); 
        return session.sftp!;
      } catch (_) {
        session.sftp = null;
      }
    }

    session.sftp = await session.client.sftp();
    return session.sftp!;
  }

  // ── Execute one-shot command ─────────────────────────────────────────────

  Future<String> execute(String serverId, String command) async {
    final session = _sessions[serverId];
    if (session == null) throw Exception('No active session for $serverId');

    final result = await session.client.run(command);
    return String.fromCharCodes(result);
  }

  // ── Disconnect ───────────────────────────────────────────────────────────

  Future<void> disconnect(String serverId) async {
    final session = _sessions.remove(serverId);
    session?.flushHistory();
    session?.dispose();
  }

  SshSession? getSession(String serverId) => _sessions[serverId];

  bool isConnected(String serverId) =>
      _sessions[serverId]?.state == SshConnectionState.connected;

  void dispose() {
    for (final s in _sessions.values) {
      s.dispose();
    }
    _sessions.clear();
  }
}
