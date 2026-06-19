// lib/screens/unlock_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/database.dart';
import '../utils/theme.dart';

class UnlockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const UnlockScreen({super.key, required this.onUnlocked});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _passCtrl = TextEditingController();
  String? _error;

  void _submit() async {
    final pass = _passCtrl.text.trim();
    if (pass.isEmpty) return;

    try {
      await AppDatabase.instance.init(pass);
      widget.onUnlocked();
    } catch (e) {
      setState(() => _error = 'Invalid master password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(border: Border.all(color: AppTheme.grayBorder)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: AppTheme.white),
              const SizedBox(height: 24),
              const Text(
                'PROMPLITY',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              const Text(
                'MASTER PASSWORD',
                style: TextStyle(color: AppTheme.graySecondary, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                onSubmitted: (_) => _submit(),
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter password...',
                  errorText: _error,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('UNLOCK', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
