import 'package:hive/hive.dart';
import 'package:iptv_app/utils/logger.dart';
import '../models/favorite_item.dart';
import '../models/watch_history.dart';
import '../models/user_settings.dart';
import '../models/content_item.dart';

/// Birden fazla " - S01E" biriktiyse dizi kökü + son bölüm tek satırda (eski bug + yeni kayıt).
String _oneLineSeriesHistoryName(String name) {
  final re = RegExp(r'\s-\sS\d+E');
  final ms = re.allMatches(name).toList();
  if (ms.length <= 1) return name;
  return '${name.substring(0, ms.first.start).trim()} ${name.substring(ms.last.start).trim()}';
}

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

  Future<void> _repairSeriesWatchNames(Box<WatchHistory> box) async {
    for (final key in box.keys.toList()) {
      final item = box.get(key);
      if (item == null || item.streamType != 'series') continue;
      final fixed = _oneLineSeriesHistoryName(item.name);
      if (fixed == item.name) continue;
      final w = WatchHistory(
        contentId: item.contentId,
        name: fixed,
        streamType: item.streamType,
        streamIcon: item.streamIcon,
        position: item.position,
        duration: item.duration,
        streamUrl: item.streamUrl,
        category: item.category,
        historyId: item.historyId,
      );
      w.watchDate = item.watchDate;
      await box.put(key, w);
    }
  }

  // Favoriler
  Future<List<FavoriteItem>> getFavorites() async {
    final box = await Hive.openBox<FavoriteItem>(_favoritesBox);
    return box.values.toList();
  }

  Future<void> addFavorite(ContentItem contentItem) async {
    final box = await Hive.openBox<FavoriteItem>(_favoritesBox);

    final isEpisode = contentItem.streamType == 'series' &&
        contentItem.historyId.isNotEmpty &&
        contentItem.historyId != contentItem.id;

    final favorite = FavoriteItem(
      id: contentItem.id,
      name: contentItem.name,
      streamType: contentItem.streamType ?? 'live',
      streamIcon: contentItem.streamIcon,
      category: contentItem.category,
      streamUrl: contentItem.streamUrl,
      description: contentItem.description,
      seriesId: isEpisode ? contentItem.historyId : null,
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
    await _repairSeriesWatchNames(box);
    final List<WatchHistory> history = box.values.toList();
    history.sort((a, b) => b.watchDate.compareTo(a.watchDate));
    return history;
  }

  Future<void> addToWatchHistory(ContentItem contentItem) async {
    try {
      Log.d("DBG",
          "Debug - Database addToWatchHistory - ContentID: ${contentItem.id}, Pozisyon: ${contentItem.position}, Süre: ${contentItem.duration}");
      final box = await Hive.openBox<WatchHistory>(_watchHistoryBox);

      final type = contentItem.streamType ?? 'live';
      final storedName = type == 'series'
          ? _oneLineSeriesHistoryName(contentItem.name)
          : contentItem.name;

      final watchItem = WatchHistory(
        contentId: contentItem.id,
        name: storedName,
        streamType: type,
        streamIcon: contentItem.streamIcon,
        position: contentItem.position,
        duration: contentItem.duration,
        streamUrl: contentItem.streamUrl,
        category: contentItem.category,
        historyId: contentItem.historyId,
      );

      // Aynı içerik zaten varsa güncelle, key = historyId
      final key = contentItem.historyId;
      await box.put(key, watchItem);

      // Kaydettikten sonra kontrol et (Hive anahtarı historyId)
      final savedItem = box.get(key);
      Log.d("DBG",
          "Debug - Database kaydedilen: ContentID: ${savedItem?.contentId}, Pozisyon: ${savedItem?.position}, Süre: ${savedItem?.duration}");
    } catch (e) {
      Log.d("DBG", "Debug - Database addToWatchHistory hata: $e");
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

  Future<List<WatchHistory>> getLastWatched(String contentType,
      {int limit = 10}) async {
    final box = await Hive.openBox<WatchHistory>(_watchHistoryBox);
    await _repairSeriesWatchNames(box);
    final filtered =
        box.values.where((e) => e.streamType == contentType).toList();
    filtered.sort((a, b) => b.watchDate.compareTo(a.watchDate));
    return filtered.take(limit).toList();
  }

  Future<WatchHistory?> getWatchPosition(String contentId) async {
    final box = await Hive.openBox<WatchHistory>(_watchHistoryBox);
    final result = box.get(contentId);
    Log.d("DBG",
        "Debug - Database getWatchPosition - ContentID: $contentId, Pozisyon: ${result?.position}, Süre: ${result?.duration}");
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
