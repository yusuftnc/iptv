class M3uEntry {
  final String name;
  final String url;
  final String? logo;
  final String? group;

  const M3uEntry({
    required this.name,
    required this.url,
    this.logo,
    this.group,
  });
}

class M3uParseResult {
  final List<M3uEntry> entries;

  /// HLS yayın listesi (#EXT-X-). Kanal listesi değildir; dosyanın kendisi oynatılır.
  final bool isHls;

  /// Kanal listesi `#EXTM3U` ve en az bir `#EXTINF` yayını taşımalı.
  /// HLS dosyası da geçerlidir. Düz bir adres satırı geçerli değildir.
  final bool isValid;

  const M3uParseResult({
    required this.entries,
    required this.isHls,
    required this.isValid,
  });
}

M3uParseResult parseM3u(String raw) {
  final text = raw.replaceFirst('\uFEFF', '');
  final isHls = text.contains('#EXT-X-STREAM-INF') || text.contains('#EXT-X-TARGETDURATION');
  final entries = <M3uEntry>[];
  var hasHeader = false;
  var waitingForUrl = false;
  String? pendingName;
  String? pendingLogo;
  String? pendingGroup;

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (line.toUpperCase().startsWith('#EXTM3U')) {
      hasHeader = true;
      continue;
    }

    if (line.startsWith('#EXTINF')) {
      waitingForUrl = true;
      pendingLogo = _attribute(line, 'tvg-logo');
      pendingGroup = _attribute(line, 'group-title');
      final fromTag = _displayName(line);
      final tvgName = _attribute(line, 'tvg-name');
      pendingName = (fromTag != null && fromTag.isNotEmpty) ? fromTag : tvgName;
      continue;
    }

    if (line.startsWith('#')) continue;
    if (!_isStreamUrl(line) || !waitingForUrl) continue;

    final name = (pendingName == null || pendingName.isEmpty) ? line : pendingName;
    entries.add(M3uEntry(
      name: name,
      url: line,
      logo: _emptyToNull(pendingLogo),
      group: _emptyToNull(pendingGroup),
    ));
    waitingForUrl = false;
    pendingName = null;
    pendingLogo = null;
    pendingGroup = null;
  }

  final isValid = isHls || (hasHeader && entries.isNotEmpty);
  return M3uParseResult(entries: entries, isHls: isHls, isValid: isValid);
}

String? _emptyToNull(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value.trim();
}

bool _isStreamUrl(String line) {
  final uri = Uri.tryParse(line);
  if (uri == null || !uri.hasScheme) return false;
  switch (uri.scheme.toLowerCase()) {
    case 'http':
    case 'https':
    case 'rtsp':
    case 'rtmp':
    case 'rtsps':
      return true;
    default:
      return false;
  }
}

String? _displayName(String line) {
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') inQuotes = !inQuotes;
    if (char == ',' && !inQuotes) {
      return line.substring(i + 1).trim();
    }
  }
  return null;
}

String? _attribute(String line, String name) {
  final match = RegExp('$name="([^"]*)"', caseSensitive: false).firstMatch(line);
  return match?.group(1);
}
