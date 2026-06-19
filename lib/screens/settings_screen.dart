// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/keymap_bloc.dart';
import '../models/models.dart';
import '../utils/theme.dart';
import '../widgets/disclaimer_banner.dart';
import 'donate_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    context.read<KeymapBloc>().add(LoadKeybindings());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: const Text('SETTINGS'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'KEYBINDINGS'), Tab(text: 'GENERAL')],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabs,
            children: const [_KeybindingsTab(), _GeneralTab()],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: DisclaimerBanner(
              onDonate: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DonateScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeybindingsTab extends StatelessWidget {
  const _KeybindingsTab();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KeymapBloc, KeymapState>(
      builder: (ctx, state) {
        final bindings = state is KeymapLoaded ? state.bindings : <KeymapBinding>[];
        return ListView(
          padding: const EdgeInsets.all(40),
          children: [
            Row(children: [
              const Text('KEYBOARD SHORTCUTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const Spacer(),
              TextButton(onPressed: () => ctx.read<KeymapBloc>().add(ResetDefaultKeybindings()), child: const Text('RESET DEFAULTS')),
            ]),
            Divider(color: AppTheme.grayBorder, thickness: 0.5),
            const SizedBox(height: 24),
            ...bindings.map((b) => _BindingTile(binding: b)),
          ],
        );
      },
    );
  }
}

class _BindingTile extends StatelessWidget {
  final KeymapBinding binding;
  const _BindingTile({required this.binding});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.grayBorder)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(binding.label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text('ACTION: ${binding.action}', style: TextStyle(color: AppTheme.graySecondary, fontSize: 11)),
        ])),
        Text(binding.shortcutLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        _SettingsTile(title: 'VERSION', subtitle: '0.0.1 (Open Source)'),
        const SizedBox(height: 24),
        const Text('ABOUT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppTheme.graySecondary)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: AppTheme.grayBorder)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Promplity is a free and open-source SSH/SFTP client.\nAll donations go exclusively to project development.',
                style: TextStyle(color: AppTheme.grayMuted, fontSize: 11, height: 1.6),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => launchUrl(Uri.parse('https://github.com/egogoule/promplity'), mode: LaunchMode.externalApplication),
                child: const Text(
                  'github.com/egogoule/promplity',
                  style: TextStyle(color: AppTheme.primaryBlue, fontSize: 11, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SettingsTile({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.grayBorder)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(subtitle, style: TextStyle(color: AppTheme.graySecondary, fontSize: 11)),
        ])),
        Icon(Icons.chevron_right, color: AppTheme.graySecondary, size: 18),
      ]),
    );
  }
}
