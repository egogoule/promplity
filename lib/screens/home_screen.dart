// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/server_bloc.dart';
import '../models/models.dart';
import '../services/ssh_service.dart';
import '../utils/theme.dart';
import 'connect_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(Server, SshSession) onConnect;

  const HomeScreen({super.key, required this.onConnect});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _search = '';
  final _quickConnectCtrl = TextEditingController();

  void _onEdit(BuildContext context, Server server) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ConnectScreen(existingServer: server)),
    ).then((_) => context.read<ServerBloc>().add(LoadServers()));
  }

  @override
  void initState() {
    super.initState();
    context.read<ServerBloc>().add(LoadServers());
  }

  void _handleQuickConnect() {
    final input = _quickConnectCtrl.text.trim();
    if (input.isEmpty) return;
    
    _quickConnectCtrl.clear();
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'JUST NOW';
    if (diff.inMinutes < 60) return '${diff.inMinutes}M AGO';
    if (diff.inHours < 24) return '${diff.inHours}H AGO';
    if (diff.inDays < 30) return '${diff.inDays}D AGO';
    return '${(diff.inDays / 30).floor()}MO AGO';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ServerBloc, ServerState>(
      listener: (context, state) {
        if (state is ServerConnected) {
          final server = state.servers.firstWhere((s) => s.id == state.serverId);
          widget.onConnect(server, state.session);
        }
      },
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CONNECT', style: TextStyle(color: AppTheme.graySecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              _buildQuickConnectField(),
              const SizedBox(height: 48),
              _buildSavedHeader(),
              Divider(height: 1, color: AppTheme.grayBorder, thickness: 0.5),
              const SizedBox(height: 12),
              Expanded(
                child: BlocBuilder<ServerBloc, ServerState>(
                  builder: (context, state) {
                    final filtered = _search.isEmpty
                        ? state.servers
                        : state.servers.where((s) =>
                            s.label.toLowerCase().contains(_search.toLowerCase()) ||
                            s.host.toLowerCase().contains(_search.toLowerCase())).toList();

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _buildServerListItem(filtered[i], state.connectionStates[filtered[i].id]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickConnectField() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grayBorder),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.chevron_right, color: AppTheme.graySecondary, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: _quickConnectCtrl,
              onSubmitted: (_) => _handleQuickConnect(),
              style: TextStyle(color: AppTheme.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'ssh user@hostname -p 22',
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            onPressed: _handleQuickConnect,
            icon: Icon(Icons.arrow_forward, color: AppTheme.grayMuted, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('SAVED CONNECTIONS', style: TextStyle(color: AppTheme.graySecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConnectScreen())),
              icon: Icon(Icons.add, size: 20, color: AppTheme.white),
            ),
            const SizedBox(width: 8),
            Icon(Icons.search, size: 14, color: AppTheme.grayMuted),
            const SizedBox(width: 8),
            SizedBox(
              width: 150,
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServerListItem(Server server, SshConnectionState? connState) {
    final isConnecting = connState == SshConnectionState.connecting;
    final isError = connState == SshConnectionState.error;
    final isConnected = connState == SshConnectionState.connected;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isError ? Colors.red : (isConnecting ? AppTheme.white : AppTheme.grayBorder)),
      ),
      child: InkWell(
        onTap: isConnecting ? null : () => context.read<ServerBloc>().add(ConnectToServer(server)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(isConnecting ? '...' : '>_', style: TextStyle(color: isConnecting ? AppTheme.white : AppTheme.graySecondary, fontSize: 18)),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(server.host, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      isConnecting ? 'CONNECTING...' : (isError ? 'CONNECTION FAILED' : '${server.username}@${server.host}'), 
                      style: TextStyle(color: isError ? Colors.redAccent : AppTheme.graySecondary, fontSize: 12)
                    ),
                  ],
                ),
              ),
              if (server.label.isNotEmpty && !isConnecting)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: AppTheme.grayBorder)),
                  child: Text(server.label.toUpperCase(), style: const TextStyle(fontSize: 8, color: AppTheme.graySecondary, letterSpacing: 1)),
                ),
              const SizedBox(width: 24),
              if (isConnecting)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.white))
              else ...[
                if (isConnected)
                  const Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.green),
                      SizedBox(width: 4),
                      Text('CONNECTED', style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  )
                else if (server.lastConnected != null)
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 12, color: AppTheme.grayMuted),
                      const SizedBox(width: 4),
                      Text(_formatTimeAgo(server.lastConnected!), style: const TextStyle(fontSize: 9, color: AppTheme.grayMuted)),
                    ],
                  ),
                const SizedBox(width: 24),
                OutlinedButton(
                  onPressed: () => context.read<ServerBloc>().add(ConnectToServer(server)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.grayMuted),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Row(
                    children: [
                      Text('CONNECT', style: TextStyle(fontSize: 10, color: AppTheme.white, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 14, color: AppTheme.white),
                    ],
                  ),
                ),
                _ServerMenuButton(
                  server: server,
                  onEdit: () => _onEdit(context, server),
                  onDelete: () => context.read<ServerBloc>().add(DeleteServer(server.id)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerMenuButton extends StatelessWidget {
  final Server server;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServerMenuButton({required this.server, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: AppTheme.black,
      shape: const RoundedRectangleBorder(side: BorderSide(color: AppTheme.grayBorder)),
      icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.graySecondary),
      onSelected: (val) {
        if (val == 'edit') onEdit();
        if (val == 'delete') onDelete();
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'edit', child: Text('EDIT', style: TextStyle(fontSize: 12))),
        const PopupMenuItem(value: 'delete', child: Text('DELETE', style: TextStyle(color: Colors.redAccent, fontSize: 12))),
      ],
    );
  }
}
