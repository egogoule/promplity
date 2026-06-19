import 'package:flutter/material.dart';
import '../utils/theme.dart';

class DisclaimerBanner extends StatefulWidget {
  final VoidCallback onDonate;
  const DisclaimerBanner({super.key, required this.onDonate});

  @override
  State<DisclaimerBanner> createState() => _DisclaimerBannerState();
}

class _DisclaimerBannerState extends State<DisclaimerBanner> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Container(
      width: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.black,
        border: Border.all(color: AppTheme.grayBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline, size: 14, color: AppTheme.grayMuted),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('OPEN SOURCE PROJECT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppTheme.graySecondary)),
            ),
            InkWell(
              onTap: () => setState(() => _visible = false),
              child: const Icon(Icons.close, size: 14, color: AppTheme.grayMuted),
            ),
          ]),
          const SizedBox(height: 10),
          const Text(
            'Free and open-source. The creator assumes no responsibility for its use by others.',
            style: TextStyle(color: AppTheme.grayMuted, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'All donations go exclusively to project development.',
            style: TextStyle(color: AppTheme.graySecondary, fontSize: 10),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onDonate,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryBlue),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('SUPPORT THE PROJECT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
