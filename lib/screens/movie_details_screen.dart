import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie_details.dart';
import '../models/content_item.dart';
import '../models/watch_history.dart';
import '../services/app_settings.dart';
import '../services/cloud_sync_service.dart';
import '../services/database_service.dart';
import 'player_screen.dart';

class MovieDetailsScreen extends StatefulWidget {
  final String contentId;
  final String streamUrl;
  final MovieDetails movieDetails;

  const MovieDetailsScreen({
    super.key,
    required this.contentId,
    required this.streamUrl,
    required this.movieDetails,
  });

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen>
    with WidgetsBindingObserver {
  final DatabaseService _databaseService = DatabaseService();
  bool _isFavorite = false;
  WatchHistory? _resumeHistory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CloudSyncService.instance.revision.addListener(_onCloudRevision);
    _checkIfFavorite(fromCloud: true);
    _loadResume(fromCloud: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CloudSyncService.instance.revision.removeListener(_onCloudRevision);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkIfFavorite(fromCloud: true);
      _loadResume(fromCloud: true);
    }
  }

  void _onCloudRevision() {
    _checkIfFavorite();
    _loadResume();
  }

  Future<void> _checkIfFavorite({bool fromCloud = false}) async {
    final isFavorite = await _databaseService.isFavorite(
      widget.contentId,
      refreshFromCloud: fromCloud,
    );
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  Future<void> _loadResume({bool fromCloud = false}) async {
    final history = await _databaseService.getWatchPosition(
      widget.contentId,
      refreshFromCloud: fromCloud,
    );
    if (!mounted) return;
    setState(() {
      _resumeHistory = history;
    });
  }

  bool get _canResume {
    final h = _resumeHistory;
    if (h == null || h.position == null || h.duration == null) return false;
    return h.position! > 10 && h.position! < (h.duration! - 30);
  }

  String _formatPosition(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await _databaseService.removeFavorite(widget.contentId);
    } else {
      final contentItem = ContentItem(
        id: widget.contentId,
        name: widget.movieDetails.name,
        streamIcon: widget.movieDetails.coverUrl,
        streamType: 'movie',
        historyId: widget.contentId,
      );
      await _databaseService.addFavorite(contentItem);
    }

    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(widget.movieDetails.name),
        backgroundColor: context.accent,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : context.palette.text,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image (tam görüntü, kırpmasız)
            Container(
              width: double.infinity,
              color: Colors.black,
              child: CachedNetworkImage(
                imageUrl: widget.movieDetails.coverUrl,
                fit: BoxFit.contain, // kırpmadan göster
                placeholder: (context, url) => const SizedBox(
                  height: 250,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => const SizedBox(
                  height: 250,
                  child: Icon(Icons.error, color: Colors.red, size: 50),
                ),
              ),
            ),

            // Movie Details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.movieDetails.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.palette.text,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Director
                  if (widget.movieDetails.director.isNotEmpty) ...[
                    _buildDetailRow('Yönetmen', widget.movieDetails.director),
                    const SizedBox(height: 8),
                  ],

                  // Release Date
                  if (widget.movieDetails.releaseDate.isNotEmpty) ...[
                    _buildDetailRow(
                        'Yayın Tarihi', widget.movieDetails.releaseDate),
                    const SizedBox(height: 8),
                  ],

                  // Duration
                  if (widget.movieDetails.duration.isNotEmpty) ...[
                    _buildDetailRow('Süre', widget.movieDetails.duration),
                    const SizedBox(height: 8),
                  ],

                  // Cast
                  if (widget.movieDetails.cast.isNotEmpty) ...[
                    _buildDetailRow('Oyuncular', widget.movieDetails.cast),
                    const SizedBox(height: 8),
                  ],

                  // Description
                  if (widget.movieDetails.description.isNotEmpty) ...[
                    Text(
                      'Açıklama',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.palette.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.movieDetails.description,
                      style: TextStyle(
                        color: context.palette.text,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                contentId: widget.contentId,
                streamUrl: widget.streamUrl,
                contentType: 'movie',
                name: widget.movieDetails.name,
                streamIcon: widget.movieDetails.coverUrl,
                historyId: widget.contentId,
              ),
            ),
          ).then((_) {
            _loadResume(fromCloud: true);
            _checkIfFavorite(fromCloud: true);
          });
        },
        backgroundColor: _canResume ? Colors.green : context.accent,
        icon: Icon(_canResume ? Icons.play_circle : Icons.play_arrow),
        label: Text(
          _canResume
              ? 'Devam et (${_formatPosition(_resumeHistory!.position!)})'
              : 'İzle',
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.palette.text,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
