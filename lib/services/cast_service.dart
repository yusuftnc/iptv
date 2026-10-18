import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/cast_context.dart';
import 'package:flutter_chrome_cast/common.dart';
import 'package:flutter_chrome_cast/discovery.dart';
import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_chrome_cast/enums.dart';
import 'package:flutter_chrome_cast/media.dart';
import 'package:flutter_chrome_cast/models.dart';
import 'package:flutter_chrome_cast/session.dart';
import 'package:iptv_app/utils/logger.dart';

/// Google Cast (Chromecast / Cast destekli Android TV) yansıtma.
class CastService {
  CastService._();
  static final CastService instance = CastService._();

  bool _initialized = false;
  bool _discoveryStarted = false;
  StreamSubscription<List<GoogleCastDevice>>? _devicesSub;
  StreamSubscription<GoogleCastSession?>? _sessionSub;
  StreamSubscription<GoggleCastMediaStatus?>? _mediaSub;
  StreamSubscription<Duration>? _positionSub;

  final _devicesController =
      StreamController<List<GoogleCastDevice>>.broadcast();
  final _sessionController = StreamController<GoogleCastSession?>.broadcast();
  final _mediaController = StreamController<GoggleCastMediaStatus?>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get isConnected =>
      _initialized &&
      GoogleCastSessionManager.instance.connectionState ==
          GoogleCastConnectState.connected;

  Stream<List<GoogleCastDevice>> get devicesStream => _devicesController.stream;

  List<GoogleCastDevice> get devices => _initialized
      ? GoogleCastDiscoveryManager.instance.devices
      : const [];

  Stream<GoogleCastSession?> get sessionStream => _sessionController.stream;

  Stream<GoggleCastMediaStatus?> get mediaStatusStream => _mediaController.stream;

  Stream<Duration> get playerPositionStream => _positionController.stream;

  bool get isRemotePlaying {
    if (!_initialized) return false;
    final state =
        GoogleCastRemoteMediaClient.instance.mediaStatus?.playerState;
    return state == CastMediaPlayerState.playing ||
        state == CastMediaPlayerState.buffering;
  }

  Future<void> play() async {
    await GoogleCastRemoteMediaClient.instance.play();
  }

  Future<void> pause() async {
    await GoogleCastRemoteMediaClient.instance.pause();
  }

  Future<void> seekTo(Duration position) async {
    final safe = position.isNegative ? Duration.zero : position;
    await GoogleCastRemoteMediaClient.instance.seek(
      GoogleCastMediaSeekOption(
        position: safe,
        resumeState: GoogleCastMediaResumeState.play,
      ),
    );
  }

  Future<void> seekBy(Duration delta) async {
    final current = GoogleCastRemoteMediaClient.instance.playerPosition;
    var next = current + delta;
    if (next.isNegative) next = Duration.zero;
    await seekTo(next);
  }

  Future<void> initialize() async {
    if (!isSupported || _initialized) return;

    try {
      const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
      late final GoogleCastOptions options;

      if (Platform.isIOS) {
        options = IOSGoogleCastOptions(
          GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
          physicalVolumeButtonsWillControlDeviceVolume: false,
          startDiscoveryAfterFirstTapOnCastButton: true,
          disableDiscoveryAutostart: true,
          stopCastingOnAppTerminated: true,
        );
      } else {
        options = GoogleCastOptionsAndroid(
          appId: appId,
          stopCastingOnAppTerminated: true,
        );
      }

      await GoogleCastContext.instance.setSharedInstanceWithOptions(options);
      _initialized = true;
      _devicesSub ??= GoogleCastDiscoveryManager.instance.devicesStream
          .listen(_devicesController.add);
      _sessionSub ??= GoogleCastSessionManager.instance.currentSessionStream
          .listen(_sessionController.add);
      _mediaSub ??= GoogleCastRemoteMediaClient.instance.mediaStatusStream
          .listen(_mediaController.add);
      _positionSub ??= GoogleCastRemoteMediaClient.instance.playerPositionStream
          .listen(_positionController.add);
      Log.d('Cast', 'Google Cast initialized');
    } catch (e, st) {
      Log.e('Cast', e, st);
    }
  }

  Future<void> startDiscovery({bool refresh = false}) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;
    try {
      if (refresh) {
        try {
          await GoogleCastDiscoveryManager.instance.stopDiscovery();
        } catch (_) {}
        _discoveryStarted = false;
      }
      if (_discoveryStarted && !refresh) return;
      await GoogleCastDiscoveryManager.instance.startDiscovery();
      _discoveryStarted = true;
      Log.d('Cast', 'Discovery started');
    } catch (e) {
      Log.d('Cast', 'startDiscovery: $e');
    }
  }

  Future<void> stopDiscovery() async {
    if (!_initialized) return;
    try {
      await GoogleCastDiscoveryManager.instance.stopDiscovery();
      _discoveryStarted = false;
    } catch (_) {}
  }

  Future<void> connectAndPlay({
    required GoogleCastDevice device,
    required String streamUrl,
    required String title,
    String contentType = 'movie',
    String? imageUrl,
    Duration position = Duration.zero,
    String? preferredAudioLabel,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) {
      throw Exception('Cast başlatılamadı');
    }
    if (streamUrl.isEmpty) {
      throw Exception('Yansıtılacak yayın URL’si yok');
    }

    final uri = Uri.tryParse(streamUrl);
    if (uri == null || !uri.hasScheme) {
      throw Exception('Geçersiz yayın URL’si');
    }

    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await _connectAndLoad(
          device: device,
          uri: uri,
          streamUrl: streamUrl,
          title: title,
          contentType: contentType,
          imageUrl: imageUrl,
          position: position,
          attempt: attempt,
          preferredAudioLabel: preferredAudioLabel,
        );
        return;
      } catch (e) {
        lastError = e;
        Log.d('Cast', 'attempt $attempt failed: $e');
        final stillConnected =
            GoogleCastSessionManager.instance.connectionState ==
                GoogleCastConnectState.connected;
        if (!stillConnected) {
          try {
            await GoogleCastSessionManager.instance.endSessionAndStopCasting();
          } catch (_) {}
        }
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 800 * attempt));
        }
      }
    }

    throw lastError ?? Exception('Yansıtılamadı');
  }

  Future<void> _connectAndLoad({
    required GoogleCastDevice device,
    required Uri uri,
    required String streamUrl,
    required String title,
    required String contentType,
    required String? imageUrl,
    required Duration position,
    required int attempt,
    String? preferredAudioLabel,
  }) async {
    final alreadyConnected = GoogleCastSessionManager.instance.connectionState ==
        GoogleCastConnectState.connected;

    if (!alreadyConnected) {
      Log.d('Cast', 'Connecting to ${device.friendlyName} (try $attempt)…');
      await GoogleCastSessionManager.instance.startSessionWithDevice(device);
      await _waitUntilConnected();
      // Screensaver / receiver: ilk oturum ekranı açar, video yüzeyi geç gelir.
      await Future<void>.delayed(
        Duration(milliseconds: attempt == 1 ? 2500 : 1000),
      );
      if (GoogleCastSessionManager.instance.connectionState !=
          GoogleCastConnectState.connected) {
        throw Exception('TV uyandıktan sonra bağlantı koptu');
      }
    }

    final profile = _streamProfile(streamUrl, contentType);
    final images = <GoogleCastImage>[];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final imageUri = Uri.tryParse(imageUrl);
      if (imageUri != null) {
        images.add(GoogleCastImage(url: imageUri, height: 480, width: 854));
      }
    }

    final mediaInfo = GoogleCastMediaInformation(
      contentId: streamUrl.length <= 1024 ? streamUrl : uri.toString(),
      streamType: profile.isLive
          ? CastMediaStreamType.live
          : CastMediaStreamType.buffered,
      contentUrl: uri,
      contentType: profile.mimeType,
      hlsSegmentFormat: profile.hlsSegmentFormat,
      hlsVideoSegmentFormat: profile.hlsVideoSegmentFormat,
      metadata: GoogleCastMovieMediaMetadata(
        title: title.isNotEmpty ? title : 'IPTV',
        images: images,
      ),
    );

    Log.d(
      'Cast',
      'loadMedia mime=${profile.mimeType} live=${profile.isLive} url=$streamUrl',
    );

    await GoogleCastRemoteMediaClient.instance.loadMedia(
      mediaInfo,
      autoPlay: true,
      playPosition: profile.isLive ? Duration.zero : position,
    );
    await _waitUntilPlayingOrFail(
      timeout: Duration(seconds: attempt == 1 ? 12 : 18),
    );

    Log.d('Cast', 'Playing on ${device.friendlyName}');

    await _applyPreferredAudio(preferredAudioLabel);
  }

  /// Telefonda seçili ses parçasının dilini (örn. "Turkish - AC3…") TV'deki
  /// yayına uygular. Alıcı yalnızca parçaları ayrıştırabildiğinde çalışır
  /// (HLS/DASH veya çok sesli, ayrıştırılabilen akışlar). Gömülü AC3/MKV
  /// seslerinde alıcı parça bildirmezse sessizce atlanır.
  Future<void> applyPreferredAudioByLabel(String label) =>
      _applyPreferredAudio(label);

  Future<void> _applyPreferredAudio(String? label) async {
    if (label == null || label.trim().isEmpty) return;
    if (!_initialized) return;

    final client = GoogleCastRemoteMediaClient.instance;

    // Parçalar oynatma başladıktan kısa süre sonra dolabilir; birkaç kez dene.
    List<GoogleCastMediaTrack> audioTracks = const [];
    for (var i = 0; i < 10; i++) {
      final tracks = client.mediaStatus?.mediaInformation?.tracks ?? const [];
      audioTracks =
          tracks.where((t) => t.type == TrackType.audio).toList();
      if (audioTracks.length > 1) break;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    if (audioTracks.length < 2) {
      Log.d(
        'Cast',
        'audio: alıcı birden çok ses parçası bildirmedi '
            '(gömülü AC3/MKV olabilir), dil uygulanamadı',
      );
      return;
    }

    Log.d(
      'Cast',
      'audio tracks: ${audioTracks.map((t) => '${t.trackId}:${t.name}/${t.language}').join(', ')}',
    );

    final match = _matchAudioTrack(audioTracks, label);
    if (match == null) {
      Log.d('Cast', 'audio: "$label" için eşleşme bulunamadı');
      return;
    }

    final active = client.mediaStatus?.activeTrackIds ?? const <int>[];
    if (active.contains(match.trackId)) {
      Log.d('Cast', 'audio zaten aktif: ${match.trackId}');
      return;
    }

    try {
      await client.setActiveTrackIDs([match.trackId]);
      Log.d(
        'Cast',
        'audio uygulandı: ${match.trackId} (${match.name}/${match.language})',
      );
    } catch (e) {
      Log.d('Cast', 'setActiveTrackIDs: $e');
    }
  }

  GoogleCastMediaTrack? _matchAudioTrack(
    List<GoogleCastMediaTrack> tracks,
    String preferred,
  ) {
    final pref = preferred.trim().toLowerCase();
    if (pref.isEmpty) return null;

    String cand(GoogleCastMediaTrack t) =>
        '${t.name ?? ''} ${t.language?.toString() ?? ''}'.trim().toLowerCase();

    // Birebir / içeren eşleşme
    for (final t in tracks) {
      final c = cand(t);
      if (c.isNotEmpty && (c.contains(pref) || pref.contains(c))) return t;
    }

    // Dil token'ı puanlaması
    final tokens = _languageTokens(pref);
    GoogleCastMediaTrack? best;
    var bestScore = 0;
    for (final t in tracks) {
      final c = cand(t);
      var score = 0;
      for (final tok in tokens) {
        if (c.contains(tok)) score += tok.length;
      }
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    return bestScore > 0 ? best : null;
  }

  static List<String> _languageTokens(String label) {
    final l = label.toLowerCase();
    final tokens = <String>{l};
    if (l.contains('türk') ||
        l.contains('turk') ||
        l.contains('turkish') ||
        l.contains('turc') ||
        RegExp(r'\btr\b').hasMatch(l) ||
        l.contains('[tr]') ||
        l.contains('(tr)')) {
      tokens.addAll(['türk', 'turk', 'turkish', 'turc', 'tur', 'tr']);
    }
    if (l.contains('eng') ||
        l.contains('i̇ng') ||
        l.contains('ing') ||
        l.contains('ingiliz') ||
        l.contains('anglais')) {
      tokens.addAll(['eng', 'english', 'ingiliz', 'anglais', 'en']);
    }
    if (l.contains('fran') || l.contains('frans') || l.contains('french')) {
      tokens.addAll(['fran', 'french', 'fra', 'fr', 'français']);
    }
    if (l.contains('deu') ||
        l.contains('ger') ||
        l.contains('alman') ||
        l.contains('german')) {
      tokens.addAll(['deu', 'ger', 'german', 'alman', 'deutsch', 'de']);
    }
    if (l.contains('arap') || l.contains('arab') || RegExp(r'\bar\b').hasMatch(l)) {
      tokens.addAll(['arap', 'arab', 'arabic', 'ara', 'ar']);
    }
    if (l.contains('rus') || l.contains('russian')) {
      tokens.addAll(['rus', 'russian', 'ru']);
    }
    if (l.contains('ispany') || l.contains('span') || l.contains('espa')) {
      tokens.addAll(['span', 'spanish', 'espanol', 'español', 'spa', 'es']);
    }
    return tokens.toList();
  }

  static const _playbackChannel = MethodChannel('iptv.playback/control');

  /// Cast oturumu iOS ses oturumunu bırakır; VLC görüntü verir, ses kesilir
  /// ve yan düğmeler zil sesine düşer. Oynatma oturumunu geri açar.
  Future<void> restoreLocalAudio() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _playbackChannel.invokeMethod<void>('restorePlaybackAudio');
    } catch (e) {
      Log.d('Cast', 'restore audio: $e');
    }
  }

  Future<void> disconnect() async {
    if (!isConnected) return;
    try {
      await GoogleCastRemoteMediaClient.instance.stop();
    } catch (_) {}
    try {
      await GoogleCastSessionManager.instance.endSessionAndStopCasting();
    } catch (e) {
      Log.d('Cast', 'disconnect: $e');
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await restoreLocalAudio();
  }

  Future<void> _waitUntilConnected() async {
    final manager = GoogleCastSessionManager.instance;
    if (manager.connectionState == GoogleCastConnectState.connected) {
      return;
    }

    await manager.currentSessionStream
        .where(
          (session) =>
              session?.connectionState == GoogleCastConnectState.connected,
        )
        .first
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            throw Exception('TV bağlantısı kurulamadı');
          },
        );
  }

  Future<void> _waitUntilPlayingOrFail({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final client = GoogleCastRemoteMediaClient.instance;
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final status = client.mediaStatus;
      if (status != null) {
        switch (status.playerState) {
          case CastMediaPlayerState.playing:
          case CastMediaPlayerState.buffering:
          case CastMediaPlayerState.loading:
            return;
          case CastMediaPlayerState.idle:
            if (status.idleReason == GoogleCastMediaIdleReason.error) {
              throw Exception(
                'TV bu yayını oynatamadı (format veya erişim sorunu)',
              );
            }
            if (status.idleReason == GoogleCastMediaIdleReason.cancelled) {
              throw Exception('Yansıtma iptal edildi');
            }
            break;
          case CastMediaPlayerState.paused:
            return;
          case CastMediaPlayerState.unknown:
            break;
        }
      }

      GoggleCastMediaStatus? next;
      try {
        next = await client.mediaStatusStream
            .where((status) => status != null)
            .map((status) => status!)
            .first
            .timeout(const Duration(seconds: 2));
      } on TimeoutException {
        continue;
      }

      switch (next.playerState) {
        case CastMediaPlayerState.playing:
        case CastMediaPlayerState.buffering:
        case CastMediaPlayerState.loading:
        case CastMediaPlayerState.paused:
          return;
        case CastMediaPlayerState.idle:
          if (next.idleReason == GoogleCastMediaIdleReason.error) {
            throw Exception(
              'TV bu yayını oynatamadı (format veya erişim sorunu)',
            );
          }
          if (next.idleReason == GoogleCastMediaIdleReason.cancelled) {
            throw Exception('Yansıtma iptal edildi');
          }
          break;
        case CastMediaPlayerState.unknown:
          break;
      }
    }

    throw Exception(
      'TV yanıt vermedi. Yayın Cast ile uyumlu olmayabilir (HLS/MP4 deneyin).',
    );
  }

  static _StreamProfile _streamProfile(String url, String contentType) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    final isLive = contentType == 'live';

    if (path.contains('.m3u8')) {
      return _StreamProfile(
        isLive: isLive,
        mimeType: 'application/x-mpegURL',
        hlsSegmentFormat: CastHlsSegmentFormat.ts,
        hlsVideoSegmentFormat: HlsVideoSegmentFormat.mpeg2Ts,
      );
    }
    if (path.contains('.mpd')) {
      return _StreamProfile(isLive: isLive, mimeType: 'application/dash+xml');
    }
    if (path.contains('.ts')) {
      return _StreamProfile(isLive: isLive, mimeType: 'video/mp2t');
    }
    if (path.contains('.mp4')) {
      return _StreamProfile(isLive: false, mimeType: 'video/mp4');
    }
    if (path.contains('.webm')) {
      return _StreamProfile(isLive: false, mimeType: 'video/webm');
    }
    if (path.contains('.mkv')) {
      return _StreamProfile(isLive: false, mimeType: 'video/x-matroska');
    }

    if (isLive) {
      return _StreamProfile(isLive: true, mimeType: 'video/mp2t');
    }
    return _StreamProfile(isLive: false, mimeType: 'video/mp4');
  }
}

class _StreamProfile {
  const _StreamProfile({
    required this.isLive,
    required this.mimeType,
    this.hlsSegmentFormat,
    this.hlsVideoSegmentFormat,
  });

  final bool isLive;
  final String mimeType;
  final CastHlsSegmentFormat? hlsSegmentFormat;
  final HlsVideoSegmentFormat? hlsVideoSegmentFormat;
}
