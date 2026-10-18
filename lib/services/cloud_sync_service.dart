import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';
import '../config/firebase_options.dart';
import '../models/favorite_item.dart';
import '../models/watch_history.dart';
import '../utils/logger.dart';
import 'database_service.dart';

/// IPTV girişi aynı olan cihazlar favori ve izleme konumunu paylaşır.
/// Kimlik = normalize sunucu (host+port) + username. Şifre anahtara girmez.
class CloudSyncService with WidgetsBindingObserver {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  static const _profileKey = 'cloud_sync_profile';
  static const _watchDebounce = Duration(seconds: 3);
  static const _cloudTimeout = Duration(seconds: 8);
  static const _fullPullFreshness = Duration(seconds: 4);

  bool _ready = false;
  bool _started = false;
  bool _observingLifecycle = false;
  Timer? _watchTimer;
  Timer? _notifyTimer;
  DateTime? _lastFullPullAt;
  Future<void>? _inFlightPull;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _favSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _histSub;
  final Map<String, WatchHistory> _pendingWatch = {};

  /// Hive güncellenince ana sayfa / listeler yenilensin.
  final ValueNotifier<int> revision = ValueNotifier(0);

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
      await pullAndMerge(force: true);
      await flush();
      _listen();
      _ensureLifecycleObserver();
      Log.d('CloudSync', 'Hazır uid=${FirebaseAuth.instance.currentUser?.uid}');
    } catch (e, st) {
      Log.e('CloudSync', e, st);
    }
  }

  Future<void> stop() async {
    _watchTimer?.cancel();
    _watchTimer = null;
    _notifyTimer?.cancel();
    _notifyTimer = null;
    await _favSub?.cancel();
    await _histSub?.cancel();
    _favSub = null;
    _histSub = null;
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      unawaited(flush());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(pullAndMerge(force: true));
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

  Future<void> pullFavorites() async {
    if (!isActive) return;
    try {
      final snap = await _favorites.get().timeout(_cloudTimeout);
      await _applyFavoriteDocs(snap.docs, backfillLocal: true);
      _bump();
    } catch (e, st) {
      Log.e('CloudSync', e, st);
    }
  }

  Future<void> pullWatchHistory() async {
    if (!isActive) return;
    try {
      final snap = await _history.get().timeout(_cloudTimeout);
      await _applyWatchDocs(snap.docs, backfillLocal: true);
      _bump();
    } catch (e, st) {
      Log.e('CloudSync', e, st);
    }
  }

  /// Film / dizi açılırken o kaydın güncel saniyesini Firestore'dan alır.
  Future<WatchHistory?> pullWatchItem(String historyId) async {
    if (historyId.isEmpty) return DatabaseService().getWatchPosition(historyId);
    if (!isActive) return DatabaseService().getWatchPosition(historyId);

    try {
      final doc = await _history.doc(historyId).get().timeout(_cloudTimeout);
      final db = DatabaseService();
      if (!doc.exists) {
        return await db.getWatchPosition(historyId);
      }
      final data = doc.data() ?? {};
      if (data['deleted'] == true) {
        await db.applyRemoteWatchDelete(historyId);
        _bump();
        return await db.getWatchPosition(historyId);
      }
      await db.applyRemoteWatch(_watchFromMap(data, historyId));
      _bump();
    } catch (e, st) {
      Log.e('CloudSync', e, st);
    }
    return DatabaseService().getWatchPosition(historyId);
  }

  Future<void> pullFavoriteItem(String contentId) async {
    if (!isActive || contentId.isEmpty) return;
    try {
      final doc = await _favorites.doc(contentId).get().timeout(_cloudTimeout);
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final db = DatabaseService();
      if (data['deleted'] == true) {
        await db.applyRemoteFavoriteDelete(contentId);
      } else {
        await db.applyRemoteFavorite(_favoriteFromMap(data, contentId));
      }
      _bump();
    } catch (e, st) {
      Log.e('CloudSync', e, st);
    }
  }

  Future<void> pullAndMerge({bool force = false}) async {
    if (!isActive) return;
    if (_inFlightPull != null) {
      await _inFlightPull;
      if (!force) return;
    }
    if (!force &&
        _lastFullPullAt != null &&
        DateTime.now().difference(_lastFullPullAt!) < _fullPullFreshness) {
      return;
    }

    final future = _doPullAndMerge();
    _inFlightPull = future;
    try {
      await future;
    } finally {
      if (identical(_inFlightPull, future)) {
        _inFlightPull = null;
      }
    }
  }

  Future<void> _doPullAndMerge() async {
    try {
      final favSnap = await _favorites.get().timeout(_cloudTimeout);
      await _applyFavoriteDocs(favSnap.docs, backfillLocal: true);

      final histSnap = await _history.get().timeout(_cloudTimeout);
      await _applyWatchDocs(histSnap.docs, backfillLocal: true);

      _lastFullPullAt = DateTime.now();
      _bump();
    } catch (e, st) {
      Log.e('CloudSync', e, st);
    }
  }

  void _listen() {
    _favSub?.cancel();
    _histSub?.cancel();
    if (!isActive) return;

    _favSub = _favorites.snapshots().listen(
      (snap) async {
        await _applyFavoriteDocs(snap.docs, backfillLocal: false);
        _bump();
      },
      onError: (Object e, StackTrace st) => Log.e('CloudSync', e, st),
    );
    _histSub = _history.snapshots().listen(
      (snap) async {
        await _applyWatchDocs(snap.docs, backfillLocal: false);
        _bump();
      },
      onError: (Object e, StackTrace st) => Log.e('CloudSync', e, st),
    );
  }

  Future<void> _applyFavoriteDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool backfillLocal,
  }) async {
    final db = DatabaseService();
    final remoteIds = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      final id = (data['id'] as String?) ?? doc.id;
      remoteIds.add(id);
      if (data['deleted'] == true) {
        await db.applyRemoteFavoriteDelete(id);
      } else {
        await db.applyRemoteFavorite(_favoriteFromMap(data, id));
      }
    }

    if (backfillLocal) {
      final localFavs = await db.getFavorites();
      for (final fav in localFavs) {
        if (!remoteIds.contains(fav.id)) {
          await pushFavorite(fav);
        }
      }
    }
  }

  Future<void> _applyWatchDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool backfillLocal,
  }) async {
    final db = DatabaseService();
    final remoteIds = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      final id = (data['historyId'] as String?) ?? doc.id;
      remoteIds.add(id);
      if (data['deleted'] == true) {
        await db.applyRemoteWatchDelete(id);
      } else {
        await db.applyRemoteWatch(_watchFromMap(data, id));
      }
    }

    if (backfillLocal) {
      final localHist = await db.getWatchHistory();
      for (final item in localHist) {
        if (!remoteIds.contains(item.historyId)) {
          _pendingWatch[item.historyId] = item;
        }
      }
    }
  }

  void _bump() {
    _notifyTimer?.cancel();
    _notifyTimer = Timer(const Duration(milliseconds: 250), () {
      revision.value++;
    });
  }

  void _ensureLifecycleObserver() {
    if (_observingLifecycle) return;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
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
    return 'u$id@sync.player.app';
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
