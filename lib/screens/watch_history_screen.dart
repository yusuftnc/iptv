import 'package:flutter/material.dart';
import '../models/watch_history.dart';
import '../models/content_item.dart';
import '../services/database_service.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({super.key});

  @override
  State<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<WatchHistory> _watchHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWatchHistory();
  }

  Future<void> _loadWatchHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await _databaseService.getWatchHistory();
      setState(() {
        _watchHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İzleme geçmişi yüklenirken hata: $e')),
        );
      }
    }
  }

  Future<void> _clearWatchHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İzleme Geçmişini Temizle'),
        content: const Text('Tüm izleme geçmişiniz silinecek. Devam etmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _databaseService.clearWatchHistory();
      _loadWatchHistory();
    }
  }

  Future<void> _removeFromHistory(String contentId) async {
    await _databaseService.removeFromWatchHistory(contentId);
    _loadWatchHistory();
  }

  void _playContent(WatchHistory item) {
    // İçerik tipine göre uygun ekrana yönlendir
    final contentItem = ContentItem(
      id: item.contentId,
      name: item.name,
      streamUrl: item.streamUrl ?? '',
      streamType: item.streamType,
      streamIcon: item.streamIcon,
      category: item.category,
    );

    if (item.streamType == 'series') {
      // Dizi detay ekranına git
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeriesDetailScreen(seriesItem: contentItem),
        ),
      );
    } else {
      // Player ekranına git
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(contentItem: contentItem),
        ),
      ).then((_) => _loadWatchHistory()); // Geri dönünce izleme geçmişini yenile
    }
  }

  String _formatWatchDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Bugün ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Dün ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDuration(int? position, int? duration) {
    if (position == null || duration == null) {
      return '';
    }

    final positionMinutes = (position / 60).floor();
    final positionSeconds = position % 60;
    
    final durationMinutes = (duration / 60).floor();
    final durationSeconds = duration % 60;
    
    return '${positionMinutes.toString().padLeft(2, '0')}:${positionSeconds.toString().padLeft(2, '0')} / ${durationMinutes.toString().padLeft(2, '0')}:${durationSeconds.toString().padLeft(2, '0')}';
  }

  double _calculateProgress(int? position, int? duration) {
    if (position == null || duration == null || duration == 0) {
      return 0.0;
    }
    return position / duration;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('İzleme Geçmişi'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearWatchHistory,
            tooltip: 'Geçmişi Temizle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _watchHistory.isEmpty
              ? const Center(
                  child: Text(
                    'İzleme geçmişiniz boş',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _watchHistory.length,
                  itemBuilder: (context, index) {
                    final item = _watchHistory[index];
                    return Dismissible(
                      key: Key(item.contentId),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        _removeFromHistory(item.contentId);
                      },
                      child: InkWell(
                        onTap: () => _playContent(item),
                        child: Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ListTile(
                            leading: item.streamIcon != null && item.streamIcon!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    item.streamIcon!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.error),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[800],
                                  child: Icon(
                                    item.streamType == 'live' ? Icons.live_tv 
                                    : item.streamType == 'movie' ? Icons.movie 
                                    : Icons.tv,
                                    color: Colors.white,
                                  ),
                                ),
                            title: Text(
                              item.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatWatchDate(item.watchDate),
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                                if (item.position != null && item.duration != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDuration(item.position, item.duration),
                                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: _calculateProgress(item.position, item.duration),
                                        backgroundColor: Colors.grey[700],
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            trailing: Icon(
                              item.streamType == 'live' ? Icons.live_tv 
                              : item.streamType == 'movie' ? Icons.movie 
                              : Icons.tv,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 