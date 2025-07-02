import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie_details.dart';
import '../models/content_item.dart';
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

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    final isFavorite = await _databaseService.isFavorite(widget.contentId);
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.movieDetails.name),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
              ),
              child: CachedNetworkImage(
                imageUrl: widget.movieDetails.coverUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 50,
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
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                    _buildDetailRow('Yayın Tarihi', widget.movieDetails.releaseDate),
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
                    const Text(
                      'Açıklama',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.movieDetails.description,
                      style: const TextStyle(
                        color: Colors.white,
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
              ),
            ),
          );
        },
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.play_arrow),
        label: const Text('İzle'),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
} 