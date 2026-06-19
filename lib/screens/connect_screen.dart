// lib/screens/connect_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/profile_bloc.dart';
import '../bloc/server_bloc.dart';
import '../models/models.dart';
import '../utils/theme.dart';

class ConnectScreen extends StatefulWidget {
  final Server? existingServer;
  const ConnectScreen({super.key, this.existingServer});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _userCtrl = TextEditingController(text: 'root');
  final _passCtrl = TextEditingController();
  final _keyPassCtrl = TextEditingController();

  String? _keyPath;
  String? _selectedProfileId;
  String _terminalType = 'pty';
  bool _useKey = false;
  bool _obscurePass = true;

  bool get _isEditing => widget.existingServer != null;

  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(LoadProfiles());
    final s = widget.existingServer;
    if (s != null) {
      _labelCtrl.text = s.label;
      _hostCtrl.text = s.host;
      _portCtrl.text = s.port.toString();
      _userCtrl.text = s.username;
      _passCtrl.text = s.password ?? '';
      _keyPath = s.privateKeyPath;
      _keyPassCtrl.text = s.privateKeyPassphrase ?? '';
      _selectedProfileId = s.profileId;
      _terminalType = s.terminalType;
      _useKey = s.privateKeyPath != null;
    }
  }

  void _applyProfile(CredentialProfile profile) {
    setState(() {
      _selectedProfileId = profile.id;
      _userCtrl.text = profile.username;
      if (profile.password != null) _passCtrl.text = profile.password!;
      if (profile.privateKeyPath != null) {
        _keyPath = profile.privateKeyPath;
        _useKey = true;
      }
      if (profile.privateKeyPassphrase != null) {
        _keyPassCtrl.text = profile.privateKeyPassphrase!;
      }
    });
  }

  Future<void> _pickKeyFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() => _keyPath = result.files.single.path);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final host = _hostCtrl.text.trim();
    final label = _labelCtrl.text.trim().isEmpty ? host : _labelCtrl.text.trim();

    final server = _isEditing
        ? widget.existingServer!.copyWith(
            label: label,
            host: host,
            port: int.parse(_portCtrl.text),
            username: _userCtrl.text.trim(),
            password: _useKey ? null : _passCtrl.text,
            privateKeyPath: _useKey ? _keyPath : null,
            privateKeyPassphrase: _useKey && _keyPassCtrl.text.isNotEmpty
                ? _keyPassCtrl.text
                : null,
            profileId: _selectedProfileId,
            terminalType: _terminalType,
          )
        : Server.create(
            label: label,
            host: host,
            port: int.parse(_portCtrl.text),
            username: _userCtrl.text.trim(),
            password: _useKey ? null : _passCtrl.text,
            privateKeyPath: _useKey ? _keyPath : null,
            privateKeyPassphrase: _useKey && _keyPassCtrl.text.isNotEmpty
                ? _keyPassCtrl.text
                : null,
            profileId: _selectedProfileId,
            terminalType: _terminalType,
          );

    if (_isEditing) {
      context.read<ServerBloc>().add(UpdateServer(server));
    } else {
      context.read<ServerBloc>().add(AddServer(server));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'EDIT CONNECTION' : 'NEW CONNECTION',
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.graySecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('SERVER DETAILS'),
                  const SizedBox(height: 16),
                  _Field(controller: _labelCtrl, hint: 'Label (e.g. Production DB)'),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(flex: 4, child: _Field(controller: _hostCtrl, hint: 'Host / IP', validator: (v) => v!.isEmpty ? 'Required' : null)),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _Field(controller: _portCtrl, hint: 'Port')),
                  ]),
                  const SizedBox(height: 32),
                  const _SectionLabel('CREDENTIALS'),
                  const SizedBox(height: 16),
                  _Field(controller: _userCtrl, hint: 'Username'),
                  const SizedBox(height: 16),
                  Row(children: [
                    Text('Auth Method:', style: TextStyle(color: AppTheme.graySecondary, fontSize: 11)),
                    const SizedBox(width: 16),
                    _ToggleTab(label: 'PASSWORD', selected: !_useKey, onTap: () => setState(() => _useKey = false)),
                    _ToggleTab(label: 'SSH KEY', selected: _useKey, onTap: () => setState(() => _useKey = true)),
                  ]),
                  const SizedBox(height: 16),
                  if (!_useKey)
                    _Field(controller: _passCtrl, hint: 'Password', obscure: _obscurePass)
                  else ...[
                    _FilePickerField(path: _keyPath, onTap: _pickKeyFile),
                    const SizedBox(height: 16),
                    _Field(controller: _keyPassCtrl, hint: 'Key passphrase (optional)', obscure: true),
                  ],
                  const SizedBox(height: 32),
                  const _SectionLabel('TERMINAL TYPE'),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _TypeButton(label: 'PTY (FULL)', selected: _terminalType == 'pty', onTap: () => setState(() => _terminalType = 'pty'))),
                    const SizedBox(width: 12),
                    Expanded(child: _TypeButton(label: 'SIMPLE', selected: _terminalType == 'simple', onTap: () => setState(() => _terminalType = 'simple'))),
                  ]),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Text(_isEditing ? 'SAVE CHANGES' : 'SAVE & CONNECT'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [_labelCtrl, _hostCtrl, _portCtrl, _userCtrl, _passCtrl, _keyPassCtrl]) {
      c.dispose();
    }
    super.dispose();
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(color: AppTheme.graySecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final String? Function(String?)? validator;
  const _Field({required this.controller, required this.hint, this.obscure = false, this.validator});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscure,
    validator: validator,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(hintText: hint),
  );
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: selected ? AppTheme.white : AppTheme.grayBorder),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: selected ? AppTheme.white : AppTheme.graySecondary)),
    ),
  );
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: selected ? AppTheme.white : AppTheme.grayBorder),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? AppTheme.white : AppTheme.graySecondary)),
    ),
  );
}

class _FilePickerField extends StatelessWidget {
  final String? path;
  final VoidCallback onTap;
  const _FilePickerField({this.path, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.grayBorder)),
      child: Row(children: [
        Icon(Icons.key, size: 18, color: path != null ? AppTheme.white : AppTheme.grayMuted),
        const SizedBox(width: 12),
        Expanded(child: Text(path ?? 'Select key file...', style: TextStyle(fontSize: 12, color: path != null ? AppTheme.white : AppTheme.grayMuted), overflow: TextOverflow.ellipsis)),
        Icon(Icons.folder_open, size: 18, color: AppTheme.graySecondary),
      ]),
    ),
  );
}
