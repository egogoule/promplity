// lib/screens/sftp_screen.dart
// Dual-pane SFTP file manager (similar to FileZilla)
// Features: upload, download, edit in external editor, create/delete folders,
// rename, copy path, auto-sync changes from external editor back to server
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:dartssh2/dartssh2.dart';
import 'package:open_file_plus/open_file_plus.dart';

import '../models/models.dart';
import '../services/ssh_service.dart';
import '../utils/theme.dart';

class SftpScreen extends StatefulWidget {
  final Server server;
  final SshSession session;

  const SftpScreen({
    super.key,
    required this.server,
    required this.session,
  });

  @override
  State<SftpScreen> createState() => _SftpScreenState();
}

class _SftpScreenState extends State<SftpScreen> {
  late SftpClient _sftp;
  bool _loading = true;
  String? _error;

  String _localPath = '';
  String _remotePath = '/';
  late final TextEditingController _localPathController;
  late final TextEditingController _remotePathController;

  List<FileSystemEntity> _localFiles = [];
  List<SftpName> _remoteFiles = [];

  bool _isTransferring = false;
  double _progress = 0;
  String _currentTransferFile = '';

  @override
  void initState() {
    super.initState();
    _localPath = Platform.isWindows
        ? Platform.environment['USERPROFILE'] ?? 'C:\\'
        : Platform.environment['HOME'] ?? '/';
    _localPathController = TextEditingController(text: _localPath);
    _remotePathController = TextEditingController(text: _remotePath);
    _initSftp();
  }

  @override
  void dispose() {
    _localPathController.dispose();
    _remotePathController.dispose();
    for (final sub in _watchers.values) {
      sub.cancel();
    }
    _watchers.clear();
    super.dispose();
  }

  Future<void> _initSftp() async {
    try {
      _sftp = widget.session.sftp ??= await widget.session.client.sftp();
      await _refreshRemote();
      await _refreshLocal();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshLocal() async {
    try {
      final dir = Directory(_localPath);
      final list = await dir.list().toList();
      list.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
      });
      if (mounted) setState(() => _localFiles = list);
    } catch (e) {
      _showSnack('Error reading local dir: $e');
    }
  }

  Future<void> _refreshRemote() async {
    try {
      final list = await _sftp.listdir(_remotePath);
      final filtered = list.where((e) => e.filename != '.' && e.filename != '..').toList();
      filtered.sort((a, b) {
        final aIsDir = a.attr.isDirectory;
        final bIsDir = b.attr.isDirectory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
      });

      if (mounted) setState(() {
        _remoteFiles = filtered;
      });
    } catch (e) {
      _showSnack('Error reading remote dir: $e');
    }
  }

  // ── Upload ──────────────────────────────────────────────────────────────

  /// Uploads a local file to the current remote directory.
  /// Reads entire file into memory, writes in 64KB chunks for progress tracking.
  Future<void> _upload(FileSystemEntity file) async {
    if (file is! File) return;
    setState(() {
      _isTransferring = true;
      _currentTransferFile = p.basename(file.path);
      _progress = 0;
    });

    try {
      final remoteFilePath = p.posix.join(_remotePath, p.basename(file.path));
      final remoteFile = await _sftp.open(
        remoteFilePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
      );

      final totalSize = await file.length();
      final data = await file.readAsBytes();
      int uploaded = 0;
      const chunkSize = 64 * 1024;

      while (uploaded < totalSize) {
        final end = (uploaded + chunkSize).clamp(0, totalSize);
        final chunk = data.sublist(uploaded, end);
        await remoteFile.writeBytes(chunk);
        uploaded = end;
        if (mounted) setState(() => _progress = uploaded / totalSize);
      }
      await remoteFile.close();
      _showSnack('Uploaded ${p.basename(file.path)}');
      _refreshRemote();
    } catch (e) {
      _showSnack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  // ── Download ────────────────────────────────────────────────────────────

  /// Downloads a remote file to the local directory.
  /// Uses buffered IOSink with 64KB flush threshold for efficient disk writes.
  Future<void> _download(SftpName remoteFile) async {
    if (remoteFile.attr.isDirectory) return;
    setState(() {
      _isTransferring = true;
      _currentTransferFile = remoteFile.filename;
      _progress = 0;
    });

    try {
      final localFilePath = p.join(_localPath, remoteFile.filename);
      final file = await _sftp.open(p.posix.join(_remotePath, remoteFile.filename));
      final int totalSize = remoteFile.attr.size ?? 1;
      int downloaded = 0;
      final localFile = File(localFilePath);
      final IOSink sink = localFile.openWrite();
      final buffer = BytesBuilder();
      const flushThreshold = 64 * 1024;

      await for (final chunk in file.read()) {
        buffer.add(chunk);
        downloaded += chunk.length;
        if (buffer.length >= flushThreshold) {
          sink.add(buffer.toBytes());
          buffer.clear();
        }
        if (mounted) setState(() => _progress = downloaded / totalSize);
      }
      sink.add(buffer.toBytes());
      await sink.close();
      await file.close();
      _showSnack('SUCCESS: File saved to $localFilePath');
      _refreshLocal();
    } catch (e) {
      _showSnack('Download failed: $e');
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  // ── Edit remote file (download → open in notepad → watch → upload back) ─

  final Map<String, StreamSubscription> _watchers = {};

  /// Downloads remote file to temp directory, opens in system editor,
  /// watches for changes and prompts to upload back to server.
  Future<void> _editRemoteFile(SftpName remoteFile) async {
    final fullRemotePath = p.posix.join(_remotePath, remoteFile.filename);

    setState(() {
      _isTransferring = true;
      _currentTransferFile = remoteFile.filename;
      _progress = 0;
    });

    try {
      final tempDir = Directory.systemTemp.createTempSync('ssh_edit_');
      final localFile = File(p.join(tempDir.path, remoteFile.filename));

      final sftpFile = await _sftp.open(fullRemotePath);

      final int totalSize = remoteFile.attr.size ?? 1;
      int downloaded = 0;
      final sink = localFile.openWrite();
      final buffer = BytesBuilder();
      const flushThreshold = 64 * 1024;

      await for (final chunk in sftpFile.read()) {
        buffer.add(chunk);
        downloaded += chunk.length;
        if (buffer.length >= flushThreshold) {
          sink.add(buffer.toBytes());
          buffer.clear();
        }
        if (mounted) setState(() => _progress = downloaded / totalSize);
      }
      sink.add(buffer.toBytes());
      await sink.close();
      await sftpFile.close();

      _showSnack('Opening ${remoteFile.filename}...');
      await OpenFile.open(localFile.path);

      await _watchers[localFile.path]?.cancel();

      final watcher = localFile.parent.watch().listen((event) async {
        if (!event.path.endsWith(remoteFile.filename)) return;

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        if (await localFile.exists()) {
          _askToUpload(localFile, fullRemotePath, remoteFile.filename);
        }
      });

      _watchers[localFile.path] = watcher;
    } catch (e) {
      _showSnack('Failed to edit: $e');
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<void> _editLocalFile(FileSystemEntity entity) async {
    if (entity is! File) return;
    final filename = p.basename(entity.path);

    try {
      _showSnack('Opening $filename...');
      await OpenFile.open(entity.path);

      await _watchers[entity.path]?.cancel();

      final watcher = entity.parent.watch().listen((event) async {
        if (!event.path.endsWith(filename)) return;

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        if (await entity.exists()) {
          _askToUploadLocal(entity);
        }
      });

      _watchers[entity.path] = watcher;
    } catch (e) {
      _showSnack('Failed to open: $e');
    }
  }

  Future<void> _askToUploadLocal(File localFile) async {
    final filename = p.basename(localFile.path);
    final remotePath = p.posix.join(_remotePath, filename);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.black,
        shape: const RoundedRectangleBorder(side: BorderSide(color: AppTheme.grayBorder)),
        title: const Text('FILE CHANGED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text(
          'Файл "$filename" был изменён. Загрузить на сервер?',
          style: const TextStyle(color: AppTheme.graySecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('НЕТ'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ДА'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _uploadToRemotePath(localFile, remotePath);
    }
  }

  Future<void> _askToUpload(File localFile, String fullRemotePath, String filename) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.black,
        shape: const RoundedRectangleBorder(side: BorderSide(color: AppTheme.grayBorder)),
        title: const Text('FILE CHANGED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text(
          'Файл "$filename" был изменён во внешнем редакторе. Обновить его на сервере?',
          style: const TextStyle(color: AppTheme.graySecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('НЕТ'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ДА'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _uploadToRemotePath(localFile, fullRemotePath);
    }
  }

  Future<void> _uploadToRemotePath(File file, String fullRemotePath) async {
    final filename = p.basename(fullRemotePath);
    _showSnack('Uploading $filename...');

    try {
      final remoteFile = await _sftp.open(
        fullRemotePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
      );

      final data = await file.readAsBytes();
      int offset = 0;
      const chunkSize = 64 * 1024;

      while (offset < data.length) {
        final end = (offset + chunkSize).clamp(0, data.length);
        final chunk = data.sublist(offset, end);
        await remoteFile.writeBytes(chunk);
        offset = end;
      }
      await remoteFile.close();
      _showSnack('File $filename updated on server');
      _refreshRemote();
    } catch (e) {
      _showSnack('Upload failed: $e');
    }
  }

  // ── Create folder ───────────────────────────────────────────────────────

  Future<void> _createLocalFolder() async {
    final name = await _showInputDialog('NEW FOLDER', 'Enter folder name:');
    if (name == null || name.trim().isEmpty) return;

    try {
      final dir = Directory(p.join(_localPath, name.trim()));
      await dir.create();
      _showSnack('Folder "$name" created');
      _refreshLocal();
    } catch (e) {
      _showSnack('Failed to create folder: $e');
    }
  }

  Future<void> _createRemoteFolder() async {
    final name = await _showInputDialog('NEW FOLDER', 'Enter folder name:');
    if (name == null || name.trim().isEmpty) return;

    try {
      final fullPath = p.posix.join(_remotePath, name.trim());
      await _sftp.mkdir(fullPath);
      _showSnack('Folder "$name" created on server');
      _refreshRemote();
    } catch (e) {
      _showSnack('Failed to create folder: $e');
    }
  }

  // ── Create file ─────────────────────────────────────────────────────────

  Future<void> _createLocalFile() async {
    final name = await _showInputDialog('NEW FILE', 'Enter file name:');
    if (name == null || name.trim().isEmpty) return;

    try {
      final file = File(p.join(_localPath, name.trim()));
      await file.writeAsString('');
      _showSnack('File "$name" created');
      _refreshLocal();
    } catch (e) {
      _showSnack('Failed to create file: $e');
    }
  }

  Future<void> _createRemoteFile() async {
    final name = await _showInputDialog('NEW FILE', 'Enter file name:');
    if (name == null || name.trim().isEmpty) return;

    try {
      final fullPath = p.posix.join(_remotePath, name.trim());
      final remoteFile = await _sftp.open(
        fullPath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
      );
      await remoteFile.close();
      _showSnack('File "$name" created on server');
      _refreshRemote();
    } catch (e) {
      _showSnack('Failed to create file: $e');
    }
  }

  // ── Rename ──────────────────────────────────────────────────────────────

  Future<void> _renameLocal(FileSystemEntity entity) async {
    final oldName = p.basename(entity.path);
    final newName = await _showInputDialog('RENAME', 'Enter new name:', initialValue: oldName);
    if (newName == null || newName.trim().isEmpty || newName.trim() == oldName) return;

    try {
      final newPath = p.join(p.dirname(entity.path), newName.trim());
      await entity.rename(newPath);
      _showSnack('Renamed to "$newName"');
      _refreshLocal();
    } catch (e) {
      _showSnack('Failed to rename: $e');
    }
  }

  Future<void> _renameRemote(SftpName remoteFile) async {
    final oldName = remoteFile.filename;
    final newName = await _showInputDialog('RENAME', 'Enter new name:', initialValue: oldName);
    if (newName == null || newName.trim().isEmpty || newName.trim() == oldName) return;

    try {
      final oldPath = p.posix.join(_remotePath, oldName);
      final newPath = p.posix.join(_remotePath, newName.trim());
      await _sftp.rename(oldPath, newPath);
      _showSnack('Renamed to "$newName"');
      _refreshRemote();
    } catch (e) {
      _showSnack('Failed to rename: $e');
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────

  Future<void> _deleteLocal(FileSystemEntity entity) async {
    final name = p.basename(entity.path);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.black,
        shape: const RoundedRectangleBorder(side: BorderSide(color: AppTheme.grayBorder)),
        title: const Text('CONFIRM DELETE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text(
          'Delete "$name"?',
          style: const TextStyle(color: AppTheme.graySecondary, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await entity.delete(recursive: true);
        _showSnack('Deleted "$name"');
        _refreshLocal();
      } catch (e) {
        _showSnack('Delete failed: $e');
      }
    }
  }

  Future<void> _deleteRemote(SftpName remoteFile) async {
    final name = remoteFile.filename;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.black,
        shape: const RoundedRectangleBorder(side: BorderSide(color: AppTheme.grayBorder)),
        title: const Text('CONFIRM DELETE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text(
          'Delete "$name" from server?',
          style: const TextStyle(color: AppTheme.graySecondary, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final fullPath = p.posix.join(_remotePath, name);
        if (remoteFile.attr.isDirectory) {
          await _sftp.rmdir(fullPath);
        } else {
          await _sftp.remove(fullPath);
        }
        _showSnack('Deleted "$name"');
        _refreshRemote();
      } catch (e) {
        _showSnack('Delete failed: $e');
      }
    }
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────

  Future<String?> _showInputDialog(String title, String hint, {String? initialValue}) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.black,
        shape: const RoundedRectangleBorder(side: BorderSide(color: AppTheme.grayBorder)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.grayMuted, fontSize: 12),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.grayBorder)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.white)),
          ),
          onSubmitted: (val) => Navigator.pop(ctx, val),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        backgroundColor: AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: Text('SFTP: ${widget.server.host}', style: const TextStyle(fontSize: 12)),
        bottom: _isTransferring ? PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: LinearProgressIndicator(value: _progress, color: AppTheme.white, backgroundColor: AppTheme.grayBorder),
        ) : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.white))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)))
              : Row(
                  children: [
                    Expanded(child: _buildPane(isLocal: true)),
                    const VerticalDivider(width: 1, color: AppTheme.grayBorder),
                    Expanded(child: _buildPane(isLocal: false)),
                  ],
                ),
    );
  }

  Widget _buildPane({required bool isLocal}) {
    final path = isLocal ? _localPath : _remotePath;
    final items = isLocal ? _localFiles : _remoteFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.grayBorder.withValues(alpha: 0.3),
          child: Row(
            children: [
              Text(isLocal ? 'LOCAL SITE' : 'REMOTE SITE', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.graySecondary)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined, size: 14),
                tooltip: 'New folder',
                onPressed: isLocal ? _createLocalFolder : _createRemoteFolder,
              ),
              IconButton(
                icon: const Icon(Icons.note_add_outlined, size: 14),
                tooltip: 'New file',
                onPressed: isLocal ? _createLocalFile : _createRemoteFile,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 14),
                tooltip: 'Go up',
                onPressed: () {
                  if (isLocal) {
                    final parent = p.dirname(_localPath);
                    if (parent != _localPath) setState(() { _localPath = parent; _localPathController.text = parent; });
                    _refreshLocal();
                  } else {
                    final parent = p.posix.dirname(_remotePath);
                    if (parent != _remotePath) setState(() { _remotePath = parent; _remotePathController.text = parent; });
                    _refreshRemote();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 14),
                tooltip: 'Refresh',
                onPressed: isLocal ? _refreshLocal : _refreshRemote,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.grayBorder, width: 0.5))),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: isLocal ? _localPathController : _remotePathController,
                  style: const TextStyle(fontSize: 11, color: AppTheme.grayMuted, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isEmpty) return;
                    if (isLocal) {
                      final dir = Directory(val.trim());
                      if (dir.existsSync()) {
                        setState(() { _localPath = val.trim(); _localPathController.text = val.trim(); });
                        _refreshLocal();
                      } else {
                        _showSnack('Directory not found: ${val.trim()}');
                      }
                    } else {
                      setState(() { _remotePath = val.trim(); _remotePathController.text = val.trim(); });
                      _refreshRemote();
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 12),
                tooltip: 'Copy path',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: path));
                  _showSnack('Path copied');
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              final isDir = isLocal ? item is Directory : (item as SftpName).attr.isDirectory;
              final name = isLocal ? p.basename((item as FileSystemEntity).path) : (item as SftpName).filename;

              return ListTile(
                dense: true,
                onTap: () {
                  if (isDir) {
                    if (isLocal) {
                      setState(() { _localPath = (item as FileSystemEntity).path; _localPathController.text = _localPath; });
                      _refreshLocal();
                    } else {
                      setState(() { _remotePath = p.posix.join(_remotePath, name); _remotePathController.text = _remotePath; });
                      _refreshRemote();
                    }
                  } else if (!isLocal) {
                    _editRemoteFile(item as SftpName);
                  } else {
                    _editLocalFile(item as FileSystemEntity);
                  }
                },
                leading: Icon(
                  isDir ? Icons.folder_open : Icons.insert_drive_file_outlined,
                  size: 16,
                  color: isDir ? AppTheme.white : AppTheme.graySecondary,
                ),
                title: Text(name, style: TextStyle(fontSize: 13, color: isDir ? AppTheme.white : AppTheme.graySecondary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isDir) IconButton(
                      icon: Icon(isLocal ? Icons.upload : Icons.download, size: 14),
                      tooltip: isLocal ? 'Upload' : 'Download',
                      onPressed: () => isLocal ? _upload(item as FileSystemEntity) : _download(item as SftpName),
                    ),
                    _SftpMenuButton(
                      item: item,
                      isLocal: isLocal,
                      isDir: isDir,
                      onEdit: !isDir ? () {
                        if (isLocal) {
                          _editLocalFile(item as FileSystemEntity);
                        } else {
                          _editRemoteFile(item as SftpName);
                        }
                      } : null,
                      onRename: () {
                        if (isLocal) {
                          _renameLocal(item as FileSystemEntity);
                        } else {
                          _renameRemote(item as SftpName);
                        }
                      },
                      onDelete: () {
                        if (isLocal) {
                          _deleteLocal(item as FileSystemEntity);
                        } else {
                          _deleteRemote(item as SftpName);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SftpMenuButton extends StatelessWidget {
  final dynamic item;
  final bool isLocal;
  final bool isDir;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback onRename;

  const _SftpMenuButton({
    required this.item,
    required this.isLocal,
    required this.isDir,
    required this.onDelete,
    required this.onRename,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: AppTheme.black,
      shape: const RoundedRectangleBorder(side: BorderSide(color: AppTheme.grayBorder)),
      icon: const Icon(Icons.more_vert, size: 14, color: AppTheme.graySecondary),
      onSelected: (val) {
        if (val == 'delete') onDelete();
        if (val == 'edit') onEdit?.call();
        if (val == 'rename') onRename();
      },
      itemBuilder: (ctx) => [
        if (onEdit != null)
          const PopupMenuItem(value: 'edit', child: Text('OPEN', style: TextStyle(fontSize: 11))),
        const PopupMenuItem(value: 'rename', child: Text('RENAME', style: TextStyle(fontSize: 11))),
        const PopupMenuItem(value: 'delete', child: Text('DELETE', style: TextStyle(color: Colors.redAccent, fontSize: 11))),
      ],
    );
  }
}
