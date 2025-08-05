import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/content_item.dart';
import '../services/iptv_service.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'watch_history_screen.dart';
import 'movie_details_screen.dart';
import '../models/watch_history.dart';
import '../services/database_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final IptvService _iptvService = IptvService();
  int _currentIndex = 0;
  bool _isLoading = true;
  String _errorMessage = '';

  // Kategoriler ve içerikler
  List<Map<String, dynamic>> _liveCategories = [];
  List<Map<String, dynamic>> _movieCategories = [];
  List<Map<String, dynamic>> _seriesCategories = [];

  // Seçilen kategori içerikleri
  List<Map<String, dynamic>> _selectedCategoryContent = [];
  String _selectedCategoryName = '';
  String _selectedCategoryId = '';
  String _currentContentType = 'live'; // 'live', 'movie', 'series'

  List<Map<String, dynamic>> _latestMovies = [];
  List<Map<String, dynamic>> _latestSeries = [];
  List<Map<String, dynamic>> _latestChannels = [];
  List<WatchHistory> _lastWatchedMovies = [];
  List<WatchHistory> _lastWatchedSeries = [];

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      switch (_currentIndex) {
        case 0: // Yeniler
          _latestMovies = await _iptvService.getLatestMovies(limit: 30);
          _latestSeries = await _iptvService.getLatestSeries(limit: 30);
          _latestChannels = await _iptvService.getLatestChannels(limit: 10);
          final db = DatabaseService();
          _lastWatchedMovies = await db.getLastWatched('movie', limit: 10);
          _lastWatchedSeries = await db.getLastWatched('series', limit: 10);

          break;
        case 1: // TV Kanalları
          _currentContentType = 'live';
          final categories = await _iptvService.getLiveCategories();
          setState(() {
            _liveCategories = categories;
          });
          break;
        case 2: // Filmler
          _currentContentType = 'movie';
          final categories = await _iptvService.getMovieCategories();
          setState(() {
            _movieCategories = categories;
          });
          break;
        case 3: // Diziler
          _currentContentType = 'series';
          final categories = await _iptvService.getSeriesCategories();
          setState(() {
            _seriesCategories = categories;
          });
          break;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'İçerik yüklenirken hata oluştu: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategoryContent(
      String categoryId, String categoryType) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      List<Map<String, dynamic>> content = [];

      switch (categoryType) {
        case 'live':
          content = await _iptvService.getChannels(categoryId);
          break;
        case 'movie':
          final allMovies = await _iptvService.getMovies();
          content = allMovies
              .where((movie) => movie['category_id']?.toString() == categoryId)
              .toList();
          break;
        case 'series':
          final allSeries = await _iptvService.getSeries();
          content = allSeries
              .where((serie) => serie['category_id']?.toString() == categoryId)
              .toList();
          break;
      }

      print(
          'Debug - Loaded content for category $categoryId: ${content.length} items');

      if (mounted) {
        setState(() {
          _selectedCategoryContent = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Debug - Error loading category content: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'İçerik yüklenirken bir hata oluştu: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final storageService = StorageService();
    await storageService.clearCredentials();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }

        if (_selectedCategoryName.isNotEmpty) {
          // Eğer bir kategori içeriği görüntüleniyorsa, kategori listesine geri dön
          setState(() {
            _selectedCategoryName = '';
            _selectedCategoryId = '';
            _selectedCategoryContent = [];
          });
        } else {
          // Ana ekrandaysa, çıkış onayı diyaloğunu göster
          _showExitDialog();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(_selectedCategoryName.isNotEmpty
              ? _selectedCategoryName
              : _getAppBarTitle()),
          backgroundColor: Colors.blue,
          leading: _selectedCategoryName.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedCategoryName = '';
                      _selectedCategoryId = '';
                      _selectedCategoryContent = [];
                    });
                  },
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const SearchScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 100),
                  ),
                );
              },
              tooltip: 'Ara',
            ),
            // Refresh butonu menüye taşındı
          ],
        ),
        drawer: Drawer(
          child: Container(
            color: Colors.grey.shade900,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'IPTV',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Kullanıcı: ${_iptvService.getUsername() ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Anasayfa',
                    style: TextStyle(color: Colors.white),
                  ),
                  leading: const Icon(
                    Icons.home,
                    color: Colors.white,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text(
                    'Favoriler',
                    style: TextStyle(color: Colors.white),
                  ),
                  leading: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FavoritesScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  title: const Text(
                    'İzleme Geçmişi',
                    style: TextStyle(color: Colors.white),
                  ),
                  leading: const Icon(
                    Icons.history,
                    color: Colors.white,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WatchHistoryScreen(),
                      ),
                    );
                  },
                ),
                // Yenile
                ListTile(
                  title: const Text(
                    'Yenile',
                    style: TextStyle(color: Colors.white),
                  ),
                  leading: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _loadContent();
                  },
                ),
                const Divider(color: Colors.grey),
                ListTile(
                  title: const Text(
                    'Çıkış Yap',
                    style: TextStyle(color: Colors.white),
                  ),
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.white,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
              ],
            ),
          ),
        ),
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              _selectedCategoryName = '';
              _selectedCategoryId = '';
              _selectedCategoryContent = [];
            });
            _loadContent();
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.new_releases),
              label: 'Yeniler',
            ),
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
      ),
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
              onPressed: _loadContent,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    // Eğer bir kategori seçilmişse, o kategorinin içeriğini göster
    if (_selectedCategoryName.isNotEmpty) {
      return _buildCategoryContent();
    }

    // Eğer kategori seçilmemişse, tab içeriğine göre kategori listesini göster
    switch (_currentIndex) {
      case 0: // Yeniler
        return _buildNewContent();
      case 1: // TV Kanalları
        return _buildCategoryList();
      case 2: // Filmler
        return _buildCategoryList();
      case 3: // Diziler
        return _buildCategoryList();
      default:
        return const Center(
          child: Text(
            'Bilinmeyen sekme',
            style: TextStyle(color: Colors.white),
          ),
        );
    }
  }

  Widget _buildNewContent() {
    if (_latestMovies.isEmpty &&
        _latestSeries.isEmpty &&
        _latestChannels.isEmpty) {
      return const Center(
        child: Text(
          'Yeni içerik bulunamadı',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView(
      children: [
        if (_lastWatchedMovies.isNotEmpty) ...[
          _buildSectionHeader('İzlenen Filmler', _lastWatchedMovies.length),
          _buildWatchHorizontal(_lastWatchedMovies, 'movie'),
        ],
        if (_lastWatchedSeries.isNotEmpty) ...[
          _buildSectionHeader('İzlenen Diziler', _lastWatchedSeries.length),
          _buildWatchHorizontal(_lastWatchedSeries, 'series'),
        ],
        if (_latestMovies.isNotEmpty) ...[
          _buildSectionHeader('Son Eklenen Filmler', _latestMovies.length),
          _buildContentGrid(_latestMovies, 'movie'),
        ],
        if (_latestSeries.isNotEmpty) ...[
          _buildSectionHeader('Son Eklenen Diziler', _latestSeries.length),
          _buildContentGrid(_latestSeries, 'series'),
        ],
        if (_latestChannels.isNotEmpty) ...[
          _buildSectionHeader('Son Eklenen Kanallar', _latestChannels.length),
          _buildChannelsList(_latestChannels),
        ],
      ],
    );
  }

  Widget _buildCategoryList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _currentIndex == 1
          ? _liveCategories.length
          : _currentIndex == 2
              ? _movieCategories.length
              : _seriesCategories.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final category = _currentIndex == 1
            ? _liveCategories[index]
            : _currentIndex == 2
                ? _movieCategories[index]
                : _seriesCategories[index];
        return ListTile(
          leading: Icon(
            _getCategoryIcon(category['category_name']),
            color: Colors.white,
          ),
          title: Text(
            category['category_name'] ?? 'Unknown',
            style: const TextStyle(color: Colors.white),
          ),
          onTap: () {
            setState(() {
              _selectedCategoryId = category['category_id'].toString();
              _selectedCategoryName = category['category_name'];
              _currentContentType = _currentIndex == 1
                  ? 'live'
                  : _currentIndex == 2
                      ? 'movie'
                      : 'series';
            });
            _loadCategoryContent(
              category['category_id'].toString(),
              _currentContentType,
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryContent() {
    if (_selectedCategoryContent.isEmpty) {
      return const Center(
        child: Text(
          'Bu kategoride içerik bulunamadı',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // GridView için sabit değerler
    const crossAxisCount = 3;
    const childAspectRatio = 0.7;
    const crossAxisSpacing = 8.0;
    const mainAxisSpacing = 8.0;
    const padding = EdgeInsets.all(8.0);

    return GridView.builder(
      padding: padding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: _selectedCategoryContent.length,
      cacheExtent: 1000,
      addAutomaticKeepAlives: true,
      itemBuilder: (context, index) {
        final item = _selectedCategoryContent[index];
        final contentItem = ContentItem.fromJson(item, _currentContentType);

        return RepaintBoundary(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                try {
                  print('Debug - Content item: $item');
                  print('Debug - Current content type: $_currentContentType');
                  final contentId = _currentContentType == 'live'
                      ? item['stream_id'].toString()
                      : _currentContentType == 'movie'
                          ? item['stream_id'].toString()
                          : item['series_id'].toString();
                  print('Debug - Content ID: $contentId');

                  if (_currentContentType == 'series') {
                    print('Debug - Series ID: ${item['series_id']}');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SeriesDetailScreen(
                          seriesItem: ContentItem.fromJson(item, 'series'),
                        ),
                      ),
                    );
                    return;
                  }

                  String? streamUrl = await _iptvService.getStreamUrl(
                    streamId: contentId,
                    streamType: _currentContentType,
                  );
                  print('Debug - Stream URL: $streamUrl');

                  if (streamUrl != null && mounted) {
                    _playContent(contentId, streamUrl, _currentContentType);
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Stream URL bulunamadı'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  print('Debug - Error getting stream URL: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: ${e.toString()}'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (contentItem.streamIcon != null &&
                      contentItem.streamIcon!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: contentItem.streamIcon!,
                      fit: _currentContentType == 'live'
                          ? BoxFit.contain
                          : BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: _currentContentType == 'live'
                          ? Alignment.center
                          : Alignment.topCenter,
                      memCacheWidth: 300,
                      memCacheHeight: 450,
                      cacheKey: contentItem.streamIcon,
                      maxHeightDiskCache: 450,
                      maxWidthDiskCache: 300,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[900],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[900],
                        child: Icon(
                          _currentContentType == 'live'
                              ? Icons.tv
                              : _currentContentType == 'movie'
                                  ? Icons.movie
                                  : Icons.video_library,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: Colors.grey[900],
                      child: Icon(
                        _currentContentType == 'live'
                            ? Icons.tv
                            : _currentContentType == 'movie'
                                ? Icons.movie
                                : Icons.video_library,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      color: Colors.black54,
                      child: Text(
                        contentItem.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _playContent(
      String contentId, String streamUrl, String contentType) async {
    try {
      if (contentType == 'movie') {
        final movieDetails = await _iptvService.getMovieInfo(contentId);
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsScreen(
              contentId: contentId,
              streamUrl: streamUrl,
              movieDetails: movieDetails,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
              streamUrl: streamUrl,
              contentId: contentId,
              contentType: contentType,
              name: contentId,
              streamIcon: contentId,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load content: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showLogoutDialog() {
    _showConfirmationDialog(
      title: 'Çıkış Yap',
      content: 'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
      confirmText: 'Çıkış Yap',
      onConfirm: _logout,
    );
  }

  void _showExitDialog() {
    _showConfirmationDialog(
      title: 'Uygulamadan Çık',
      content: 'Uygulamadan çıkmak istediğinize emin misiniz?',
      confirmText: 'Çıkış',
      onConfirm: () {
        SystemNavigator.pop(); // Uygulamadan çık
      },
    );
  }

  void _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    required VoidCallback onConfirm,
    String cancelText = 'İptal',
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Yeniler';
      case 1:
        return 'TV Kanalları';
      case 2:
        return 'Filmler';
      case 3:
        return 'Diziler';
      default:
        return 'Bilinmeyen sekme';
    }
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('film') || name.contains('movie')) {
      return Icons.movie;
    } else if (name.contains('dizi') || name.contains('series')) {
      return Icons.video_library;
    } else if (name.contains('spor') || name.contains('sport')) {
      return Icons.sports;
    } else if (name.contains('çocuk') || name.contains('kids')) {
      return Icons.child_care;
    } else if (name.contains('belgesel') || name.contains('documentary')) {
      return Icons.nature;
    } else {
      return Icons.tv;
    }
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsList(List<Map<String, dynamic>> channels) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      cacheExtent: 100.0,
      itemCount: channels.length,
      separatorBuilder: (context, index) => const Divider(
        color: Colors.grey,
        height: 1,
        indent: 70,
      ),
      itemBuilder: (context, index) {
        final channel = channels[index];
        return ListTile(
          leading: channel['stream_icon'] != null &&
                  channel['stream_icon'].isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: channel['stream_icon'],
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey[800],
                    child: const Icon(Icons.tv, color: Colors.white, size: 20),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey[800],
                    child: const Icon(Icons.tv, color: Colors.white, size: 20),
                  ),
                )
              : Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[800],
                  child: const Icon(Icons.tv, color: Colors.white, size: 20),
                ),
          title: Text(
            channel['name'] ?? 'İsimsiz Kanal',
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: channel['category_name'] != null
              ? Text(
                  channel['category_name'],
                  style: TextStyle(color: Colors.grey[400]),
                )
              : null,
          onTap: () => _openContent(ContentItem.fromJson(channel, 'live')),
        );
      },
    );
  }

  Widget _buildContentGrid(
      List<Map<String, dynamic>> items, String contentType) {
    const crossAxisCount = 3;
    const childAspectRatio = 0.7;
    const crossAxisSpacing = 8.0;
    const mainAxisSpacing = 8.0;
    const padding = EdgeInsets.all(8.0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final iconUrl =
            contentType == 'series' ? item['cover'] : item['stream_icon'];
        final name = item['name'] ?? 'İsimsiz İçerik';

        final iconWidget = contentType == 'movie'
            ? const Icon(Icons.movie, size: 30, color: Colors.white)
            : const Icon(Icons.video_library, size: 30, color: Colors.white);

        return Card(
          clipBehavior: Clip.antiAlias,
          color: Colors.grey[900],
          child: InkWell(
            onTap: () => _openContent(ContentItem.fromJson(item, contentType)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (iconUrl != null && iconUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: iconUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        Container(color: Colors.grey[800], child: iconWidget),
                  )
                else
                  Container(color: Colors.grey[800], child: iconWidget),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    color: Colors.black54,
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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
    );
  }

  Future<void> _openContent(ContentItem contentItem) async {
    try {
      final type = contentItem.streamType ?? 'live';

      if (type == 'series') {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SeriesDetailScreen(seriesItem: contentItem),
          ),
        );
        return;
      }

      String streamUrl = contentItem.streamUrl ?? '';
      if (streamUrl.isEmpty) {
        final fetchedUrl = await _iptvService.getStreamUrl(
          streamId: contentItem.id,
          streamType: type,
        );
        streamUrl = fetchedUrl ?? '';
      }

      if (type == 'movie') {
        final movieDetails = await _iptvService.getMovieInfo(contentItem.id);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsScreen(
              contentId: contentItem.id,
              streamUrl: streamUrl,
              movieDetails: movieDetails,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
              contentId: contentItem.id,
              streamUrl: streamUrl,
              contentType: type,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('İçerik yüklenirken hata oluştu: ${e.toString()}')),
      );
    }
  }

  Widget _buildWatchHorizontal(List<WatchHistory> items, String type) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final h = items[index];
          final iconUrl = h.streamIcon;
          final name = h.name ?? '';
          final contentItem = ContentItem(
            id: h.contentId,
            name: name,
            streamIcon: iconUrl,
            streamType: type,
            streamUrl: h.streamUrl,
          );
          return SizedBox(
            width: 130,
            child: _buildCardForHorizontal(contentItem),
          );
        },
      ),
    );
  }

  Widget _buildCardForHorizontal(ContentItem item) {
    final iconUrl =
        item.streamType == 'series' ? item.streamIcon : item.streamIcon;
    final iconWidget = item.streamType == 'movie'
        ? const Icon(Icons.movie, color: Colors.white, size: 30)
        : const Icon(Icons.video_library, color: Colors.white, size: 30);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: Colors.grey[900],
      child: InkWell(
        onTap: () => _openContent(item),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (iconUrl != null && iconUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: iconUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) =>
                    Container(color: Colors.grey[800], child: iconWidget),
              )
            else
              Container(color: Colors.grey[800], child: iconWidget),
          ],
        ),
      ),
    );
  }
}

// Kategori listesi öğeleri için özel widget
class CategoryListItem extends StatelessWidget {
  final Map<String, dynamic> category;
  final String contentType;
  final VoidCallback onTap;

  const CategoryListItem({
    Key? key,
    required this.category,
    required this.contentType,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sabit değerler
    const iconColor = Colors.blue;
    const textColor = Colors.white;
    const arrowColor = Colors.blue;
    const arrowSize = 16.0;

    // İçerik tipine göre ikon belirleme
    final IconData categoryIcon = contentType == 'live'
        ? Icons.tv
        : contentType == 'movie'
            ? Icons.movie
            : Icons.video_library;

    return ListTile(
      title: Text(
        category['category_name'] ?? 'İsimsiz Kategori',
        style: const TextStyle(color: textColor),
      ),
      leading: Icon(
        categoryIcon,
        color: iconColor,
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: arrowColor,
        size: arrowSize,
      ),
      onTap: onTap,
    );
  }
}
