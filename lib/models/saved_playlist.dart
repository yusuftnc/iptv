import '../services/iptv_service.dart';

class SavedPlaylist {
  final String id;
  final String name;

  /// `xtream` veya `m3u`.
  final String kind;
  final String host;
  final String port;
  final String username;
  final String password;

  /// M3U adresle eklendiyse listenin internet adresi.
  final String m3uUrl;

  /// M3U dosyayla eklendiyse uygulamanın kopyaladığı dosya yolu.
  final String m3uPath;

  const SavedPlaylist({
    required this.id,
    required this.name,
    required this.kind,
    this.host = '',
    this.port = '',
    this.username = '',
    this.password = '',
    this.m3uUrl = '',
    this.m3uPath = '',
  });

  bool get isXtream => kind == 'xtream';
  bool get isRemoteM3u => kind == 'm3u' && m3uUrl.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'kind': kind,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'm3uUrl': m3uUrl,
      'm3uPath': m3uPath,
    };
  }

  factory SavedPlaylist.fromJson(Map<String, dynamic> json) {
    return SavedPlaylist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      host: json['host']?.toString() ?? '',
      port: json['port']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      m3uUrl: json['m3uUrl']?.toString() ?? '',
      m3uPath: json['m3uPath']?.toString() ?? '',
    );
  }
}

/// Eski tek Xtream kaydını playlist listesine taşır. Kayıt yoksa null.
SavedPlaylist? playlistFromLegacyCredentials(Map<String, String> credentials) {
  final host = credentials['host'] ?? '';
  final username = credentials['username'] ?? '';
  final password = credentials['password'] ?? '';
  if (host.trim().isEmpty || username.trim().isEmpty || password.isEmpty) {
    return null;
  }

  var server = host.trim();
  try {
    server = IptvService.normalizeServerBaseUrl(host, credentials['port'] ?? '');
  } catch (_) {}

  return SavedPlaylist(
    id: 'legacy',
    name: playlistNameFromServer(server),
    kind: 'xtream',
    host: server,
    username: username,
    password: password,
  );
}

String playlistNameFromServer(String server) {
  final uri = Uri.tryParse(server);
  final host = uri?.host ?? '';
  if (host.isNotEmpty) return host;
  final trimmed = server.trim();
  return trimmed.isEmpty ? 'Xtream' : trimmed;
}
