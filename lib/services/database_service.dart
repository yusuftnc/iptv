import 'package:hive/hive.dart';
import '../models/favorite_item.dart';
import '../models/watch_history.dart';
import '../models/user_settings.dart';
import '../models/content_item.dart';

class DatabaseService {
  static const String _favoritesBox = 'favorites';
  static const String _watchHistoryBox = 'watchHistory';
  static const String _settingsBox = 'settings';
  
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  
  factory DatabaseService() {
    return _instance;
  }
  
  DatabaseService._internal();
  
  // Favoriler
  Future<List<FavoriteItem>> getFavorites() async {
    final box = await Hive.openBox<FavoriteItem>(_favoritesBox);
    return box.values.toList();
  }
  
  Future<void> addFavorite(ContentItem contentItem) async {
    final box = await Hive.openBox<FavoriteItem>(_favoritesBox);
    
    final favorite = FavoriteItem(
      id: contentItem.id,
      name: contentItem.name,
      streamType: contentItem.streamType ?? 'live',
      streamIcon: contentItem.streamIcon,
      category: contentItem.category,
      streamUrl: contentItem.streamUrl,
      description: contentItem.description,
    );
    
    await box.put(contentItem.id, favorite);
  }
  
  Future<void> removeFavorite(String contentId) async {
    final box = await Hive.openBox<FavoriteItem>(_favoritesBox);
    await box.delete(contentId);
  }
  
  Future<bool> isFavorite(String contentId) async {
    final box = await Hive.openBox<FavoriteItem>(_favoritesBox);
    return box.containsKey(contentId);
  }
  
  // İzleme Geçmişi
  Future<List<WatchHistory>> getWatchHistory() async {
    final box = await Hive.openBox<WatchHistory>(_watchHistoryBox);
    final List<WatchHistory> history = box.values.toList();
    // En son izlenenler en üstte olacak şekilde sırala
    history.sort((a, b) => b.watchDate.compareTo(a.watchDate));
    return history;
  }
  
  Future<void> addToWatchHistory(ContentItem contentItem) async {
    try {
      print("Debug - Database addToWatchHistory - ContentID: ${contentItem.id}, Pozisyon: ${contentItem.position}, Süre: ${contentItem.duration}");
      final box = await Hive.openBox<WatchHistory>(_watchHistoryBox);
      
      final watchItem = WatchHistory(
        contentId: contentItem.id,
        name: contentItem.name,
        streamType: contentItem.streamType ?? 'live',
        streamIcon: contentItem.streamIcon,
        position: contentItem.position,
        duration: contentItem.duration,
        streamUrl: contentItem.streamUrl,
        category: contentItem.category,
      );
      
      // Aynı içerik zaten varsa güncelle
      await box.put(contentItem.id, watchItem);
      
      // Kaydettikten sonra kontrol et
      final savedItem = box.get(contentItem.id);
      print("Debug - Database kaydedilen: ContentID: ${savedItem?.contentId}, Pozisyon: ${savedItem?.position}, Süre: ${savedItem?.duration}");
    } catch (e) {
      print("Debug - Database addToWatchHistory hata: $e");
    }
  }
  
  Future<void> removeFromWatchHistory(String contentId) async {
    final box = await Hive.openBox<WatchHistory>(_watchHistoryBox);
    await box.delete(contentId);
  }
  
  Future<void> clearWatchHistory() async {
    final box = await Hive.openBox<WatchHistory>(_watchHistoryBox);
    await box.clear();
  }
  
  Future<WatchHistory?> getWatchPosition(String contentId) async {
    final box = await Hive.openBox<WatchHistory>(_watchHistoryBox);
    final result = box.get(contentId);
    print("Debug - Database getWatchPosition - ContentID: $contentId, Pozisyon: ${result?.position}, Süre: ${result?.duration}");
    return result;
  }
  
  // Kullanıcı Ayarları
  Future<UserSettings> getUserSettings() async {
    final box = await Hive.openBox<UserSettings>(_settingsBox);
    return box.get('userSettings') ?? UserSettings();
  }
  
  Future<void> saveUserSettings(UserSettings settings) async {
    final box = await Hive.openBox<UserSettings>(_settingsBox);
    await box.put('userSettings', settings);
  }
  
  Future<void> updateSetting(String key, dynamic value) async {
    final settings = await getUserSettings();
    
    switch (key) {
      case 'darkMode':
        settings.darkMode = value as bool;
        break;
      case 'language':
        settings.language = value as String;
        break;
      case 'autoPlayNext':
        settings.autoPlayNext = value as bool;
        break;
      case 'showSubtitles':
        settings.showSubtitles = value as bool;
        break;
      case 'defaultVolume':
        settings.defaultVolume = value as int;
        break;
      case 'videoQuality':
        settings.videoQuality = value as String;
        break;
    }
    
    await saveUserSettings(settings);
  }
} 