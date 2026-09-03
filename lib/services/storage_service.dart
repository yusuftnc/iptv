import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iptv_app/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'credential_crypto.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Tek kayıt: AES-GCM şifreli JSON (değerler diskte düz metin değil).
  static const String _encBlobKey = 'iptv_creds_enc';

  /// Eski sürüm düz metin anahtarları (sadece göç için).
  static const String _hostKey = 'iptv_host';
  static const String _portKey = 'iptv_port';
  static const String _usernameKey = 'iptv_username';
  static const String _passwordKey = 'iptv_password';
  static const String _searchHistoryKey = 'search_history';
  static const String _preferredAudioTrackKey = 'preferred_audio_track';
  static const String _preferredSubtitleTrackKey = 'preferred_subtitle_track';

  Future<void> _deleteLegacyCredentialKeys() async {
    await _secureStorage.delete(key: _hostKey);
    await _secureStorage.delete(key: _portKey);
    await _secureStorage.delete(key: _usernameKey);
    await _secureStorage.delete(key: _passwordKey);
  }

  Map<String, String> _mapFromJsonMap(Map<String, dynamic> m) {
    return {
      'host': (m['host'] as String?) ?? '',
      'port': (m['port'] as String?) ?? '',
      'username': (m['username'] as String?) ?? '',
      'password': (m['password'] as String?) ?? '',
    };
  }

  // Giriş bilgilerini kaydet
  Future<void> saveCredentials({
    required String host,
    required String port,
    required String username,
    required String password,
  }) async {
    final payload = json.encode({
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    });
    final sealed = await CredentialCrypto.encryptJson(payload);
    await _secureStorage.write(key: _encBlobKey, value: sealed);
    await _deleteLegacyCredentialKeys();
  }

  // Giriş bilgilerini getir
  Future<Map<String, String>> getCredentials() async {
    final sealed = await _secureStorage.read(key: _encBlobKey);
    if (sealed != null && sealed.isNotEmpty) {
      try {
        final clear = await CredentialCrypto.decryptToUtf8(sealed);
        final decoded = json.decode(clear) as Map<String, dynamic>;
        return _mapFromJsonMap(decoded);
      } catch (e, st) {
        Log.e('StorageService', e, st);
        await clearCredentials();
        return {
          'host': '',
          'port': '',
          'username': '',
          'password': '',
        };
      }
    }

    final host = await _secureStorage.read(key: _hostKey) ?? '';
    final port = await _secureStorage.read(key: _portKey) ?? '';
    final username = await _secureStorage.read(key: _usernameKey) ?? '';
    final password = await _secureStorage.read(key: _passwordKey) ?? '';

    if (host.isNotEmpty &&
        port.isNotEmpty &&
        username.isNotEmpty &&
        password.isNotEmpty) {
      await saveCredentials(
        host: host,
        port: port,
        username: username,
        password: password,
      );
    }

    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
  }

  // Giriş bilgileri var mı kontrol et
  Future<bool> hasCredentials() async {
    final sealed = await _secureStorage.read(key: _encBlobKey);
    if (sealed != null && sealed.isNotEmpty) {
      return true;
    }

    final host = await _secureStorage.read(key: _hostKey);
    final port = await _secureStorage.read(key: _portKey);
    final username = await _secureStorage.read(key: _usernameKey);
    final password = await _secureStorage.read(key: _passwordKey);

    return host != null &&
        port != null &&
        username != null &&
        password != null &&
        host.isNotEmpty &&
        port.isNotEmpty &&
        username.isNotEmpty &&
        password.isNotEmpty;
  }

  // Giriş bilgilerini sil
  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _encBlobKey);
    await _deleteLegacyCredentialKeys();
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
      Log.d("DBG", 'Arama geçmişi çözümlenirken hata: $e');
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

  /// Kullanıcının seçtiği ses parçası adı (track id bölümden bölüme değişir).
  Future<void> savePreferredAudioTrack(String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredAudioTrackKey, label);
  }

  Future<String?> getPreferredAudioTrack() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_preferredAudioTrackKey);
  }

  /// Altyazı etiketi; boş veya "__off__" = kapalı.
  Future<void> savePreferredSubtitleTrack(String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredSubtitleTrackKey, label);
  }

  Future<String?> getPreferredSubtitleTrack() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_preferredSubtitleTrackKey);
  }

  static const String subtitleOffSentinel = '__off__';
}
