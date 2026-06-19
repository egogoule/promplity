import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';

class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  static const _boostyUrl = 'https://boosty.to/egogoule/donate';
  static const _walletAddress = 'UQAiawglSWOeXBhrq-0RiSorwHjg7QfgvFOiqkesXopGEzZt';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: const Text('SUPPORT THE PROJECT', style: TextStyle(fontSize: 12, letterSpacing: 1)),
        backgroundColor: AppTheme.black,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_border, size: 48, color: AppTheme.primaryBlue),
              const SizedBox(height: 24),
              const Text('DONATE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 3)),
              const SizedBox(height: 12),
              const Text('All funds go exclusively to project development.', style: TextStyle(color: AppTheme.graySecondary, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              _DonateOption(icon: Icons.link, label: 'BOOSTY', subtitle: _boostyUrl, onTap: () => _copyAndOpen(context, _boostyUrl)),
              const SizedBox(height: 16),
              _DonateOption(icon: Icons.account_balance_wallet, label: 'USDT (TON)', subtitle: _walletAddress, onTap: () => _copyAddress(context, _walletAddress)),
            ],
          ),
        ),
      ),
    );
  }

  void _copyAndOpen(BuildContext context, String url) async {
    Clipboard.setData(ClipboardData(text: url));
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opened: $url', style: const TextStyle(fontSize: 12)), backgroundColor: AppTheme.primaryBlue, behavior: SnackBarBehavior.floating));
    }
  }

  void _copyAddress(BuildContext context, String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet address copied!', style: TextStyle(fontSize: 12)), backgroundColor: AppTheme.primaryBlue, behavior: SnackBarBehavior.floating));
  }
}

class _DonateOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _DonateOption({required this.icon, required this.label, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: AppTheme.grayBorder)),
        child: Row(children: [
          Icon(icon, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: AppTheme.grayMuted, fontSize: 11, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
          ])),
          const Icon(Icons.copy, size: 14, color: AppTheme.grayMuted),
        ]),
      ),
    );
  }
}
