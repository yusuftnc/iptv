import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../models/movie_details.dart';

class IptvService {
  String? _host;
  String? _port;
  String? _username;
  String? _password;
  String? _serverUrl;
  Map<String, String> _categoryNames = {};
  Map<String, dynamic>? _userInfo;
  bool _isLoggedIn = false;
  late final Dio _dio;
  
  // Arama geçmişi için anahtar
  static const String _searchHistoryKey = 'search_history';

  // Her içerik türü için çalışan formatı önbellekte tut
  final Map<String, String> _formatCache = {};
  
  // Her içerik türü için olası formatlar
  final Map<String, List<String>> _formatTemplates = {
    'live': [
      '{server}/live/{user}/{pass}/{id}.ts',
      '{server}/live/{user}/{pass}/{id}.m3u8',
      '{server}/streaming/live/{id}?username={user}&password={pass}',
      '{server}/hls/{user}/{pass}/{id}/index.m3u8',
      '{server}/{user}/{pass}/{id}'
    ],
    'movie': [
      '{server}/movie/{user}/{pass}/{id}.mkv',
      '{server}/movie/{user}/{pass}/{id}.mp4',
      '{server}/vod/{user}/{pass}/{id}.mkv',
      '{server}/vod/{user}/{pass}/{id}.mp4',
      '{server}/vod/{user}/{pass}/{id}.avi',
      '{server}/film/{user}/{pass}/{id}.mp4',
      '{server}/film/{user}/{pass}/{id}.mkv',
      '{server}/streaming/vod/{id}?username={user}&password={pass}',
      '{server}/{user}/{pass}/{id}'
    ],
    'series': [
      '{server}/series/{user}/{pass}/{id}.mp4',
      '{server}/series/{user}/{pass}/{id}.mkv',
      '{server}/series/{user}/{pass}/{id}.ts',
      '{server}/series/{user}/{pass}/{id}.m3u8',
      '{server}/series/{user}/{pass}/{id}',
      '{server}/series/{user}/{pass}/{id}/index.m3u8',
      '{server}/series/{user}/{pass}/series/{id}.mp4',
      '{server}/series/{user}/{pass}/series/{id}.mkv',
      '{server}/series/{user}/{pass}/series/{id}.ts',
      '{server}/series/{user}/{pass}/series/{id}.m3u8',
      '{server}/streaming/series/{id}?username={user}&password={pass}',
      '{server}/player_api.php?username={user}&password={pass}&action=get_series_info&series_id={id}',
      '{server}/vod/{user}/{pass}/{id}.mp4',
      '{server}/vod/{user}/{pass}/{id}.mkv',
      '{server}/{user}/{pass}/{id}'
    ]
  };

  // Singleton pattern
  static final IptvService _instance = IptvService._internal();
  factory IptvService() => _instance;
  IptvService._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ));
  }

  // Getter metodları
  String? getServerUrl() => _serverUrl;
  String? getUsername() => _username;
  String? getPassword() => _password;

  Future<void> initialize({
    required String host,
    required String port,
    required String username,
    required String password,
  }) async {
    _host = host;
    _port = port;
    _username = username;
    _password = password;
    _serverUrl = 'http://$_host:$_port';
    
    // Önbelleği temizle (yeni giriş yapıldığında)
    _formatCache.clear();
  }

  Future<void> _loadCategories() async {
    try {
      final liveCategories = await getLiveCategories();
      final movieCategories = await getMovieCategories();
      final seriesCategories = await getSeriesCategories();
      
      _categoryNames.clear();
      
      for (var category in [...liveCategories, ...movieCategories, ...seriesCategories]) {
        _categoryNames[category['category_id'].toString()] = category['category_name'];
      }
    } catch (e) {
      print('Load categories error: $e');
    }
  }

  // TV Kategorilerini getir
  Future<List<Map<String, dynamic>>> getLiveCategories() async {
    try {
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_live_categories',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      print('Get Live Categories error: $e');
      return [];
    }
  }

  // Film Kategorilerini getir
  Future<List<Map<String, dynamic>>> getMovieCategories() async {
    try {
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_vod_categories',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      print('Get Movie Categories error: $e');
      return [];
    }
  }

  // Dizi Kategorilerini getir
  Future<List<Map<String, dynamic>>> getSeriesCategories() async {
    try {
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_series_categories',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      print('Get Series Categories error: $e');
      return [];
    }
  }

  Future<bool> login() async {
    try {
      print('Debug - Attempting login with URL: $_serverUrl');
      final response = await _dio.get(
        '$_serverUrl/player_api.php',
        queryParameters: {
          'username': _username,
          'password': _password,
        },
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status! < 500,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      print('Debug - Login response status: ${response.statusCode}');
      print('Debug - Login response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          print('Debug - Login successful, user info received');
          _userInfo = data;
          _isLoggedIn = true;
          return true;
        } else {
          print('Debug - Login failed: Response data is not a Map');
          return false;
        }
      }
      print('Debug - Login failed: Status code ${response.statusCode}');
      return false;
    } on DioException catch (e) {
      print('Debug - Login DioException: ${e.message}');
      print('Debug - DioException type: ${e.type}');
      print('Debug - DioException response: ${e.response?.data}');
      
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Bağlantı zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Sunucuya bağlanılamıyor. Lütfen internet bağlantınızı kontrol edin.');
      }
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      print('Debug - Unexpected login error: $e');
      throw Exception('Beklenmeyen bir hata oluştu: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    if (_serverUrl == null || _username == null || _password == null) {
      throw Exception('IptvService not initialized');
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/player_api.php?username=$_username&password=$_password&action=get_live_categories'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      }
      throw Exception('Failed to load categories: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getChannels(String categoryId) async {
    try {
      print('Debug - Getting channels for category: $categoryId');
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_live_streams',
          'category_id': categoryId,
        },
      );

      print('Debug - Request URL: ${uri.toString()}');
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      print('Debug - Response status: ${response.statusCode}');
      print('Debug - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data is List) {
          return data.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Debug - Get Live TV error: $e');
      return [];
    }
  }

  Future<String?> getStreamUrl({
    required String streamId,
    required String streamType,
  }) async {
    if (_serverUrl == null || _username == null || _password == null) {
      throw Exception('IptvService not initialized');
    }
    
    // Önbellekte bu tür için çalışan bir format var mı?
    if (_formatCache.containsKey(streamType)) {
      final formatTemplate = _formatCache[streamType]!;
      final url = _applyTemplate(formatTemplate, streamId, streamType);
      
      // Önbellekteki format çalışıyor mu kontrol et (opsiyonel)
      try {
        final response = await http.head(Uri.parse(url))
            .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
          print('Debug - Önbellekteki format çalışıyor: $url');
          return url; // Önbellekteki format çalışıyor
        }
      } catch (_) {
        // Önbellekteki format artık çalışmıyor, önbelleği temizle
        print('Debug - Önbellekteki format çalışmıyor, temizleniyor');
        _formatCache.remove(streamType);
      }
    }
    
    // İçerik türü için olası formatları al
    final templates = _formatTemplates[streamType] ?? [];
    if (templates.isEmpty) {
      // Bilinmeyen içerik türü için varsayılan format
      final defaultUrl = '{server}/{type}/{user}/{pass}/{id}'
          .replaceAll('{server}', _serverUrl!)
          .replaceAll('{type}', streamType)
          .replaceAll('{user}', _username!)
          .replaceAll('{pass}', _password!)
          .replaceAll('{id}', streamId);
      
      print('Debug - Bilinmeyen içerik türü için varsayılan URL: $defaultUrl');
      return defaultUrl;
    }
    
    print('Debug - ${templates.length} format deneniyor...');
    
    // Her formatı dene
    for (final template in templates) {
      final url = _applyTemplate(template, streamId, streamType);
      
      try {
        print('Debug - Deneniyor: $url');
        final response = await http.head(Uri.parse(url))
            .timeout(const Duration(seconds: 3));
        
      if (response.statusCode == 200) {
          // Çalışan formatı önbelleğe al
          _formatCache[streamType] = template;
          print('Debug - Çalışan format bulundu ve önbelleğe alındı: $url');
          return url;
        }
      } catch (e) {
        // Bu format çalışmadı, bir sonrakini dene
        print('Debug - Format çalışmadı: $url, Hata: $e');
        continue;
      }
    }
    
    // Hiçbir format çalışmadıysa, varsayılan formatı döndür
    final defaultTemplate = templates.first;
    final defaultUrl = _applyTemplate(defaultTemplate, streamId, streamType);
    print('Debug - Hiçbir format çalışmadı, varsayılan döndürülüyor: $defaultUrl');
    return defaultUrl;
  }
  
  // Format şablonunu uygula
  String _applyTemplate(String template, String streamId, String streamType) {
    return template
        .replaceAll('{server}', _serverUrl!)
        .replaceAll('{user}', _username!)
        .replaceAll('{pass}', _password!)
        .replaceAll('{id}', streamId)
        .replaceAll('{type}', streamType);
  }

  // TV Kanallarını getir
  Future<List<Map<String, dynamic>>> getLiveTV() async {
    try {
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_live_streams',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      print('Get Live TV error: $e');
      return [];
    }
  }

  // Filmleri getir
  Future<List<Map<String, dynamic>>> getMovies() async {
    try {
      print('Debug - Getting all movies');
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_vod_streams',
        },
      );

      print('Debug - Request URL: ${uri.toString()}');
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      print('Debug - Response status: ${response.statusCode}');
      print('Debug - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data is List) {
          return data.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Debug - Get Movies error: $e');
      return [];
    }
  }

  // Dizileri getir
  Future<List<Map<String, dynamic>>> getSeries() async {
    try {
      print('Debug - Getting all series');
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_series',
        },
      );

      print('Debug - Request URL: ${uri.toString()}');
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      print('Debug - Response status: ${response.statusCode}');
      print('Debug - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data is List) {
          return data.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Debug - Get Series error: $e');
      return [];
    }
  }

  // Dizi detaylarını getir
  Future<Map<String, dynamic>> getSeriesInfo(String seriesId) async {
    try {
      print('Debug - Getting series info for ID: $seriesId');
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_series_info',
          'series_id': seriesId,
        },
      );

      print('Debug - Request URL: ${uri.toString().replaceAll(_password!, '****')}');
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      print('Debug - Response status: ${response.statusCode}');
      print('Debug - Response headers: ${response.headers}');
      print('Debug - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          // Dizi bilgilerini döndür
          return {
            'name': data['name'] ?? '',
            'plot': data['plot'] ?? '',
            'cast': data['cast'] ?? '',
            'director': data['director'] ?? '',
            'genre': data['genre'] ?? '',
            'releaseDate': data['releaseDate'] ?? '',
            'rating': data['rating'] ?? '',
            'cover': data['cover'] ?? '',
            'banner': data['banner'] ?? '',
            'episodes': data['episodes'] ?? {},
          };
        }
      }
      return {};
    } catch (e) {
      print('Get Series Info error: $e');
      return {};
    }
  }

  // Film detaylarını getir
  Future<MovieDetails> getMovieInfo(String movieId) async {
    final url = Uri.parse('$_serverUrl/player_api.php');
    final response = await http.get(url.replace(queryParameters: {
      'username': _username,
      'password': _password,
      'action': 'get_vod_info',
      'vod_id': movieId,
    }));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return MovieDetails.fromJson(data);
    } else {
      throw Exception('Film bilgileri alınamadı');
    }
  }

  // Dizi bölümlerini getir
  Future<Map<String, List<Map<String, dynamic>>>> getSeriesEpisodes(String seriesId) async {
    try {
      print('Debug - Getting episodes for series ID: $seriesId');
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_series_info',
          'series_id': seriesId,
        },
      );

      print('Debug - Request URL: ${uri.toString().replaceAll(_password!, '****')}');
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      print('Debug - Response status: ${response.statusCode}');
      print('Debug - Response headers: ${response.headers}');
      print('Debug - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['episodes'] != null) {
          final episodes = data['episodes'] as Map<String, dynamic>;
          final result = <String, List<Map<String, dynamic>>>{};
          
          episodes.forEach((season, seasonEpisodes) {
            if (seasonEpisodes is List) {
              final episodeList = seasonEpisodes.map((episode) {
                if (episode is Map<String, dynamic>) {
                  return {
                    'id': episode['id']?.toString() ?? '',
                    'title': episode['title'] ?? '',
                    'container_extension': episode['container_extension'] ?? '',
                    'info': episode['info'] ?? {},
                    'season': season,
                  };
                }
                return <String, dynamic>{};
              }).toList();
              
              result[season] = episodeList;
            }
          });
          
          return result;
        }
      }
      return {};
    } catch (e) {
      print('Get Series Episodes error: $e');
      return {};
    }
  }

  // Tüm arama geçmişini temizle
  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
  }

  // Arama yap
  Future<SearchResults> search(String query, {
    bool includeChannels = true,
    bool includeMovies = true,
    bool includeSeries = true,
    String sortOrder = 'asc', // 'asc' veya 'desc'
  }) async {
    if (_serverUrl == null || _username == null || _password == null) {
      throw Exception('IptvService not initialized');
    }

    if (query.trim().isEmpty) {
      return SearchResults(channels: [], movies: [], series: []);
    }

    final normalizedQuery = query.toLowerCase().trim();
    
    List<Map<String, dynamic>> channelResults = [];
    List<Map<String, dynamic>> movieResults = [];
    List<Map<String, dynamic>> seriesResults = [];

    try {
      // Kanalları ara
      if (includeChannels) {
        final allChannels = await getLiveTV();
        channelResults = allChannels.where((channel) {
          final name = (channel['name'] ?? '').toLowerCase();
          final description = (channel['description'] ?? '').toLowerCase();
          return name.contains(normalizedQuery) || description.contains(normalizedQuery);
        }).toList();
      }

      // Filmleri ara
      if (includeMovies) {
        final allMovies = await getMovies();
        movieResults = allMovies.where((movie) {
          final name = (movie['name'] ?? '').toLowerCase();
          final description = (movie['description'] ?? '').toLowerCase();
          final plot = (movie['plot'] ?? '').toLowerCase();
          final cast = (movie['cast'] ?? '').toLowerCase();
          final director = (movie['director'] ?? '').toLowerCase();
          final genre = (movie['genre'] ?? '').toLowerCase();
          
          return name.contains(normalizedQuery) || 
                 description.contains(normalizedQuery) || 
                 plot.contains(normalizedQuery) ||
                 cast.contains(normalizedQuery) ||
                 director.contains(normalizedQuery) ||
                 genre.contains(normalizedQuery);
        }).toList();
      }

      // Dizileri ara
      if (includeSeries) {
        final allSeries = await getSeries();
        seriesResults = allSeries.where((series) {
          final name = (series['name'] ?? '').toLowerCase();
          final description = (series['description'] ?? '').toLowerCase();
          final plot = (series['plot'] ?? '').toLowerCase();
          final cast = (series['cast'] ?? '').toLowerCase();
          final director = (series['director'] ?? '').toLowerCase();
          final genre = (series['genre'] ?? '').toLowerCase();
          
          return name.contains(normalizedQuery) || 
                 description.contains(normalizedQuery) || 
                 plot.contains(normalizedQuery) ||
                 cast.contains(normalizedQuery) ||
                 director.contains(normalizedQuery) ||
                 genre.contains(normalizedQuery);
        }).toList();
      }

      // Sonuçları sırala
      final sortFunction = (Map<String, dynamic> a, Map<String, dynamic> b) {
        final nameA = (a['name'] ?? '').toLowerCase();
        final nameB = (b['name'] ?? '').toLowerCase();
        return sortOrder == 'asc' 
            ? nameA.compareTo(nameB) 
            : nameB.compareTo(nameA);
      };

      channelResults.sort((a, b) => sortFunction(a, b));
      movieResults.sort((a, b) => sortFunction(a, b));
      seriesResults.sort((a, b) => sortFunction(a, b));

      return SearchResults(
        channels: channelResults,
        movies: movieResults,
        series: seriesResults,
      );
    } catch (e) {
      print('Search error: $e');
      return SearchResults(channels: [], movies: [], series: []);
    }
  }

  // Tarih sıralaması için yardımcı metod
  List<Map<String, dynamic>> _sortByDate(List<Map<String, dynamic>> items, bool ascending) {
    items.sort((a, b) {
      // Önce tarih alanını bul (added, releaseDate, last_modified vb.)
      String? dateFieldA;
      String? dateFieldB;
      
      if (a.containsKey('added')) {
        dateFieldA = a['added'];
        dateFieldB = b['added'];
      } else if (a.containsKey('releaseDate')) {
        dateFieldA = a['releaseDate'];
        dateFieldB = b['releaseDate'];
      } else if (a.containsKey('last_modified')) {
        dateFieldA = a['last_modified'];
        dateFieldB = b['last_modified'];
      } else {
        // Tarih alanı bulunamadı, isme göre sırala
        final nameA = (a['name'] ?? '').toLowerCase();
        final nameB = (b['name'] ?? '').toLowerCase();
        return ascending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
      }
      
      // Tarih alanları null ise isme göre sırala
      if (dateFieldA == null || dateFieldB == null) {
        final nameA = (a['name'] ?? '').toLowerCase();
        final nameB = (b['name'] ?? '').toLowerCase();
        return ascending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
      }
      
      // Tarihleri karşılaştır
      try {
        final dateA = DateTime.parse(dateFieldA);
        final dateB = DateTime.parse(dateFieldB);
        return ascending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
      } catch (e) {
        // Tarih ayrıştırılamadı, isme göre sırala
        final nameA = (a['name'] ?? '').toLowerCase();
        final nameB = (b['name'] ?? '').toLowerCase();
        return ascending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
      }
    });
    
    return items;
  }
  
  // Sonuçları tarihe göre sırala
  Future<SearchResults> sortResultsByDate(SearchResults results, bool ascending) async {
    return SearchResults(
      channels: _sortByDate(results.channels, ascending),
      movies: _sortByDate(results.movies, ascending),
      series: _sortByDate(results.series, ascending),
    );
  }

  // Sonuçları isme göre sırala
  Future<SearchResults> sortResultsByName(SearchResults results, bool ascending) async {
    final sortFunction = (Map<String, dynamic> a, Map<String, dynamic> b) {
      final nameA = (a['name'] ?? '').toLowerCase();
      final nameB = (b['name'] ?? '').toLowerCase();
      return ascending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    };

    final channels = List<Map<String, dynamic>>.from(results.channels);
    final movies = List<Map<String, dynamic>>.from(results.movies);
    final series = List<Map<String, dynamic>>.from(results.series);

    channels.sort((a, b) => sortFunction(a, b));
    movies.sort((a, b) => sortFunction(a, b));
    series.sort((a, b) => sortFunction(a, b));

    return SearchResults(
      channels: channels,
      movies: movies,
      series: series,
    );
  }
}

// Arama sonuçları için model sınıfı
class SearchResults {
  final List<Map<String, dynamic>> channels;
  final List<Map<String, dynamic>> movies;
  final List<Map<String, dynamic>> series;

  SearchResults({
    required this.channels,
    required this.movies,
    required this.series,
  });

  bool get isEmpty => channels.isEmpty && movies.isEmpty && series.isEmpty;
  int get totalCount => channels.length + movies.length + series.length;
} 