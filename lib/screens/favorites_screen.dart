import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/content_item.dart';
import '../models/favorite_item.dart';
import '../services/cloud_sync_service.dart';
import '../services/database_service.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import '../services/iptv_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with WidgetsBindingObserver {
  final DatabaseService _databaseService = DatabaseService();
  List<FavoriteItem> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CloudSyncService.instance.revision.addListener(_onCloudRevision);
    _loadFavorites(fromCloud: true);
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
      _loadFavorites(fromCloud: true, showSpinner: false);
    }
  }

  void _onCloudRevision() {
    _loadFavorites(fromCloud: false, showSpinner: false);
  }

  Future<void> _loadFavorites({
    bool fromCloud = false,
    bool showSpinner = true,
  }) async {
    if (showSpinner && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final favorites =
          await _databaseService.getFavorites(refreshFromCloud: fromCloud);
      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Favoriler yüklenirken hata: $e')),
      );
    }
  }

  List<FavoriteItem> _getFavoritesByType(String type) {
    return _favorites.where((item) => item.streamType == type).toList();
  }

  Future<void> _playContent(FavoriteItem item) async {
    final seriesIdForEpisode = item.seriesId;

    if (item.streamType == 'series' && item.isSeriesEpisodeFavorite) {
      final historyId = (seriesIdForEpisode != null &&
              seriesIdForEpisode.isNotEmpty)
          ? seriesIdForEpisode
          : item.id;
      String url = item.streamUrl ?? '';
      if (url.isEmpty) {
        url = await IptvService().getStreamUrl(
              streamId: item.id,
              streamType: 'series',
            ) ??
            '';
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            contentId: item.id,
            streamUrl: url,
            contentType: 'series',
            name: item.name,
            streamIcon: item.streamIcon,
            historyId: historyId,
          ),
        ),
      );
      return;
    }

    final contentItem = ContentItem(
      id: item.id,
      name: item.name,
      streamUrl: item.streamUrl,
      streamType: item.streamType,
      streamIcon: item.streamIcon,
      description: item.description,
      category: item.category,
      historyId: item.id,
    );

    if (item.streamType == 'series') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeriesDetailScreen(seriesItem: contentItem),
        ),
      );
    } else {
      final IptvService iptv = IptvService();
      String url = item.streamUrl ?? '';
      if (url.isEmpty) {
        url = await iptv.getStreamUrl(
                streamId: item.id, streamType: item.streamType ?? 'movie') ??
            '';
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            contentId: item.id,
            streamUrl: url,
            contentType: item.streamType,
            name: item.name,
            streamIcon: item.streamIcon,
            historyId: item.id,
          ),
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
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
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
          : RefreshIndicator(
              color: Colors.blue,
              onRefresh: () =>
                  _loadFavorites(fromCloud: true, showSpinner: false),
              child: _favorites.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        Center(
                          child: Text(
                            'Favorileriniz boş',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
            ),
    );
  }
}
