// lib/widgets/simple_terminal.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/ssh_service.dart';
import '../utils/theme.dart';

class SimpleTerminalWidget extends StatelessWidget {
  final SshSession session;
  final Server server;
  const SimpleTerminalWidget({super.key, required this.session, required this.server});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.black,
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: Text('STANDALONE TERMINAL MODE', style: TextStyle(color: AppTheme.graySecondary, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
    );
  }
}
