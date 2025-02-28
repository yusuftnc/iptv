import 'package:flutter/material.dart';
import '../models/content_item.dart';
import '../services/iptv_service.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = false;
  List<ContentItem> _items = [];
  final IptvService _iptvService = IptvService();

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _items = [];
    });

    try {
      List<Map<String, dynamic>> data = [];
      switch (_currentIndex) {
        case 0: // TV Kanalları
          data = await _iptvService.getLiveTV();
          _items = data.map((item) => ContentItem.fromJson(item, 'live')).toList();
          break;
        case 1: // Filmler
          data = await _iptvService.getMovies();
          _items = data.map((item) => ContentItem.fromJson(item, 'movie')).toList();
          break;
        case 2: // Diziler
          data = await _iptvService.getSeries();
          _items = data.map((item) => ContentItem.fromJson(item, 'series')).toList();
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final storageService = StorageService();
    await storageService.clearCredentials();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 
            ? 'TV Kanalları' 
            : _currentIndex == 1 
                ? 'Filmler' 
                : 'Diziler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('İçerik bulunamadı'))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 16 / 9,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          // TODO: Navigate to player screen
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (item.streamIcon != null && item.streamIcon!.isNotEmpty)
                              Image.network(
                                item.streamIcon!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.error_outline),
                                  );
                                },
                              )
                            else
                              Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.play_circle_outline, size: 50),
                              ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.black54,
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _loadContent();
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.tv),
            label: 'TV Kanalları',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.movie),
            label: 'Filmler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: 'Diziler',
          ),
        ],
      ),
    );
  }
} 