// lib/main.dart
// Main application entry point for Promplity SSH Client
// Manages tab-based UI, SSH sessions, and disclaimer banner
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:window_manager/window_manager.dart';

import 'bloc/keymap_bloc.dart';
import 'bloc/profile_bloc.dart';
import 'bloc/server_bloc.dart';
import 'repositories/database.dart';
import 'repositories/repositories.dart';
import 'services/ssh_service.dart';
import 'utils/theme.dart';
import 'models/models.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/terminal_screen.dart';
import 'screens/unlock_screen.dart';
import 'screens/donate_screen.dart';
import 'widgets/disclaimer_banner.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop support
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // await windowManager.ensureInitialized();
    // WindowOptions windowOptions = const WindowOptions(
    //   size: Size(1280, 800),
    //   center: true,
    //   backgroundColor: Colors.transparent,
    //   skipTaskbar: false,
    //   titleStyle: TitleBarStyle.normal,
    //   title: 'PROMPLITY',
    // );
    // windowManager.waitUntilReadyToShow(windowOptions, () async {
    //   await windowManager.show();
    //   await windowManager.focus();
    // });
  }

  // Initialize database automatically with a default key for desktop UX
  await AppDatabase.instance.init('default_desktop_key');

  runApp(const PromplityApp());
}

class TabData {
  final String id;
  final String title;
  final String subtitle;
  final Server server;
  final SshSession session;

  TabData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.server,
    required this.session,
  });
}

class PromplityApp extends StatefulWidget {
  const PromplityApp({super.key});

  @override
  State<PromplityApp> createState() => _PromplityAppState();
}

class _PromplityAppState extends State<PromplityApp> {
  final List<TabData> _activeTabs = [];
  String _activeTabId = 'HOME';
  bool _isUnlocked = true; // Auto-unlock for desktop UX

  void _onUnlocked() {
    setState(() => _isUnlocked = true);
  }

  void _openTerminal(Server server, SshSession session) {
    setState(() {
      final tabId = 'term-${server.id}';
      if (!_activeTabs.any((t) => t.id == tabId)) {
        _activeTabs.add(TabData(
          id: tabId,
          title: server.host,
          subtitle: '${server.username}@${server.host}',
          server: server,
          session: session,
        ));
      }
      _activeTabId = tabId;
    });
  }

  void _closeTab(BuildContext context, String id) {
    final tabIndex = _activeTabs.indexWhere((t) => t.id == id);
    if (tabIndex != -1) {
      final tab = _activeTabs[tabIndex];
      // Use the provided context which is below the MultiBlocProvider
      BlocProvider.of<ServerBloc>(context).add(DisconnectFromServer(tab.server.id));
      setState(() {
        _activeTabs.removeAt(tabIndex);
        if (_activeTabId == id) {
          _activeTabId = 'HOME';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = AppDatabase.instance;
    final sshService = SshService();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: db),
        RepositoryProvider.value(value: sshService),
        RepositoryProvider(create: (ctx) => ServerRepository(db)),
        RepositoryProvider(create: (ctx) => ProfileRepository(db)),
        RepositoryProvider(create: (ctx) => KeymapRepository(db)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (ctx) => ServerBloc(repo: ctx.read<ServerRepository>(), ssh: ctx.read<SshService>())),
          BlocProvider(create: (ctx) => ProfileBloc(ctx.read<ProfileRepository>())),
          BlocProvider(create: (ctx) => KeymapBloc(ctx.read<KeymapRepository>())),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Promplity Client',
          theme: AppTheme.dark(),
          home: !_isUnlocked 
            ? UnlockScreen(onUnlocked: _onUnlocked)
            : Builder(
                builder: (context) => _MainScaffold(
                  activeTabId: _activeTabId,
                  activeTabs: _activeTabs,
                  onTabChanged: (id) => setState(() => _activeTabId = id),
                  onTabClosed: (id) => _closeTab(context, id),
                  onConnect: _openTerminal,
                ),
              ),
        ),
      ),
    );
  }
}

class _MainScaffold extends StatefulWidget {
  final String activeTabId;
  final List<TabData> activeTabs;
  final Function(String) onTabChanged;
  final Function(String) onTabClosed;
  final Function(Server, SshSession) onConnect;

  const _MainScaffold({
    required this.activeTabId,
    required this.activeTabs,
    required this.onTabChanged,
    required this.onTabClosed,
    required this.onConnect,
  });

  @override
  State<_MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<_MainScaffold> {
  bool _showDisclaimer = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showDisclaimer && mounted) {
        setState(() => _showDisclaimer = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                height: 48,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.grayBorder, width: 0.5)),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.terminal, size: 18, color: AppTheme.white),
                          SizedBox(width: 10),
                          Text(
                            'PROMPLITY',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _AppTab(
                              label: 'HOME',
                              isActive: widget.activeTabId == 'HOME',
                              onTap: () => widget.onTabChanged('HOME'),
                            ),
                            ...widget.activeTabs.map((tab) => _AppTab(
                                  label: tab.title,
                                  isActive: widget.activeTabId == tab.id,
                                  onTap: () => widget.onTabChanged(tab.id),
                                  onClose: () => widget.onTabClosed(tab.id),
                                )),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined, color: AppTheme.graySecondary, size: 18),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: widget.activeTabId == 'HOME'
                    ? HomeScreen(onConnect: widget.onConnect)
                    : _buildTerminalView(),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: DisclaimerBanner(
              onDonate: () =>                   Navigator.push(context, MaterialPageRoute(builder: (_) => const DonateScreen())),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalView() {
    final tab = widget.activeTabs.firstWhere((t) => t.id == widget.activeTabId);
    return TerminalScreen(
      server: tab.server,
      session: tab.session,
    );
  }
}

class _AppTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _AppTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppTheme.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.white : AppTheme.graySecondary,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: onClose,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: isActive ? AppTheme.white : AppTheme.graySecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
