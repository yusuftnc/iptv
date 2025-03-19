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
                    pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 100),
                  ),
                );
              },
              tooltip: 'Ara',
            ),
            IconButton(
              icon: const Icon(Icons.favorite),
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const FavoritesScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 100),
                  ),
                );
              },
              tooltip: 'Favoriler',
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

    // Performans optimizasyonu için sabit değerler
    const separatorHeight = 1.0;
    const separatorIndent = 70.0;
    const arrowSize = 16.0;
    
    return ListView.separated(
      cacheExtent: 120.0, // Daha fazla öğeyi önbelleğe al
      itemCount: categories.length,
      separatorBuilder: (context, index) => const Divider(
        color: Colors.grey,
        height: separatorHeight,
        indent: separatorIndent,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        return CategoryListItem(
          category: category,
          contentType: contentType,
          onTap: () => _loadCategoryContent(
            category['category_id'].toString(),
            category['category_name'] ?? 'İsimsiz Kategori',
            contentType,
          ),
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
      itemBuilder: (context, index) {
        final item = _selectedCategoryContent[index];
        final contentItem = ContentItem.fromJson(item, _currentContentType);
        
        // İkon widget'ını önceden oluştur
        final iconWidget = _currentContentType == 'live'
            ? const Icon(Icons.tv, size: 30, color: Colors.white)
            : _currentContentType == 'movie'
                ? const Icon(Icons.movie, size: 30, color: Colors.white)
                : const Icon(Icons.video_library, size: 30, color: Colors.white);
        
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
                      child: iconWidget,
                    ),
                  )
                else
                  Container(
                    color: Colors.grey[800],
                    child: iconWidget,
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
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => SeriesDetailScreen(seriesItem: item),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 100),
        ),
      );
    } else {
      // Diğer içerik türleri için doğrudan oynatıcıya yönlendir
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(contentItem: item),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 100),
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