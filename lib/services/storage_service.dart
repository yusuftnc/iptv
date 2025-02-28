import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _hostKey = 'host';
  static const String _portKey = 'port';
  static const String _usernameKey = 'username';
  static const String _passwordKey = 'password';

  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Future<void> saveCredentials({
    required String host,
    required String port,
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, host);
    await prefs.setString(_portKey, port);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_passwordKey, password);
  }

  Future<Map<String, String?>> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'host': prefs.getString(_hostKey),
      'port': prefs.getString(_portKey),
      'username': prefs.getString(_usernameKey),
      'password': prefs.getString(_passwordKey),
    };
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hostKey);
    await prefs.remove(_portKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
  }

  Future<bool> hasCredentials() async {
    final credentials = await getCredentials();
    return credentials.values.every((value) => value != null && value.isNotEmpty);
  }
} 