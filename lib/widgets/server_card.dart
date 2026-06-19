// lib/widgets/server_card.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/ssh_service.dart';
import '../utils/theme.dart';

// Note: This widget is now largely superseded by the _buildServerListItem in HomeScreen
// but I'm updating it for consistency in case it's used elsewhere.

class ServerCard extends StatelessWidget {
  final Server server;
  final SshConnectionState connectionState;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ServerCard({
    super.key,
    required this.server,
    required this.connectionState,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grayBorder),
      ),
      child: InkWell(
        onTap: onConnect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('>_', style: TextStyle(color: AppTheme.graySecondary, fontSize: 18)),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(server.host, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('${server.username}@${server.host}', style: TextStyle(color: AppTheme.graySecondary, fontSize: 12)),
                  ],
                ),
              ),
              if (server.label.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: AppTheme.grayBorder)),
                  child: Text(server.label.toUpperCase(), style: TextStyle(fontSize: 8, color: AppTheme.graySecondary)),
                ),
              const SizedBox(width: 24),
              OutlinedButton(
                onPressed: onConnect,
                child: const Text('CONNECT ->', style: TextStyle(fontSize: 10)),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.more_vert, size: 18, color: AppTheme.graySecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
