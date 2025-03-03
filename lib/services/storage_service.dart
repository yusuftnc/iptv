import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Anahtar sabitleri
  static const String _hostKey = 'iptv_host';
  static const String _portKey = 'iptv_port';
  static const String _usernameKey = 'iptv_username';
  static const String _passwordKey = 'iptv_password';
  
  // Giriş bilgilerini kaydet
  Future<void> saveCredentials({
    required String host,
    required String port,
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _hostKey, value: host);
    await _storage.write(key: _portKey, value: port);
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _passwordKey, value: password);
  }
  
  // Giriş bilgilerini getir
  Future<Map<String, String>> getCredentials() async {
    final host = await _storage.read(key: _hostKey) ?? '';
    final port = await _storage.read(key: _portKey) ?? '';
    final username = await _storage.read(key: _usernameKey) ?? '';
    final password = await _storage.read(key: _passwordKey) ?? '';
    
    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
  }
  
  // Giriş bilgileri var mı kontrol et
  Future<bool> hasCredentials() async {
    final host = await _storage.read(key: _hostKey);
    final port = await _storage.read(key: _portKey);
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);
    
    return host != null && port != null && username != null && password != null &&
           host.isNotEmpty && port.isNotEmpty && username.isNotEmpty && password.isNotEmpty;
  }
  
  // Giriş bilgilerini sil
  Future<void> clearCredentials() async {
    await _storage.delete(key: _hostKey);
    await _storage.delete(key: _portKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
  }
} 