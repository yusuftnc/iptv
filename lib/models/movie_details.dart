class MovieDetails {
  final String? tmdbUrl;
  final String? tmdbId;
  final String name;
  final String? originalName;
  final String coverUrl;
  final String? movieImageUrl;
  final String releaseDate;
  final String duration;
  final String? youtubeTrailer;
  final String director;
  final String? actors;
  final String cast;
  final String description;

  MovieDetails({
    this.tmdbUrl,
    this.tmdbId,
    required this.name,
    this.originalName,
    required this.coverUrl,
    this.movieImageUrl,
    required this.releaseDate,
    required this.duration,
    this.youtubeTrailer,
    required this.director,
    this.actors,
    required this.cast,
    required this.description,
  });

  factory MovieDetails.fromJson(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>;
    return MovieDetails(
      tmdbUrl: info['tmdb_url'],
      tmdbId: info['tmdb_id']?.toString(),
      name: info['name'] ?? '',
      originalName: info['o_name'],
      coverUrl: info['cover_big'] ?? '',
      movieImageUrl: info['movie_image'],
      releaseDate: info['releasedate'] ?? '',
      duration: info['episode_run_time']?.toString() ?? '',
      youtubeTrailer: info['youtube_trailer'],
      director: info['director'] ?? '',
      actors: info['actors'],
      cast: info['cast'] ?? '',
      description: info['description'] ?? '',
    );
  }
} 