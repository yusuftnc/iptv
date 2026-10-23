import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/saved_playlist.dart';
import '../services/app_settings.dart';
import '../services/m3u_parser.dart';
import '../services/playlist_content.dart';
import '../services/storage_service.dart';
import 'm3u_list_screen.dart';
import 'player_screen.dart';

class M3uAddScreen extends StatefulWidget {
  const M3uAddScreen({super.key});

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

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_busy) return false;
    if (_fromFile) {
      return _nameController.text.trim().isNotEmpty && _file != null;
    }
    if (_urlController.text.trim().isEmpty) return false;
    if (_askForName && _nameController.text.trim().isEmpty) return false;
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

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final name = _nameController.text.trim();
    try {
      final M3uParseResult parsed;
      String m3uUrl = '';
      String m3uPath = '';
      List<int>? fileBytes;

      if (_fromFile) {
        fileBytes = await _fileBytes(_file!);
        parsed = parseM3u(_decode(fileBytes));
      } else {
        m3uUrl = _urlController.text.trim();
        final uri = Uri.tryParse(m3uUrl);
        final scheme = uri?.scheme.toLowerCase();
        if (uri == null || (scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
          setState(() => _error = AppText.get('listAddressInvalid'));
          return;
        }
        if (isDirectMediaUrl(m3uUrl) || await PlaylistContent.looksLikeMedia(m3uUrl)) {
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
      }

      if (_fromFile && !parsed.isValid) {
        setState(() => _error = 'Geçersiz liste.');
        return;
      }

      if (fileBytes != null) {
        m3uPath = await PlaylistContent.copyPickedFile(playlistId: id, bytes: fileBytes);
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
      await _openParsed(playlist, parsed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppText.get(_fromFile ? 'fileFailed' : 'listFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: const Text('M3U'),
        backgroundColor: context.accent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            dismissKeyboard();
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 36, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Icon(Icons.featured_play_list_outlined, size: 80, color: context.accent),
          const SizedBox(height: 30),
          if (_fromFile || _askForName) ...[
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
              ButtonSegment(value: true, label: Text(AppText.get('file')), icon: const Icon(Icons.folder_open)),
              ButtonSegment(value: false, label: Text(AppText.get('address')), icon: const Icon(Icons.link)),
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
              label: Text(_file?.name ?? AppText.get('pickFile')),
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
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(AppText.get(_fromFile ? 'add' : 'open'), style: const TextStyle(fontSize: 16)),
          ),
            ],
          ),
        ),
    );
  }
}
