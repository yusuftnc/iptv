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
          // Yeniler tabı için içerik yükleme
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
  
  Future<void> _loadCategoryContent(String categoryId, String categoryName, String contentType) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _selectedCategoryId = categoryId;
        _selectedCategoryName = categoryName;
      });
      
      List<Map<String, dynamic>> content = [];
      
      switch (contentType) {
        case 'live':
          content = await _iptvService.getChannels(categoryId);
          break;
        case 'movie':
          content = await _iptvService.getMovies().then((movies) => 
            movies.where((movie) => movie['category_id'].toString() == categoryId).toList());
          break;
        case 'series':
          content = await _iptvService.getSeries().then((series) => 
            series.where((serie) => serie['category_id'].toString() == categoryId).toList());
          break;
      }
      
      setState(() {
        _selectedCategoryContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Kategori içeriği yüklenirken hata oluştu: ${e.toString()}';
        _isLoading = false;
      });
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
              : _currentIndex == 0 
                  ? 'Yeniler' 
                  : _currentIndex == 1 
                      ? 'TV Kanalları' 
                      : _currentIndex == 2 
                          ? 'Filmler' 
                          : 'Diziler'),
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
                  MaterialPageRoute(builder: (context) => const SearchScreen()),
                );
              },
              tooltip: 'Ara',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadContent,
              tooltip: 'Yenile',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showLogoutDialog(),
              tooltip: 'Çıkış Yap',
            ),
          ],
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
        return _buildCategoryList(_liveCategories, 'live');
      case 2: // Filmler
        return _buildCategoryList(_movieCategories, 'movie');
      case 3: // Diziler
        return _buildCategoryList(_seriesCategories, 'series');
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
    return const Center(
      child: Text(
        'Yakında burada yeni içerikler gösterilecek',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildCategoryList(List<Map<String, dynamic>> categories, String contentType) {
    if (categories.isEmpty) {
      return Center(
        child: Text(
          contentType == 'live' 
              ? 'Hiç TV kanalı kategorisi bulunamadı' 
              : contentType == 'movie' 
                  ? 'Hiç film kategorisi bulunamadı' 
                  : 'Hiç dizi kategorisi bulunamadı',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return ListTile(
          title: Text(
            category['category_name'] ?? 'İsimsiz Kategori',
            style: const TextStyle(color: Colors.white),
          ),
          leading: Icon(
            contentType == 'live' 
                ? Icons.tv 
                : contentType == 'movie' 
                    ? Icons.movie 
                    : Icons.video_library,
            color: Colors.blue,
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: Colors.blue,
            size: 16,
          ),
          onTap: () {
            _loadCategoryContent(
              category['category_id'].toString(),
              category['category_name'] ?? 'İsimsiz Kategori',
              contentType,
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryContent() {
    if (_selectedCategoryContent.isEmpty) {
      return Center(
        child: Text(
          'Bu kategoride içerik bulunamadı',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _selectedCategoryContent.length,
      itemBuilder: (context, index) {
        final item = _selectedCategoryContent[index];
        final contentItem = ContentItem.fromJson(item, _currentContentType);
        
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              _playContent(contentItem);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (contentItem.streamIcon != null && contentItem.streamIcon!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: contentItem.streamIcon!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
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
                    color: Colors.grey[800],
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
        );
      },
    );
  }

  void _playContent(ContentItem item) {
    // Eğer içerik türü dizi ise, dizi detay ekranına yönlendir
    if (item.streamType == 'series') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeriesDetailScreen(seriesItem: item),
        ),
      );
    } else {
      // Diğer içerik türleri için doğrudan oynatıcıya yönlendir
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(contentItem: item),
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
} 