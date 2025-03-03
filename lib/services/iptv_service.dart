import 'dart:convert';
import 'package:http/http.dart' as http;

class IptvService {
  String? _host;
  String? _port;
  String? _username;
  String? _password;
  String? _serverUrl;
  Map<String, String> _categoryNames = {};

  // Singleton pattern
  static final IptvService _instance = IptvService._internal();
  factory IptvService() => _instance;
  IptvService._internal();

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
    String extension = 'ts',
  }) async {
    if (_serverUrl == null || _username == null || _password == null) {
      throw Exception('IptvService not initialized');
    }
    
    // Modern IPTV sistemleri için XC style URL
    final xcStyleUrl = '$_serverUrl/$streamType/$_username/$_password/$streamId.$extension';
    
    // Eski stil URL (bazı sistemler hala bunu kullanır)
    final legacyStyleUrl = '$_serverUrl/streaming/$streamType/$streamId?username=$_username&password=$_password&type=$extension';
    
    // Önce XC style URL'i dene, çalışmazsa legacy URL'e geri dön
    try {
      final response = await http.head(Uri.parse(xcStyleUrl));
      if (response.statusCode == 200) {
        return xcStyleUrl;
      }
    } catch (_) {
      // XC style URL çalışmadı, legacy URL'i dene
    }
    
    try {
      final response = await http.head(Uri.parse(legacyStyleUrl));
      if (response.statusCode == 200) {
        return legacyStyleUrl;
      }
    } catch (_) {
      // Legacy URL de çalışmadı
    }
    
    // Hiçbir URL çalışmadıysa, varsayılan olarak XC style URL'i döndür
    return xcStyleUrl;
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

  // Diğer IPTV işlemleri için metodlar buraya eklenecek
  // - Kanal listesi alma
  // - Yayın akışı URL'i alma
  // - EPG (Program rehberi) alma vb.
} 