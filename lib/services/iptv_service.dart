import 'dart:convert';
import 'package:http/http.dart' as http;

class IptvService {
  String? _baseUrl;
  String? _username;
  String? _password;

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
    _baseUrl = 'http://$host:$port';
    _username = username;
    _password = password;
  }

  Future<bool> login() async {
    try {
      if (_baseUrl == null || _username == null || _password == null) {
        throw Exception('Service not initialized');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/player_api.php'),
        body: {
          'username': _username,
          'password': _password,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Tipik bir IPTV sunucusu başarılı girişte user_info döndürür
        return data['user_info'] != null;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // TV Kanallarını getir
  Future<List<Map<String, dynamic>>> getLiveTV() async {
    try {
      final uri = Uri.parse('$_baseUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_live_streams',
        },
      );

      final response = await http.get(uri);

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
      final uri = Uri.parse('$_baseUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_vod_streams',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
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
      final uri = Uri.parse('$_baseUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': 'get_series',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      print('Get Series error: $e');
      return [];
    }
  }

  // Yayın URL'ini al
  Future<String?> getStreamUrl({
    required String streamId,
    required String streamType, // 'live', 'movie', 'series'
  }) async {
    try {
      if (_baseUrl == null || _username == null || _password == null) {
        throw Exception('Service not initialized');
      }

      // Önce stream detaylarını alalım
      final action = streamType == 'live' ? 'get_live_streams' :
                     streamType == 'movie' ? 'get_vod_streams' : 'get_series';

      final uri = Uri.parse('$_baseUrl/player_api.php').replace(
        queryParameters: {
          'username': _username,
          'password': _password,
          'action': action,
          'stream_id': streamId,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Streaming URL'ini oluştur
        final extension = streamType == 'live' ? 'ts' : 'm3u8';
        
        // Modern IPTV sistemleri için XC style URL
        final xcStyleUrl = '$_baseUrl/$streamType/$_username/$_password/$streamId.$extension';
        
        // Eski stil URL (bazı sistemler hala bunu kullanır)
        final legacyStyleUrl = '$_baseUrl/streaming/$streamType/$streamId?username=$_username&password=$_password&type=$extension';
        
        // Önce XC style URL'i dene, çalışmazsa legacy URL'e geri dön
        return xcStyleUrl;
      }
      return null;
    } catch (e) {
      print('Get Stream URL error: $e');
      return null;
    }
  }

  // Diğer IPTV işlemleri için metodlar buraya eklenecek
  // - Kanal listesi alma
  // - Yayın akışı URL'i alma
  // - EPG (Program rehberi) alma vb.
} 