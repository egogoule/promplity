// lib/screens/profiles_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/profile_bloc.dart';
import '../models/models.dart';
import '../utils/theme.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(LoadProfiles());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: const Text('CREDENTIAL PROFILES'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.graySecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (ctx, state) {
          final profiles = state is ProfilesLoaded ? state.profiles : <CredentialProfile>[];
          return Column(
            children: [
              Expanded(
                child: profiles.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(border: Border.all(color: AppTheme.grayBorder)),
                          child: Text('NO PROFILES YET', style: TextStyle(color: AppTheme.grayMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      )
                    : Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(40),
                            itemCount: profiles.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _ProfileTile(
                              profile: profiles[i],
                              onEdit: () => _showForm(context, profiles[i]),
                              onDelete: () => context.read<ProfileBloc>().add(DeleteProfile(profiles[i].id)),
                            ),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(40),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _showForm(context, null),
                    child: const Text('CREATE NEW PROFILE'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showForm(BuildContext context, CredentialProfile? profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => BlocProvider.value(
        value: context.read<ProfileBloc>(),
        child: _ProfileForm(existing: profile),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final CredentialProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProfileTile({required this.profile, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.grayBorder)),
      child: Row(children: [
        Text('>_', style: TextStyle(color: AppTheme.graySecondary, fontSize: 18)),
        const SizedBox(width: 24),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profile.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(profile.username, style: TextStyle(color: AppTheme.graySecondary, fontSize: 12)),
          ]),
        ),
        IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), onPressed: onDelete),
      ]),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  final CredentialProfile? existing;
  const _ProfileForm({this.existing});
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController(text: 'root');
  final _passCtrl = TextEditingController();
  final _keyPassCtrl = TextEditingController();
  String? _keyPath;
  bool _useKey = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _nameCtrl.text = p.name;
      _userCtrl.text = p.username;
      _passCtrl.text = p.password ?? '';
      _keyPath = p.privateKeyPath;
      _keyPassCtrl.text = p.privateKeyPassphrase ?? '';
      _useKey = p.privateKeyPath != null;
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final p = widget.existing != null
        ? widget.existing!.copyWith(
            name: _nameCtrl.text.trim(),
            username: _userCtrl.text.trim(),
            password: _useKey ? null : _passCtrl.text,
            privateKeyPath: _useKey ? _keyPath : null,
            privateKeyPassphrase: _useKey ? _keyPassCtrl.text : null,
          )
        : CredentialProfile.create(
            name: _nameCtrl.text.trim(),
            username: _userCtrl.text.trim(),
            password: _useKey ? null : _passCtrl.text,
            privateKeyPath: _useKey ? _keyPath : null,
            privateKeyPassphrase: _useKey ? _keyPassCtrl.text : null,
          );

    if (widget.existing != null) {
      context.read<ProfileBloc>().add(UpdateProfile(p));
    } else {
      context.read<ProfileBloc>().add(AddProfile(p));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 40, right: 40, top: 40, bottom: MediaQuery.of(context).viewInsets.bottom + 40),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.existing != null ? 'EDIT PROFILE' : 'NEW PROFILE', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 32),
          TextFormField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Profile Name')),
          const SizedBox(height: 16),
          TextFormField(controller: _userCtrl, decoration: const InputDecoration(hintText: 'Username')),
          const SizedBox(height: 24),
          Row(children: [
            Text('Auth Method:', style: TextStyle(color: AppTheme.graySecondary, fontSize: 11)),
            const SizedBox(width: 16),
            _ToggleTab(label: 'PASSWORD', selected: !_useKey, onTap: () => setState(() => _useKey = false)),
            const SizedBox(width: 8),
            _ToggleTab(label: 'SSH KEY', selected: _useKey, onTap: () => setState(() => _useKey = true)),
          ]),
          const SizedBox(height: 16),
          if (!_useKey)
            TextFormField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Password'))
          else ...[
            _FilePickerField(path: _keyPath, onTap: () async {
              final r = await FilePicker.platform.pickFiles();
              if (r != null) setState(() => _keyPath = r.files.single.path);
            }),
            const SizedBox(height: 16),
            TextFormField(controller: _keyPassCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Key Passphrase')),
          ],
          const SizedBox(height: 48),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _submit, child: Text(widget.existing != null ? 'SAVE CHANGES' : 'CREATE PROFILE'))),
        ]),
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleTab({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(border: Border.all(color: selected ? AppTheme.white : AppTheme.grayBorder)), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: selected ? AppTheme.white : AppTheme.graySecondary))));
}

class _FilePickerField extends StatelessWidget {
  final String? path;
  final VoidCallback onTap;
  const _FilePickerField({this.path, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: AppTheme.grayBorder)), child: Row(children: [Icon(Icons.key, size: 18, color: path != null ? AppTheme.white : AppTheme.grayMuted), const SizedBox(width: 12), Expanded(child: Text(path ?? 'Select key file...', style: TextStyle(fontSize: 12, color: path != null ? AppTheme.white : AppTheme.grayMuted), overflow: TextOverflow.ellipsis)), const Icon(Icons.folder_open, size: 18, color: AppTheme.graySecondary)])));
}
