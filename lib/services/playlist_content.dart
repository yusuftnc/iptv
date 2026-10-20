import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/saved_playlist.dart';
import 'm3u_parser.dart';

class PlaylistContent {
  static Future<M3uParseResult> load(SavedPlaylist playlist) async {
    final text = playlist.isRemoteM3u
        ? await _download(playlist.m3uUrl)
        : await _readFile(playlist.m3uPath);
    return parseM3u(text);
  }

  static Future<String> copyPickedFile({
    required String playlistId,
    required List<int> bytes,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/playlists');
    await folder.create(recursive: true);
    final file = File('${folder.path}/$playlistId.m3u');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> deleteLocalFile(SavedPlaylist playlist) async {
    if (playlist.m3uPath.isEmpty) return;
    final file = File(playlist.m3uPath);
    if (await file.exists()) {
      await file.delete();
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

  static Future<String> _readFile(String path) async {
    final bytes = await File(path).readAsBytes();
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }
}
