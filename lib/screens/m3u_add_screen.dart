import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/saved_playlist.dart';
import '../services/app_settings.dart';
import '../services/m3u_parser.dart';
import '../services/playlist_content.dart';
import '../services/storage_service.dart';
import '../widgets/brand_pulse_logo.dart';
import 'm3u_list_screen.dart';
import 'player_screen.dart';

class M3uAddScreen extends StatefulWidget {
  final SavedPlaylist? existing;

  const M3uAddScreen({super.key, this.existing});

  @override
  State<M3uAddScreen> createState() => _M3uAddScreenState();
}

class _M3uAddScreenState extends State<M3uAddScreen> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  bool _fromFile = true;
  bool _busy = false;
  bool _askForName = false;
  String _error = '';
  PlatformFile? _file;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      if (existing.m3uUrl.isNotEmpty) {
        _fromFile = false;
        _urlController.text = existing.m3uUrl;
      } else {
        _fromFile = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_busy) return false;
    if (_fromFile) {
      if (_nameController.text.trim().isEmpty) return false;
      if (_isEditing && _file == null && (widget.existing?.m3uPath.isNotEmpty ?? false)) {
        return true;
      }
      return _file != null;
    }
    if (_urlController.text.trim().isEmpty) return false;
    if ((_askForName || _isEditing) && _nameController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _pickFile() async {
    dismissKeyboard();
    final result = await FilePicker.pickFiles(
      dialogTitle: 'M3U dosyası seç',
      type: FileType.custom,
      allowedExtensions: const ['m3u', 'm3u8'],
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    setState(() {
      _file = result.files.single;
      _error = '';
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    dismissKeyboard();
    setState(() {
      _busy = true;
      _error = '';
    });

    final id = widget.existing?.id ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final name = _nameController.text.trim();
    try {
      final M3uParseResult parsed;
      String m3uUrl = '';
      String m3uPath = widget.existing?.m3uPath ?? '';
      List<int>? fileBytes;

      if (_fromFile) {
        if (_file != null) {
          fileBytes = await _fileBytes(_file!);
          parsed = parseM3u(_decode(fileBytes));
        } else if (_isEditing && m3uPath.isNotEmpty) {
          parsed = await PlaylistContent.load(widget.existing!);
        } else {
          setState(() => _error = AppText.get('fileFailed'));
          return;
        }
      } else {
        m3uUrl = _urlController.text.trim();
        final uri = Uri.tryParse(m3uUrl);
        final scheme = uri?.scheme.toLowerCase();
        if (uri == null ||
            (scheme != 'http' && scheme != 'https') ||
            uri.host.isEmpty) {
          setState(() => _error = AppText.get('listAddressInvalid'));
          return;
        }
        if (!_isEditing &&
            (isDirectMediaUrl(m3uUrl) ||
                await PlaylistContent.looksLikeMedia(m3uUrl))) {
          if (!mounted) return;
          await _playDirect(m3uUrl);
          return;
        }
        parsed = await PlaylistContent.load(SavedPlaylist(
          id: id,
          name: name,
          kind: 'm3u',
          m3uUrl: m3uUrl,
        ));
        if (!parsed.isValid) {
          setState(() => _error = AppText.get('invalidList'));
          return;
        }
        if (name.isEmpty) {
          setState(() {
            _askForName = true;
            _error = AppText.get('nameNeeded');
          });
          return;
        }
        m3uPath = '';
      }

      if (_fromFile && !parsed.isValid) {
        setState(() => _error = 'Geçersiz liste.');
        return;
      }

      if (fileBytes != null) {
        if (widget.existing != null) {
          await PlaylistContent.deleteLocalFile(widget.existing!);
        }
        m3uPath =
            await PlaylistContent.copyPickedFile(playlistId: id, bytes: fileBytes);
      }

      final playlist = SavedPlaylist(
        id: id,
        name: name,
        kind: 'm3u',
        m3uUrl: m3uUrl,
        m3uPath: m3uPath,
      );
      await StorageService().savePlaylist(playlist);
      if (!mounted) return;
      if (_isEditing) {
        Navigator.pop(context, true);
        return;
      }
      await _openParsed(playlist, parsed);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _error = AppText.get(_fromFile ? 'fileFailed' : 'listFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppText.get('deletePlaylistTitle')),
        content: Text(existing.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppText.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppText.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await PlaylistContent.deleteLocalFile(existing);
    await StorageService().deletePlaylist(existing.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _playDirect(String url) async {
    dismissKeyboard();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          contentId: url,
          streamUrl: url,
          contentType: 'movie',
          name: 'Yayın',
          historyId: url,
          allowFavorite: false,
        ),
      ),
    );
  }

  Future<void> _openParsed(SavedPlaylist playlist, M3uParseResult parsed) async {
    dismissKeyboard();
    if (parsed.isHls) {
      final uri = playlist.m3uPath.isNotEmpty
          ? Uri.file(playlist.m3uPath).toString()
          : playlist.m3uUrl;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            contentId: playlist.id,
            streamUrl: uri,
            contentType: 'live',
            name: playlist.name,
            historyId: playlist.id,
          ),
        ),
      );
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => M3uListScreen(
          title: playlist.name,
          entries: parsed.entries,
        ),
      ),
    );
  }

  Future<List<int>> _fileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) return File(file.path!).readAsBytes();
    throw StateError('Dosya okunamadı');
  }

  String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  String get _fileButtonLabel {
    if (_file != null) return _file!.name;
    if (_isEditing && (widget.existing?.m3uPath.isNotEmpty ?? false)) {
      return AppText.get('keepCurrentFile');
    }
    return AppText.get('pickFile');
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text(_isEditing ? AppText.get('editPlaylist') : 'M3U'),
        backgroundColor: context.accent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            dismissKeyboard();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: AppText.get('delete'),
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 36, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.featured_play_list_outlined,
                size: 80, color: context.accent),
            const SizedBox(height: 30),
            if (_fromFile || _askForName || _isEditing) ...[
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: p.text),
                decoration: InputDecoration(
                  labelText: AppText.get('playlistName'),
                  prefixIcon: Icon(Icons.bookmark_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  filled: true,
                  fillColor: p.field,
                  labelStyle: TextStyle(color: p.label),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
            ],
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                    value: true,
                    label: Text(AppText.get('file')),
                    icon: const Icon(Icons.folder_open)),
                ButtonSegment(
                    value: false,
                    label: Text(AppText.get('address')),
                    icon: const Icon(Icons.link)),
              ],
              selected: {_fromFile},
              onSelectionChanged: (value) {
                setState(() {
                  _fromFile = value.first;
                  _error = '';
                  if (_fromFile) _askForName = false;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_fromFile)
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_fileButtonLabel),
              )
            else
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: TextStyle(color: p.text),
                decoration: InputDecoration(
                  labelText: AppText.get('listAddress'),
                  hintText: 'https://sunucu/liste.m3u',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  filled: true,
                  fillColor: p.field,
                  labelStyle: TextStyle(color: p.label),
                  hintStyle: TextStyle(color: p.muted),
                ),
                onChanged: (_) => setState(() {}),
              ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSave ? _save : null,
              style: context.primaryButtonStyle,
            child: _busy
                ? const BrandPulseLogo(size: 28)
                : Text(
                      AppText.get(_isEditing
                          ? 'save'
                          : (_fromFile ? 'add' : 'open')),
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
