class DiscoverTitle {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final double voteAverage;
  final String? year;
  final bool isSeries;

  const DiscoverTitle({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.voteAverage,
    required this.year,
    required this.isSeries,
  });

  String? get posterUrl {
    final path = posterPath;
    if (path == null || path.isEmpty) return null;
    return path;
  }

  factory DiscoverTitle.fromJson(Map<String, dynamic> json, {required bool isSeries}) {
    final date = (isSeries ? json['first_air_date'] : json['release_date']) as String?;
    final year = (date != null && date.length >= 4) ? date.substring(0, 4) : null;
    return DiscoverTitle(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      year: year,
      isSeries: isSeries,
    );
  }
}
