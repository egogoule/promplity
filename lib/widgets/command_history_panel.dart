import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../utils/theme.dart';

class CommandHistoryPanel extends StatelessWidget {
  final List<CommandHistoryEntry> history;
  final Function(String) onSendCommand;
  final VoidCallback onClose;
  final VoidCallback? onClear;

  const CommandHistoryPanel({super.key, required this.history, required this.onSendCommand, required this.onClose, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppTheme.grayBorder)),
        color: AppTheme.black,
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.grayBorder))),
          child: Row(children: [
            const Icon(Icons.history, size: 14, color: AppTheme.graySecondary),
            const SizedBox(width: 8),
            const Text('COMMAND HISTORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.5, color: AppTheme.graySecondary)),
            const Spacer(),
            if (history.isNotEmpty && onClear != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 14),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.black,
                      shape: const RoundedRectangleBorder(side: BorderSide(color: AppTheme.grayBorder)),
                      title: const Text('CLEAR HISTORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      content: const Text('Delete all command history?', style: TextStyle(color: AppTheme.graySecondary, fontSize: 12)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
                        OutlinedButton(
                          onPressed: () { Navigator.pop(ctx); onClear!(); },
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                          child: const Text('CLEAR', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.close, size: 16), onPressed: onClose, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ),
        Expanded(
          child: history.isEmpty
              ? const Center(child: Text('No commands yet', style: TextStyle(color: AppTheme.grayMuted, fontSize: 12)))
              : ListView.builder(
                  itemCount: history.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (ctx, i) => _HistoryTile(
                    entry: history[i],
                    onSend: () => onSendCommand(history[i].command),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _HistoryTile extends StatefulWidget {
  final CommandHistoryEntry entry;
  final VoidCallback onSend;
  const _HistoryTile({required this.entry, required this.onSend});

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  bool _expanded = false;
  bool _copied = false;

  void _copyOutput() {
    Clipboard.setData(ClipboardData(text: widget.entry.output));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _copyCommand() {
    Clipboard.setData(ClipboardData(text: widget.entry.command));
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hasOutput = entry.output.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grayBorder.withValues(alpha: 0.5)),
        color: _expanded ? AppTheme.grayBorder.withValues(alpha: 0.1) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: hasOutput ? () => setState(() => _expanded = !_expanded) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Text(r'$', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.command,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.white),
                  maxLines: _expanded ? null : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(DateFormat('HH:mm:ss').format(entry.executedAt), style: TextStyle(color: AppTheme.grayMuted, fontSize: 9)),
              if (hasOutput) ...[
                const SizedBox(width: 8),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 14, color: AppTheme.grayMuted),
              ],
            ]),
          ),
        ),
        if (_expanded && hasOutput) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.grayBorder.withValues(alpha: 0.3))),
              color: Colors.black.withValues(alpha: 0.3),
            ),
            child: SelectableText(
              entry.output,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.graySecondary, height: 1.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              _ActionChip(
                icon: _copied ? Icons.check : Icons.copy,
                label: _copied ? 'COPIED' : 'COPY OUTPUT',
                onTap: _copyOutput,
                color: _copied ? Colors.green : null,
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.play_arrow,
                label: 'RE-RUN',
                onTap: widget.onSend,
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionChip({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color ?? AppTheme.grayBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: color ?? AppTheme.graySecondary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color ?? AppTheme.graySecondary, letterSpacing: 0.5)),
        ]),
      ),
    );
  }
}
