import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Anahtar sabitleri
  static const String _hostKey = 'iptv_host';
  static const String _portKey = 'iptv_port';
  static const String _usernameKey = 'iptv_username';
  static const String _passwordKey = 'iptv_password';
  static const String _searchHistoryKey = 'search_history';
  
  // Giriş bilgilerini kaydet
  Future<void> saveCredentials({
    required String host,
    required String port,
    required String username,
    required String password,
  }) async {
    await _secureStorage.write(key: _hostKey, value: host);
    await _secureStorage.write(key: _portKey, value: port);
    await _secureStorage.write(key: _usernameKey, value: username);
    await _secureStorage.write(key: _passwordKey, value: password);
  }
  
  // Giriş bilgilerini getir
  Future<Map<String, String>> getCredentials() async {
    final host = await _secureStorage.read(key: _hostKey) ?? '';
    final port = await _secureStorage.read(key: _portKey) ?? '';
    final username = await _secureStorage.read(key: _usernameKey) ?? '';
    final password = await _secureStorage.read(key: _passwordKey) ?? '';
    
    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
  }
  
  // Giriş bilgileri var mı kontrol et
  Future<bool> hasCredentials() async {
    final host = await _secureStorage.read(key: _hostKey);
    final port = await _secureStorage.read(key: _portKey);
    final username = await _secureStorage.read(key: _usernameKey);
    final password = await _secureStorage.read(key: _passwordKey);
    
    return host != null && port != null && username != null && password != null &&
           host.isNotEmpty && port.isNotEmpty && username.isNotEmpty && password.isNotEmpty;
  }
  
  // Giriş bilgilerini sil
  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _hostKey);
    await _secureStorage.delete(key: _portKey);
    await _secureStorage.delete(key: _usernameKey);
    await _secureStorage.delete(key: _passwordKey);
  }
  
  // Arama geçmişini getir
  Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_searchHistoryKey);
    
    if (historyJson == null || historyJson.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = json.decode(historyJson);
      return decoded.map((item) => item.toString()).toList();
    } catch (e) {
      print('Arama geçmişi çözümlenirken hata: $e');
      return [];
    }
  }
  
  // Arama geçmişine ekle
  Future<void> addToSearchHistory(String query) async {
    if (query.trim().isEmpty) {
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final history = await getSearchHistory();
    
    // Eğer aynı sorgu zaten varsa, onu listeden çıkar (daha sonra başa eklemek için)
    history.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
    
    // Sorguyu listenin başına ekle (en son aramalar en üstte)
    history.insert(0, query);
    
    // Geçmişi maksimum 20 öğe ile sınırla
    if (history.length > 20) {
      history.removeLast();
    }
    
    // Geçmişi kaydet
    await prefs.setString(_searchHistoryKey, json.encode(history));
  }
  
  // Arama geçmişinden bir öğeyi sil
  Future<void> removeFromSearchHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getSearchHistory();
    
    history.removeWhere((item) => item == query);
    
    await prefs.setString(_searchHistoryKey, json.encode(history));
  }
  
  // Tüm arama geçmişini temizle
  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
  }
} 