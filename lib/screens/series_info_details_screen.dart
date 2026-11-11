import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/content_item.dart';
import '../services/app_settings.dart';
import '../services/cloud_sync_service.dart';
import '../services/database_service.dart';

/// Film detay ekranına benzer: büyük poster + eksiksiz dizi meta bilgisi.
class SeriesInfoDetailsScreen extends StatefulWidget {
  final ContentItem seriesItem;
  final String title;
  final String coverUrl;
  final String plot;
  final String cast;
  final String director;
  final String genre;
  final String releaseDate;
  final String rating;
  final bool canResume;
  final VoidCallback? onResume;

  const SeriesInfoDetailsScreen({
    super.key,
    required this.seriesItem,
    required this.title,
    required this.coverUrl,
    required this.plot,
    required this.cast,
    required this.director,
    required this.genre,
    required this.releaseDate,
    required this.rating,
    this.canResume = false,
    this.onResume,
  });

  @override
  State<SeriesInfoDetailsScreen> createState() =>
      _SeriesInfoDetailsScreenState();
}

class _SeriesInfoDetailsScreenState extends State<SeriesInfoDetailsScreen>
    with WidgetsBindingObserver {
  final DatabaseService _databaseService = DatabaseService();
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CloudSyncService.instance.revision.addListener(_onCloudRevision);
    _checkIfFavorite(fromCloud: true);
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
    }
  }

  void _onCloudRevision() {
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite({bool fromCloud = false}) async {
    final isFavorite = await _databaseService.isFavorite(
      widget.seriesItem.id,
      refreshFromCloud: fromCloud,
    );
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await _databaseService.removeFavorite(widget.seriesItem.id);
    } else {
      await _databaseService.addFavorite(widget.seriesItem);
    }

    if (!mounted) return;
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: context.accent,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : context.palette.text,
            ),
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? 'Favorilerden Çıkar' : 'Favorilere Ekle',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.coverUrl.isNotEmpty)
              Container(
                width: double.infinity,
                color: Colors.black,
                child: CachedNetworkImage(
                  imageUrl: widget.coverUrl,
                  fit: BoxFit.contain,
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.palette.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.director.isNotEmpty) ...[
                    _buildDetailRow('Yönetmen', widget.director),
                    const SizedBox(height: 8),
                  ],
                  if (widget.genre.isNotEmpty) ...[
                    _buildDetailRow('Tür', widget.genre),
                    const SizedBox(height: 8),
                  ],
                  if (widget.releaseDate.isNotEmpty) ...[
                    _buildDetailRow('Yayın Tarihi', widget.releaseDate),
                    const SizedBox(height: 8),
                  ],
                  if (widget.rating.isNotEmpty) ...[
                    _buildDetailRow('Puan', widget.rating),
                    const SizedBox(height: 8),
                  ],
                  if (widget.cast.isNotEmpty) ...[
                    _buildDetailRow('Oyuncular', widget.cast),
                    const SizedBox(height: 8),
                  ],
                  if (widget.plot.isNotEmpty) ...[
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
                      widget.plot,
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
          if (widget.canResume && widget.onResume != null) {
            Navigator.pop(context);
            widget.onResume!();
          } else {
            Navigator.pop(context);
          }
        },
        backgroundColor: widget.canResume ? Colors.green : context.accent,
        icon: Icon(widget.canResume ? Icons.play_circle : Icons.list),
        label: Text(widget.canResume ? 'Devam Et' : 'Bölümler'),
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
