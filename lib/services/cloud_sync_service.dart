import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';
import '../config/firebase_options.dart';
import '../models/favorite_item.dart';
import '../models/watch_history.dart';
import '../utils/logger.dart';
import 'database_service.dart';

/// IPTV girişi aynı olan cihazlar favori ve izleme konumunu paylaşır.
/// Kimlik = normalize sunucu (host+port) + username. Şifre anahtara girmez.
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  static const _profileKey = 'cloud_sync_profile';
  static const _watchDebounce = Duration(seconds: 8);

  bool _ready = false;
  bool _started = false;
  Timer? _watchTimer;
  final Map<String, WatchHistory> _pendingWatch = {};

  bool get isActive => _ready && _started && FirebaseAuth.instance.currentUser != null;

  Future<void> start({
    required String host,
    required String port,
    required String username,
    required String password,
  }) async {
    if (host.isEmpty || username.isEmpty || password.isEmpty) return;

    if (!await _ensureFirebase()) return;

    try {
      await _signIn(host: host, port: port, username: username);
      _started = true;
      await _switchLocalProfileIfNeeded(_profileId(host, port, username));
      await pullAndMerge();
      await flush();
      Log.d('CloudSync', 'Hazır uid=${FirebaseAuth.instance.currentUser?.uid}');
    } catch (e, st) {
      Log.e('CloudSync', e, st);
    }
  }

  Future<void> stop() async {
    _watchTimer?.cancel();
    _watchTimer = null;
    await flush();
    _started = false;
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      Log.d('CloudSync', 'signOut: $e');
    }
  }

  Future<void> pushFavorite(FavoriteItem item) async {
    if (!isActive) return;
    try {
      await _favorites.doc(item.id).set(_favoriteMap(item, deleted: false));
    } catch (e) {
      Log.d('CloudSync', 'pushFavorite: $e');
    }
  }

  Future<void> deleteFavorite(String contentId) async {
    if (!isActive) return;
    try {
      await _favorites.doc(contentId).set({
        'id': contentId,
        'deleted': true,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      Log.d('CloudSync', 'deleteFavorite: $e');
    }
  }

  void scheduleWatchPush(WatchHistory item) {
    if (!isActive) return;
    _pendingWatch[item.historyId] = item;
    _watchTimer?.cancel();
    _watchTimer = Timer(_watchDebounce, () {
      unawaited(flush());
    });
  }

  Future<void> deleteWatch(String historyId) async {
    if (!isActive) return;
    _pendingWatch.remove(historyId);
    try {
      await _history.doc(historyId).set({
        'historyId': historyId,
        'deleted': true,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      Log.d('CloudSync', 'deleteWatch: $e');
    }
  }

  Future<void> clearRemoteWatch() async {
    if (!isActive) return;
    _pendingWatch.clear();
    _watchTimer?.cancel();
    try {
      final snap = await _history.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.set(
          doc.reference,
          {
            'historyId': doc.id,
            'deleted': true,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } catch (e) {
      Log.d('CloudSync', 'clearRemoteWatch: $e');
    }
  }

  Future<void> flush() async {
    if (!isActive || _pendingWatch.isEmpty) return;
    final pending = Map<String, WatchHistory>.from(_pendingWatch);
    _pendingWatch.clear();
    _watchTimer?.cancel();
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final item in pending.values) {
        batch.set(_history.doc(item.historyId), _watchMap(item, deleted: false));
      }
      await batch.commit();
    } catch (e) {
      Log.d('CloudSync', 'flush: $e');
      _pendingWatch.addAll(pending);
    }
  }

  Future<void> pullAndMerge() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    final db = DatabaseService();

    try {
      final favSnap = await _favorites.get();
      final remoteFavIds = <String>{};
      for (final doc in favSnap.docs) {
        final data = doc.data();
        final id = (data['id'] as String?) ?? doc.id;
        remoteFavIds.add(id);
        final deleted = data['deleted'] == true;
        if (deleted) {
          await db.applyRemoteFavoriteDelete(id);
          continue;
        }
        await db.applyRemoteFavorite(_favoriteFromMap(data, id));
      }

      final histSnap = await _history.get();
      final remoteHistIds = <String>{};
      for (final doc in histSnap.docs) {
        final data = doc.data();
        final id = (data['historyId'] as String?) ?? doc.id;
        remoteHistIds.add(id);
        final deleted = data['deleted'] == true;
        if (deleted) {
          await db.applyRemoteWatchDelete(id);
          continue;
        }
        await db.applyRemoteWatch(_watchFromMap(data, id));
      }

      final localFavs = await db.getFavorites();
      for (final fav in localFavs) {
        if (!remoteFavIds.contains(fav.id)) {
          await pushFavorite(fav);
        }
      }

      final localHist = await db.getWatchHistory();
      for (final item in localHist) {
        if (!remoteHistIds.contains(item.historyId)) {
          _pendingWatch[item.historyId] = item;
        }
      }
    } catch (e, st) {
      Log.e('CloudSync', e, st);
    }
  }

  CollectionReference<Map<String, dynamic>> get _favorites =>
      _userCol.collection('favorites');

  CollectionReference<Map<String, dynamic>> get _history =>
      _userCol.collection('watchHistory');

  DocumentReference<Map<String, dynamic>> get _userCol {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  Future<bool> _ensureFirebase() async {
    if (_ready) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      _ready = true;
      return true;
    } catch (e) {
      Log.d('CloudSync', 'Firebase yapılandırılmadı, senkron kapalı.');
      return false;
    }
  }

  Future<void> _signIn({
    required String host,
    required String port,
    required String username,
  }) async {
    final email = _email(host, port, username);
    final secret = _password(host, port, username);
    final auth = FirebaseAuth.instance;

    try {
      await auth.signInWithEmailAndPassword(email: email, password: secret);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        try {
          await auth.createUserWithEmailAndPassword(email: email, password: secret);
        } on FirebaseAuthException catch (createError) {
          if (createError.code == 'email-already-in-use') {
            await auth.signInWithEmailAndPassword(email: email, password: secret);
          } else {
            rethrow;
          }
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> _switchLocalProfileIfNeeded(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_profileKey);
    if (previous != null && previous.isNotEmpty && previous != profileId) {
      await DatabaseService().clearLocalLibrary();
    }
    await prefs.setString(_profileKey, profileId);
  }

  /// `http://x.com:8080/c/` + port alanı → `x.com|8080`.
  /// Böylece aynı panel farklı yazılınca iki hesap oluşmaz.
  static ({String host, String port}) _normalizeServer(String host, String port) {
    var raw = host.trim().toLowerCase();
    raw = raw.replaceFirst(RegExp(r'^https?://'), '');
    raw = raw.split('/').first;
    String? embeddedPort;
    if (raw.contains(':')) {
      final parts = raw.split(':');
      raw = parts.first;
      if (parts.length > 1 && parts[1].isNotEmpty) {
        embeddedPort = parts[1];
      }
    }
    var normalizedPort = port.trim();
    if (normalizedPort.isEmpty) {
      normalizedPort = embeddedPort ?? '80';
    }
    return (host: raw, port: normalizedPort);
  }

  static String _profileId(String host, String port, String username) {
    final server = _normalizeServer(host, port);
    final user = username.trim().toLowerCase();
    return sha256.convert(utf8.encode('${server.host}|${server.port}|$user')).toString();
  }

  static String _email(String host, String port, String username) {
    final id = _profileId(host, port, username);
    return 'u$id@sync.iptv.app';
  }

  static String _password(String host, String port, String username) {
    final server = _normalizeServer(host, port);
    final user = username.trim().toLowerCase();
    return sha256
        .convert(utf8.encode('${Env.credentialsSecret}|${server.host}|${server.port}|$user'))
        .toString();
  }

  static Map<String, dynamic> _favoriteMap(FavoriteItem item, {required bool deleted}) {
    return {
      'id': item.id,
      'name': item.name,
      'streamType': item.streamType,
      'streamIcon': item.streamIcon,
      'category': item.category,
      'description': item.description,
      'seriesId': item.seriesId,
      'addedDate': item.addedDate.toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }

  static Map<String, dynamic> _watchMap(WatchHistory item, {required bool deleted}) {
    return {
      'contentId': item.contentId,
      'name': item.name,
      'streamType': item.streamType,
      'streamIcon': item.streamIcon,
      'watchDate': item.watchDate.toUtc().toIso8601String(),
      'position': item.position,
      'duration': item.duration,
      'category': item.category,
      'historyId': item.historyId,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }

  static FavoriteItem _favoriteFromMap(Map<String, dynamic> data, String id) {
    final item = FavoriteItem(
      id: id,
      name: data['name'] as String? ?? '',
      streamType: data['streamType'] as String? ?? 'movie',
      streamIcon: data['streamIcon'] as String?,
      category: data['category'] as String?,
      description: data['description'] as String?,
      seriesId: data['seriesId'] as String?,
    );
    final added = DateTime.tryParse(data['addedDate'] as String? ?? '');
    if (added != null) item.addedDate = added.toLocal();
    return item;
  }

  static WatchHistory _watchFromMap(Map<String, dynamic> data, String id) {
    final item = WatchHistory(
      contentId: data['contentId'] as String? ?? id,
      name: data['name'] as String? ?? '',
      streamType: data['streamType'] as String? ?? 'movie',
      streamIcon: data['streamIcon'] as String?,
      position: (data['position'] as num?)?.toInt(),
      duration: (data['duration'] as num?)?.toInt(),
      category: data['category'] as String?,
      historyId: id,
    );
    final watched = DateTime.tryParse(data['watchDate'] as String? ?? '');
    if (watched != null) item.watchDate = watched.toLocal();
    return item;
  }
}
