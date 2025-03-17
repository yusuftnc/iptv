import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/content_item.dart';
import '../services/iptv_service.dart';
import '../services/storage_service.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final IptvService _iptvService = IptvService();
  final StorageService _storageService = StorageService();
  
  bool _isLoading = false;
  String _errorMessage = '';
  SearchResults _searchResults = SearchResults(channels: [], movies: [], series: []);
  List<String> _searchHistory = [];
  
  // Filtreler
  bool _includeChannels = true;
  bool _includeMovies = true;
  bool _includeSeries = true;
  
  // Sıralama
  String _sortType = 'name'; // 'name' veya 'date'
  bool _sortAscending = true;
  
  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSearchHistory() async {
    try {
      final history = await _storageService.getSearchHistory();
      setState(() {
        _searchHistory = history;
      });
    } catch (e) {
      print('Arama geçmişi yüklenirken hata: $e');
    }
  }
  
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      // Arama yap
      final results = await _iptvService.search(
        query,
        includeChannels: _includeChannels,
        includeMovies: _includeMovies,
        includeSeries: _includeSeries,
        sortOrder: _sortAscending ? 'asc' : 'desc',
      );
      
      // Sonuçları sırala
      SearchResults sortedResults;
      if (_sortType == 'date') {
        sortedResults = await _iptvService.sortResultsByDate(results, _sortAscending);
      } else {
        sortedResults = await _iptvService.sortResultsByName(results, _sortAscending);
      }
      
      // Arama geçmişine ekle
      await _storageService.addToSearchHistory(query);
      await _loadSearchHistory();
      
      setState(() {
        _searchResults = sortedResults;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Arama yapılırken hata oluştu: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  void _removeFromHistory(String query) async {
    await _storageService.removeFromSearchHistory(query);
    await _loadSearchHistory();
  }
  
  void _clearSearchHistory() async {
    await _storageService.clearSearchHistory();
    await _loadSearchHistory();
  }
  
  void _playContent(Map<String, dynamic> item, String contentType) {
    final contentItem = ContentItem.fromJson(item, contentType);
    
    if (contentType == 'series') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeriesDetailScreen(seriesItem: contentItem),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(contentItem: contentItem),
        ),
      );
    }
  }
  
  void _updateSort(String sortType, bool ascending) {
    setState(() {
      _sortType = sortType;
      _sortAscending = ascending;
    });
    
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }
  
  void _updateFilters({bool? channels, bool? movies, bool? series}) {
    setState(() {
      if (channels != null) _includeChannels = channels;
      if (movies != null) _includeMovies = movies;
      if (series != null) _includeSeries = series;
    });
    
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Arama'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Arama çubuğu
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Film, dizi veya kanal ara...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = SearchResults(channels: [], movies: [], series: []);
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (value) {
                _performSearch(value);
              },
              onChanged: (value) {
                setState(() {});
              },
              textInputAction: TextInputAction.search,
            ),
          ),
          
          // Filtre ve sıralama çubuğu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                // Filtreler
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Kanallar'),
                          selected: _includeChannels,
                          onSelected: (selected) {
                            _updateFilters(channels: selected);
                          },
                          backgroundColor: Colors.grey[800],
                          selectedColor: Colors.blue,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _includeChannels ? Colors.white : Colors.grey[300],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Filmler'),
                          selected: _includeMovies,
                          onSelected: (selected) {
                            _updateFilters(movies: selected);
                          },
                          backgroundColor: Colors.grey[800],
                          selectedColor: Colors.blue,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _includeMovies ? Colors.white : Colors.grey[300],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Diziler'),
                          selected: _includeSeries,
                          onSelected: (selected) {
                            _updateFilters(series: selected);
                          },
                          backgroundColor: Colors.grey[800],
                          selectedColor: Colors.blue,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _includeSeries ? Colors.white : Colors.grey[300],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Sıralama butonu
                PopupMenuButton<Map<String, dynamic>>(
                  icon: const Icon(Icons.sort, color: Colors.blue),
                  tooltip: 'Sırala',
                  onSelected: (value) {
                    _updateSort(value['type'], value['ascending']);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: {'type': 'name', 'ascending': true},
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            color: _sortType == 'name' && _sortAscending ? Colors.blue : Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('A-Z'),
                          if (_sortType == 'name' && _sortAscending)
                            const Icon(Icons.check, color: Colors.blue, size: 18),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: {'type': 'name', 'ascending': false},
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            color: _sortType == 'name' && !_sortAscending ? Colors.blue : Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Z-A'),
                          if (_sortType == 'name' && !_sortAscending)
                            const Icon(Icons.check, color: Colors.blue, size: 18),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: {'type': 'date', 'ascending': false},
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: _sortType == 'date' && !_sortAscending ? Colors.blue : Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Yeniden Eskiye'),
                          if (_sortType == 'date' && !_sortAscending)
                            const Icon(Icons.check, color: Colors.blue, size: 18),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: {'type': 'date', 'ascending': true},
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: _sortType == 'date' && _sortAscending ? Colors.blue : Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Eskiden Yeniye'),
                          if (_sortType == 'date' && _sortAscending)
                            const Icon(Icons.check, color: Colors.blue, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // İçerik alanı
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                : _errorMessage.isNotEmpty
                    ? Center(
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
                              onPressed: () => _performSearch(_searchController.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
                      )
                    : _searchController.text.isEmpty
                        ? _buildSearchHistory()
                        : _buildSearchResults(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return const Center(
        child: Text(
          'Arama geçmişi boş',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Son Aramalar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _clearSearchHistory,
                child: const Text(
                  'Tümünü Temizle',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchHistory.length,
            itemBuilder: (context, index) {
              final query = _searchHistory[index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(
                  query,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: () => _removeFromHistory(query),
                ),
                onTap: () {
                  _searchController.text = query;
                  _performSearch(query);
                },
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              color: Colors.grey,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              '"${_searchController.text}" için sonuç bulunamadı',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return ListView(
      children: [
        // Kanallar
        if (_includeChannels && _searchResults.channels.isNotEmpty) ...[
          _buildSectionHeader('Kanallar', _searchResults.channels.length),
          _buildChannelsList(_searchResults.channels),
        ],
        
        // Filmler
        if (_includeMovies && _searchResults.movies.isNotEmpty) ...[
          _buildSectionHeader('Filmler', _searchResults.movies.length),
          _buildContentGrid(_searchResults.movies, 'movie'),
        ],
        
        // Diziler
        if (_includeSeries && _searchResults.series.isNotEmpty) ...[
          _buildSectionHeader('Diziler', _searchResults.series.length),
          _buildContentGrid(_searchResults.series, 'series'),
        ],
      ],
    );
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
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return ListTile(
          leading: channel['stream_icon'] != null && channel['stream_icon'].isNotEmpty
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
          onTap: () => _playContent(channel, 'live'),
        );
      },
    );
  }
  
  Widget _buildContentGrid(List<Map<String, dynamic>> items, String contentType) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final iconUrl = contentType == 'series'
            ? item['cover']
            : item['stream_icon'];
        
        return Card(
          clipBehavior: Clip.antiAlias,
          color: Colors.grey[900],
          child: InkWell(
            onTap: () => _playContent(item, contentType),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (iconUrl != null && iconUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: iconUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: Icon(
                        contentType == 'movie' ? Icons.movie : Icons.video_library,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Container(
                    color: Colors.grey[800],
                    child: Icon(
                      contentType == 'movie' ? Icons.movie : Icons.video_library,
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
                      item['name'] ?? 'İsimsiz İçerik',
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
} 