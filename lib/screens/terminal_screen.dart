// lib/screens/terminal_screen.dart
// SSH terminal emulator with command history, auto-scroll during selection,
// uptime display, SFTP access, and keyboard shortcut support
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xterm/xterm.dart';
import 'package:xterm/src/core/buffer/cell_offset.dart';

import '../bloc/keymap_bloc.dart';
import '../bloc/server_bloc.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../repositories/database.dart';
import '../services/ssh_service.dart';
import '../utils/theme.dart';
import '../widgets/command_history_panel.dart';
import 'sftp_screen.dart';

class TerminalScreen extends StatefulWidget {
  final Server server;
  final SshSession session;

  const TerminalScreen({
    super.key,
    required this.server,
    required this.session,
  });

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late SshSession _currentSession;
  late final TerminalController _termController;
  final FocusNode _terminalFocusNode = FocusNode();
  bool _historyPanelOpen = false;
  final _historyRepo = HistoryRepository(AppDatabase.instance);
  List<CommandHistoryEntry> _history = [];
  bool _isSimpleMode = false;
  final _scrollController = ScrollController();
  final _terminalViewKey = GlobalKey();
  bool _isAutoScrolling = false;
  bool _showHistory = false;
  CellOffset? _selectionBase;
  Offset? _lastPointerPosition;
  
  StreamSubscription<SshConnectionState>? _stateSub;
  StreamSubscription? _historySub;
  Timer? _scrollTimer;
  Timer? _uptimeTimer;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    _isSimpleMode = widget.server.terminalType == 'pty';
    _termController = TerminalController();
    _loadHistory();
    _initSessionListeners();
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Size? _getTerminalViewSize() {
    final renderObj = _terminalViewKey.currentContext?.findRenderObject();
    if (renderObj is RenderBox) return renderObj.size;
    return null;
  }

  /// Starts auto-scroll when pointer is near top/bottom edge during text selection.
  /// Scroll speed increases as pointer gets closer to the edge.
  void _startAutoScroll(Offset localPosition, Size size) {
    if (_isAutoScrolling) return;
    _isAutoScrolling = true;

    const edgeSize = 50.0;
    const scrollSpeed = 50.0;
    double delta = 0;

    if (localPosition.dy < edgeSize) {
      delta = -scrollSpeed * (1.0 - localPosition.dy / edgeSize);
    } else if (localPosition.dy > size.height - edgeSize) {
      delta = scrollSpeed * (1.0 - (size.height - localPosition.dy) / edgeSize);
    }

    if (delta != 0 && _scrollController.hasClients) {
      _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (_scrollController.hasClients && mounted && _isAutoScrolling) {
          final newPixels = (_scrollController.position.pixels + delta).clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.position.jumpTo(newPixels);
          WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSelection());
        }
      });
    }
  }

  /// Restores selection after auto-scroll using buffer coordinates.
  /// The gesture handler overwrites selection with wrong coords after scroll,
  /// so we recalculate using stored _selectionBase and current pointer position.
  void _restoreSelection() {
    if (!_isAutoScrolling || _selectionBase == null || _lastPointerPosition == null) return;
    final terminal = _currentSession.terminal;
    if (terminal == null) return;
    final tvSize = _getTerminalViewSize();
    if (tvSize == null) return;

    const padding = 16.0;
    final cellWidth = tvSize.width / terminal.viewWidth;
    final cellHeight = tvSize.height / terminal.viewHeight;
    final scrollOffset = _scrollController.hasClients ? _scrollController.position.pixels : 0.0;

    final col = ((_lastPointerPosition!.dx - padding) / cellWidth).floor().clamp(0, terminal.viewWidth - 1);
    final row = ((_lastPointerPosition!.dy - padding + scrollOffset) / cellHeight).floor().clamp(0, terminal.buffer.lines.length - 1);

    _termController.setSelection(
      terminal.buffer.createAnchorFromOffset(_selectionBase!),
      terminal.buffer.createAnchorFromOffset(CellOffset(col, row)),
    );
  }

  void _stopAutoScroll() {
    if (!_isAutoScrolling) return;
    _isAutoScrolling = false;
    _selectionBase = null;
    _lastPointerPosition = null;
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  void _initSessionListeners() {
    _stateSub?.cancel();
    _historySub?.cancel();

    _stateSub = _currentSession.stateStream.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });

    _historySub = _currentSession.historyStream.listen((event) {
      final entry = CommandHistoryEntry.create(
        serverId: widget.server.id,
        command: event.command,
        output: event.output,
      );
      _historyRepo.insert(entry);
      if (mounted) setState(() => _history = [entry, ..._history]);
    });
  }

  Future<void> _loadHistory() async {
    final h = await _historyRepo.getForServer(widget.server.id);
    if (mounted) setState(() => _history = h);
  }

  Future<void> _clearHistory() async {
    await _historyRepo.clearForServer(widget.server.id);
    if (mounted) setState(() => _history = []);
  }

  String _formatUptime(DateTime? connectedAt) {
    if (connectedAt == null) return '--';
    final diff = DateTime.now().difference(connectedAt);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  void _handleAction(String action) {
    final ssh = context.read<SshService>();
    switch (action) {
      case 'copy':
        if (!_isSimpleMode) {
          final selection = _termController.selection;
          if (selection != null) {
            final selected = _currentSession.terminal?.buffer.getText(selection);
            if (selected != null && selected.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: selected));
              _showSnack('Copied to clipboard');
            }
          }
        }
      case 'copy_all':
        final terminal = _currentSession.terminal;
        if (terminal != null && !_isSimpleMode) {
          final sb = StringBuffer();
          final lines = terminal.buffer.lines;
          for (var i = 0; i < lines.length; i++) {
            sb.writeln(lines[i].toString());
          }
          final allText = sb.toString();
          if (allText.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: allText));
            _showSnack('All console text copied');
          }
        }
      case 'paste':
        Future.delayed(const Duration(milliseconds: 150), () async {
          final data = await Clipboard.getData('text/plain');
          if (data?.text != null) {
            ssh.sendInput(widget.server.id, data!.text!);
          }
        });
      case 'clear':
        _currentSession.terminal?.write('\x1b[2J\x1b[H');
      default:
        if (action.startsWith('send:')) {
          ssh.sendInput(widget.server.id, action.substring(5));
        }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        backgroundColor: AppTheme.primaryBlue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  /// Handles keyboard input: checks keymap shortcuts first, then sends
  /// characters directly to SSH stdin for immediate display (bypasses xterm
  /// internal buffering to reduce input latency).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final keymapState = context.read<KeymapBloc>().state;
    if (keymapState is! KeymapLoaded) return KeyEventResult.ignored;

    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final key = event.logicalKey.keyLabel.toLowerCase();

    for (final binding in keymapState.bindings) {
      if (binding.ctrl == ctrl &&
          binding.shift == shift &&
          binding.alt == alt &&
          binding.key.toLowerCase() == key) {
        _handleAction(binding.action);
        return KeyEventResult.handled;
      }
    }

    if (!ctrl && !alt && event.character != null && event.character!.isNotEmpty) {
      final ssh = context.read<SshService>();
      ssh.sendInput(widget.server.id, event.character!);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- TERMINAL TOOLBAR ---
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.grayBorder, width: 0.5)),
          ),
          child: Row(
            children: [
              Text(widget.server.host, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('|', style: TextStyle(color: AppTheme.grayMuted)),
              ),
              Text('${widget.server.username}@${widget.server.host}', style: TextStyle(color: AppTheme.graySecondary, fontSize: 12)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(border: Border.all(color: AppTheme.grayBorder)),
                child: Row(
                  children: [
                    Container(width: 4, height: 4, color: AppTheme.white),
                    const SizedBox(width: 6),
                    Text('UPTIME: ${_formatUptime(_currentSession.connectedAt)}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.white)),
                  ],
                ),
              ),
              const Spacer(),
              _ToolbarButton(
                icon: Icons.history,
                label: 'HISTORY',
                onTap: () => setState(() => _showHistory = !_showHistory),
              ),
              const SizedBox(width: 8),
              _ToolbarButton(
                icon: Icons.folder_outlined,
                label: 'SFTP',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SftpScreen(server: widget.server, session: _currentSession))),
              ),
              const SizedBox(width: 8),
              _ToolbarButton(
                icon: Icons.power_settings_new,
                label: 'DISCONNECT',
                onTap: () {
                  // Set session state to disconnected
                  _currentSession.state = SshConnectionState.disconnected;
                  // Dispatch bloc event using BlocProvider for stability
                  BlocProvider.of<ServerBloc>(context).add(DisconnectFromServer(widget.server.id));
                },
              ),
            ],
          ),
        ),
        // --- TERMINAL WINDOW ---
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _buildTerminal(),
                    if (_currentSession.state == SshConnectionState.disconnected)
                      _buildDisconnectedOverlay(),
                  ],
                ),
              ),
              if (_showHistory)
                CommandHistoryPanel(
                  history: _history,
                  onSendCommand: (cmd) {
                    final pty = _currentSession.ptySession;
                    if (pty != null) {
                      _currentSession.notifyCommand(cmd);
                      pty.stdin.add(Uint8List.fromList('$cmd\n'.codeUnits));
                    }
                  },
                  onClear: _clearHistory,
                  onClose: () => setState(() => _showHistory = false),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTerminal() {
    final terminal = _currentSession.terminal;
    if (terminal == null) return const Center(child: CircularProgressIndicator());

    return Listener(
      onPointerDown: (event) {
        final terminal = _currentSession.terminal;
        if (terminal == null) return;
        final tvSize = _getTerminalViewSize();
        if (tvSize == null) return;

        const padding = 16.0;
        final cellWidth = tvSize.width / terminal.viewWidth;
        final cellHeight = tvSize.height / terminal.viewHeight;
        final scrollOffset = _scrollController.hasClients ? _scrollController.position.pixels : 0.0;

        final col = ((event.localPosition.dx - padding) / cellWidth).floor().clamp(0, terminal.viewWidth - 1);
        final row = ((event.localPosition.dy - padding + scrollOffset) / cellHeight).floor().clamp(0, terminal.buffer.lines.length - 1);
        _selectionBase = CellOffset(col, row);
        _lastPointerPosition = event.localPosition;
      },
      onPointerMove: (event) {
        _lastPointerPosition = event.localPosition;
        final tvSize = _getTerminalViewSize();
        if (tvSize != null && _selectionBase != null) {
          final localPosition = event.localPosition;
          final edgeSize = 50.0;
          if (localPosition.dy < edgeSize || localPosition.dy > tvSize.height - edgeSize) {
            _startAutoScroll(localPosition, Size(tvSize.width, tvSize.height));
          } else {
            _stopAutoScroll();
          }
        }
      },
      onPointerUp: (_) => _stopAutoScroll(),
      onPointerCancel: (_) => _stopAutoScroll(),
      child: TerminalView(
        key: _terminalViewKey,
        terminal,
        controller: _termController,
        scrollController: _scrollController,
        focusNode: _terminalFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) => _onKey(node, event),
        hardwareKeyboardOnly: true,
        theme: TerminalTheme(
          cursor: AppTheme.white,
          selection: Color(0x44FFFFFF),
          foreground: AppTheme.white,
          background: AppTheme.black,
          black: Color(0xFF000000),
          white: Color(0xFFFFFFFF),
          red: Color(0xFFFF5555),
          green: Color(0xFF50FA7B),
          yellow: Color(0xFFF1FA8C),
          blue: Color(0xFF6272A4),
          magenta: Color(0xFFFF79C6),
          cyan: Color(0xFF8BE9FD),
          brightBlack: Color(0xFF44475A),
          brightWhite: Color(0xFFFFFFFF),
          brightRed: Color(0xFFFF6E6E),
          brightGreen: Color(0xFF69FF94),
          brightYellow: Color(0xFFFFFF87),
          brightBlue: Color(0xFFD6ACFF),
          brightMagenta: Color(0xFFFF92DF),
          brightCyan: Color(0xFFA4FFFF),
          searchHitBackground: Color(0xFFFFFF00),
          searchHitBackgroundCurrent: Color(0xFFFFA500),
          searchHitForeground: Color(0xFF000000),
        ),
        padding: const EdgeInsets.all(16),
        textStyle: const TerminalStyle(fontSize: 14, fontFamily: 'monospace'),
      ),
    );
  }

  Widget _buildDisconnectedOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 40, color: AppTheme.graySecondary),
            const SizedBox(height: 24),
            const Text('SESSION DISCONNECTED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => _reconnect(),
              child: const Text('RECONNECT'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reconnect() async {
    final ssh = context.read<SshService>();
    await ssh.disconnect(widget.server.id);
    final newSession = await ssh.connect(widget.server);
    if (mounted) {
      setState(() => _currentSession = newSession);
      _initSessionListeners();
    }
  }

  @override
  void dispose() {
    _uptimeTimer?.cancel();
    _scrollTimer?.cancel();
    _stateSub?.cancel();
    _historySub?.cancel();
    _termController.dispose();
    _terminalFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppTheme.grayBorder),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.graySecondary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 10, color: AppTheme.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
