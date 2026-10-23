import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/saved_playlist.dart';
import 'm3u_parser.dart';

class PlaylistContent {
  static Future<M3uParseResult> load(SavedPlaylist playlist) async {
    if (playlist.isRemoteM3u) {
      return parseM3u(await _download(playlist.m3uUrl));
    }
    return parseM3u(await _readLocal(playlist));
  }

  static Future<String> copyPickedFile({
    required String playlistId,
    required List<int> bytes,
  }) async {
    final file = File('${(await _documents()).path}/playlists/$playlistId.m3u');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> deleteLocalFile(SavedPlaylist playlist) async {
    for (final path in await _candidatePaths(playlist)) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<bool> looksLikeMedia(String url) async {
    try {
      final response = await http
          .head(Uri.parse(url), headers: const {'User-Agent': 'SUTU Player'})
          .timeout(const Duration(seconds: 15));
      final type = (response.headers['content-type'] ?? '').toLowerCase();
      return type.startsWith('video/') || type.startsWith('audio/');
    } catch (_) {
      return false;
    }
  }

  static Future<Directory> _documents() => getApplicationDocumentsDirectory();

  static Future<String> _readLocal(SavedPlaylist playlist) async {
    Object? lastError;
    for (final path in await _candidatePaths(playlist)) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        try {
          return utf8.decode(bytes);
        } on FormatException {
          return latin1.decode(bytes);
        }
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('Liste dosyası yok');
  }

  /// Kayıtlı tam yol, uygulama kabı değişince bozulur.
  /// Dosya adı ve playlist kimliğiyle güncel Documents klasöründe de aranır.
  static Future<List<String>> _candidatePaths(SavedPlaylist playlist) async {
    final paths = <String>[];
    final raw = playlist.m3uPath.trim();
    if (raw.startsWith('file://')) {
      paths.add(Uri.parse(raw).toFilePath());
    } else if (raw.isNotEmpty && !raw.contains('://')) {
      paths.add(raw);
    }

    final dir = await _documents();
    if (playlist.id.isNotEmpty) {
      paths.add('${dir.path}/playlists/${playlist.id}.m3u');
    }
    final name = raw.split('/').where((part) => part.isNotEmpty).lastOrNull;
    if (name != null && name.isNotEmpty) {
      paths.add('${dir.path}/playlists/$name');
    }
    return paths.toSet().toList();
  }

  static Future<String> _download(String url) async {
    final response = await http
        .get(
          Uri.parse(url),
          headers: const {'User-Agent': 'SUTU Player'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Liste alınamadı (${response.statusCode})');
    }
    return response.body;
  }
}
