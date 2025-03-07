import 'dart:convert';
import 'package:http/http.dart' as http;

class IptvService {
  String? _host;
  String? _port;
  String? _username;
  String? _password;
  String? _serverUrl;
  Map<String, String> _categoryNames = {};

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
  IptvService._internal();

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

      final response = await http.get(uri);

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

      final response = await http.get(uri);

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

      final response = await http.get(uri);

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
    if (_serverUrl == null || _username == null || _password == null) {
      throw Exception('IptvService not initialized');
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/player_api.php?username=$_username&password=$_password'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['user_info'] != null && data['user_info']['auth'] == 1;
      }
      return false;
    } catch (e) {
      throw Exception('Login failed: $e');
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
    if (_serverUrl == null || _username == null || _password == null) {
      throw Exception('IptvService not initialized');
    }

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/player_api.php?username=$_username&password=$_password&action=get_live_streams&category_id=$categoryId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      }
      throw Exception('Failed to load channels: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to load channels: $e');
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
      // Önce TV kategorilerini al
      final liveCategories = await getLiveCategories();
      Map<String, String> categoryMap = {};
      
      // Kategori ID'lerini ve adlarını eşleştir
      for (var category in liveCategories) {
        categoryMap[category['category_id'].toString()] = category['category_name'];
      }
      
      // Şimdi kanalları al
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_live_streams',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final result = List<Map<String, dynamic>>.from(data);
        
        // Kategori adlarını ekle
        for (var item in result) {
          final categoryId = item['category_id']?.toString() ?? '';
          item['category_name'] = categoryMap[categoryId] ?? 'Diğer';
        }
        
        return result;
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
      // Önce film kategorilerini al
      final movieCategories = await getMovieCategories();
      Map<String, String> categoryMap = {};
      
      // Kategori ID'lerini ve adlarını eşleştir
      for (var category in movieCategories) {
        categoryMap[category['category_id'].toString()] = category['category_name'];
      }
      
      // Şimdi filmleri al
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_vod_streams',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final result = List<Map<String, dynamic>>.from(data);
        
        // Debug: Tüm kategori ID'lerini ve adlarını yazdır
        print('Film kategorileri:');
        categoryMap.forEach((id, name) {
          print('ID: $id, Name: $name');
        });
        
        // Kategori adlarını ekle
        for (var item in result) {
          final categoryId = item['category_id']?.toString() ?? '';
          item['category_name'] = categoryMap[categoryId] ?? 'Diğer';
        }
        
        // Debug: Kaç film var
        print('Toplam film sayısı: ${result.length}');
        
        // Debug: Kategorilere göre film sayıları
        Map<String, int> categoryCounts = {};
        for (var item in result) {
          final categoryName = item['category_name'] ?? 'Diğer';
          categoryCounts[categoryName] = (categoryCounts[categoryName] ?? 0) + 1;
        }
        
        print('Kategorilere göre film sayıları:');
        categoryCounts.forEach((category, count) {
          print('$category: $count film');
        });
        
        return result;
      }
      return [];
    } catch (e) {
      print('Get Movies error: $e');
      return [];
    }
  }

  // Dizileri getir
  Future<List<Map<String, dynamic>>> getSeries() async {
    try {
      // Önce dizi kategorilerini al
      final seriesCategories = await getSeriesCategories();
      Map<String, String> categoryMap = {};
      
      // Kategori ID'lerini ve adlarını eşleştir
      for (var category in seriesCategories) {
        categoryMap[category['category_id'].toString()] = category['category_name'];
      }
      
      // Şimdi dizileri al
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_series',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final result = List<Map<String, dynamic>>.from(data);
        
        // Kategori adlarını ekle
        for (var item in result) {
          final categoryId = item['category_id']?.toString() ?? '';
          item['category_name'] = categoryMap[categoryId] ?? 'Diğer';
        }
        
        return result;
      }
      return [];
    } catch (e) {
      print('Get Series error: $e');
      return [];
    }
  }

  // Dizi detaylarını getir
  Future<Map<String, dynamic>> getSeriesInfo(String seriesId) async {
    try {
      final uri = Uri.parse('$_serverUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_series_info',
          'series_id': seriesId,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data;
      }
      return {};
    } catch (e) {
      print('Get Series Info error: $e');
      return {};
    }
  }

  // Dizi bölümlerini getir
  Future<Map<String, List<Map<String, dynamic>>>> getSeriesEpisodes(String seriesId) async {
    try {
      // Önce dizi bilgilerini al
      final seriesInfo = await getSeriesInfo(seriesId);
      
      if (seriesInfo.isEmpty || seriesInfo['episodes'] == null) {
        return {};
      }
      
      // Sezonlara göre bölümleri grupla
      final Map<String, List<Map<String, dynamic>>> episodesBySeason = {};
      final Map<String, dynamic> episodes = seriesInfo['episodes'];
      
      episodes.forEach((seasonKey, seasonEpisodes) {
        final List<dynamic> episodesList = seasonEpisodes;
        episodesBySeason[seasonKey] = episodesList.map((e) => e as Map<String, dynamic>).toList();
      });
      
      return episodesBySeason;
    } catch (e) {
      print('Get Series Episodes error: $e');
      return {};
    }
  }

  // Diğer IPTV işlemleri için metodlar buraya eklenecek
  // - Kanal listesi alma
  // - Yayın akışı URL'i alma
  // - EPG (Program rehberi) alma vb.
} 