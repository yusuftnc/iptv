import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/content_item.dart';
import '../services/iptv_service.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final ContentItem seriesItem;

  const SeriesDetailScreen({
    super.key,
    required this.seriesItem,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  final IptvService _iptvService = IptvService();
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Dizi bilgileri
  Map<String, dynamic> _seriesInfo = {};
  Map<String, List<Map<String, dynamic>>> _episodesBySeason = {};
  List<String> _seasons = [];
  String _selectedSeason = '';
  
  @override
  void initState() {
    super.initState();
    _loadSeriesDetails();
  }
  
  Future<void> _loadSeriesDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      // Dizi bilgilerini al
      final seriesInfo = await _iptvService.getSeriesInfo(widget.seriesItem.id);
      
      // Dizi bölümlerini al
      final episodesBySeason = await _iptvService.getSeriesEpisodes(widget.seriesItem.id);
      
      // Sezonları sırala
      final seasons = episodesBySeason.keys.toList();
      seasons.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      
      setState(() {
        _seriesInfo = seriesInfo;
        _episodesBySeason = episodesBySeason;
        _seasons = seasons;
        _selectedSeason = seasons.isNotEmpty ? seasons.first : '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Dizi bilgileri yüklenirken hata oluştu: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  void _playEpisode(Map<String, dynamic> episode) {
    // Bölüm için ContentItem oluştur
    final episodeItem = ContentItem(
      id: episode['id'].toString(),
      name: '${widget.seriesItem.name} - S${_selectedSeason}E${episode['episode_num']} - ${episode['title']}',
      streamType: 'series',
      streamIcon: widget.seriesItem.streamIcon,
      description: episode['plot'] ?? '',
      category: widget.seriesItem.category,
      // Eğer container_extension varsa, doğrudan stream URL'ini oluştur
      streamUrl: episode['container_extension'] != null && episode['container_extension'].toString().isNotEmpty
          ? '${_iptvService.getServerUrl()}/series/${_iptvService.getUsername()}/${_iptvService.getPassword()}/${episode['id']}.${episode['container_extension']}'
          : null,
    );
    
    // Oynatma ekranına git
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(contentItem: episodeItem),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.seriesItem.name),
        backgroundColor: Colors.blue,
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadSeriesDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }
    
    if (_seasons.isEmpty) {
      return const Center(
        child: Text(
          'Bu dizi için bölüm bulunamadı',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dizi bilgileri
        _buildSeriesInfo(),
        
        // Sezon seçici
        _buildSeasonSelector(),
        
        // Bölüm listesi
        Expanded(
          child: _buildEpisodesList(),
        ),
      ],
    );
  }
  
  Widget _buildSeriesInfo() {
    final plot = _seriesInfo['plot'] ?? widget.seriesItem.description ?? '';
    final cast = _seriesInfo['cast'] ?? '';
    final director = _seriesInfo['director'] ?? '';
    final genre = _seriesInfo['genre'] ?? '';
    final releaseDate = _seriesInfo['releaseDate'] ?? '';
    final rating = _seriesInfo['rating'] ?? '';
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          if (widget.seriesItem.streamIcon != null && widget.seriesItem.streamIcon!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: widget.seriesItem.streamIcon!,
                width: 120,
                height: 180,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 120,
                  height: 180,
                  color: Colors.grey[800],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 120,
                  height: 180,
                  color: Colors.grey[800],
                  child: const Icon(
                    Icons.video_library,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          
          const SizedBox(width: 16),
          
          // Dizi bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plot.isNotEmpty) ...[
                  const Text(
                    'Özet',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    plot,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
                
                if (genre.isNotEmpty) ...[
                  const Text(
                    'Tür',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    genre,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                ],
                
                if (cast.isNotEmpty) ...[
                  const Text(
                    'Oyuncular',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    cast,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
                
                Row(
                  children: [
                    if (rating.isNotEmpty) ...[
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                    ],
                    
                    if (releaseDate.isNotEmpty) ...[
                      const Icon(Icons.calendar_today, color: Colors.blue, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        releaseDate,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSeasonSelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _seasons.length,
        itemBuilder: (context, index) {
          final season = _seasons[index];
          final isSelected = season == _selectedSeason;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedSeason = season;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? Colors.blue : Colors.grey[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Sezon ${int.parse(season)}'),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildEpisodesList() {
    final episodes = _episodesBySeason[_selectedSeason] ?? [];
    
    if (episodes.isEmpty) {
      return const Center(
        child: Text(
          'Bu sezon için bölüm bulunamadı',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final episode = episodes[index];
        final episodeNum = episode['episode_num'] ?? '';
        final title = episode['title'] ?? 'Bölüm $episodeNum';
        final plot = episode['plot'] ?? '';
        final duration = episode['duration'] ?? '';
        
        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.all(8),
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                episodeNum.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plot.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    plot,
                    style: TextStyle(color: Colors.grey[400]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (duration.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Süre: $duration',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_outline, color: Colors.blue, size: 36),
              onPressed: () => _playEpisode(episode),
            ),
            onTap: () => _playEpisode(episode),
          ),
        );
      },
    );
  }
} 