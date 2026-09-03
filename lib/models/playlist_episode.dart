/// Dizi oynatıcısında önceki/sonraki bölüm için düz liste öğesi.
class PlaylistEpisode {
  final String id;
  final String name;
  final String? streamUrl;
  final String season;
  final String episodeLabel;

  const PlaylistEpisode({
    required this.id,
    required this.name,
    this.streamUrl,
    required this.season,
    required this.episodeLabel,
  });
}
