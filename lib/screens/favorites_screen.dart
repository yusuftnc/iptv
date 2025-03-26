import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/content_item.dart';
import '../models/favorite_item.dart';
import '../services/database_service.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<FavoriteItem> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final favorites = await _databaseService.getFavorites();
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Favoriler yüklenirken hata: $e')),
        );
      }
    }
  }

  List<FavoriteItem> _getFavoritesByType(String type) {
    return _favorites.where((item) => item.streamType == type).toList();
  }

  void _playContent(FavoriteItem item) {
    final contentItem = ContentItem(
      id: item.id,
      name: item.name,
      streamType: item.streamType,
      streamIcon: item.streamIcon,
      streamUrl: item.streamUrl,
      description: item.description,
      category: item.category,
    );

    if (item.streamType == 'series') {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => SeriesDetailScreen(seriesItem: contentItem),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 100),
        ),
      );
    } else {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(contentItem: contentItem),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 100),
        ),
      );
    }
  }

  Widget _buildContentGrid(List<FavoriteItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Bu kategoride favori bulunmuyor',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final iconUrl = item.streamIcon;
        final name = item.name;
        
        return GestureDetector(
          onTap: () => _playContent(item),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: iconUrl != null && iconUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: iconUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 40,
                            ),
                          )
                        : const Icon(
                            Icons.video_library,
                            size: 40,
                            color: Colors.white,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Favoriler'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const Center(
                  child: Text(
                    'Favorileriniz boş',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TV Kanalları
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'TV Kanalları',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildContentGrid(_getFavoritesByType('live')),
                      
                      // Filmler
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Filmler',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildContentGrid(_getFavoritesByType('movie')),
                      
                      // Diziler
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Diziler',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildContentGrid(_getFavoritesByType('series')),
                    ],
                  ),
                ),
    );
  }
} 