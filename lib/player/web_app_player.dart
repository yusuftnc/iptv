import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../services/web_aac_proxy.dart';
import 'app_player.dart';
import 'web_dom_audio.dart' if (dart.library.io) 'web_dom_audio_stub.dart'
    as dom_audio;

/// Web HTML5 oynatıcı.
/// AAC proxy (frag MP4) kullanıyorsa süre ffprobe'dan gelir; seek ffmpeg'i
/// `ss=` ile yeniden başlatır (tarayıcı seek'i frag stream'de kırık).
class WebAppPlayerController extends AppPlayerController {
  WebAppPlayerController._(this._video, this._playUrl);

  VideoPlayerController _video;
  String _playUrl;
  final List<VoidCallback> _onInit = [];
  bool _initNotified = false;
  bool audioUnlocked = true;
  bool _swapping = false;
  AppPlayingState _state = AppPlayingState.initializing;
  double _volume = 1.0;

  /// Proxy orijinal kaynak (ss için).
  String? _proxySource;
  Duration _originOffset = Duration.zero;
  Duration? _forcedDuration;

  bool get _proxyHardSeek =>
      _proxySource != null && WebAacProxy.isProxied(_playUrl);

  static Future<AppPlayerController> create({
    required String url,
    required bool autoPlay,
  }) async {
    final video = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
    );
    final wrapper = WebAppPlayerController._(video, url);
    if (WebAacProxy.isProxied(url)) {
      wrapper._proxySource = WebAacProxy.unwrapSource(url);
      final ss = Uri.tryParse(url)?.queryParameters['ss'];
      final start = double.tryParse(ss ?? '') ?? 0;
      if (start > 0) {
        wrapper._originOffset =
            Duration(milliseconds: (start * 1000).round());
      }
      // Süreyi arka planda doldur
      unawaited(wrapper._loadForcedDuration());
    }
    video.addListener(wrapper._onVideoChanged);
    try {
      await video.initialize();
      await video.setVolume(1.0);
      wrapper._volume = 1.0;
      wrapper._state = AppPlayingState.initialized;
      wrapper._notifyInit();
      if (autoPlay) {
        try {
          await video.play();
          wrapper._state = AppPlayingState.playing;
          dom_audio.forceUnmuteAllVideos(volume: 1.0);
        } catch (_) {
          wrapper._state = AppPlayingState.paused;
          wrapper.audioUnlocked = false;
        }
      } else {
        wrapper._state = AppPlayingState.paused;
      }
      wrapper.notifyListeners();
    } catch (_) {
      wrapper._state = AppPlayingState.error;
      wrapper.notifyListeners();
      rethrow;
    }
    return wrapper;
  }

  Future<void> _loadForcedDuration() async {
    final src = _proxySource;
    if (src == null) return;
    final d = await WebAacProxy.fetchDuration(src);
    if (d == null) return;
    _forcedDuration = d;
    notifyListeners();
  }

  Future<void> _applyVolume() async {
    try {
      await _video.setVolume(_volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> unlockAudio() async {
    _volume = _volume <= 0 ? 1.0 : _volume;
    audioUnlocked = true;
    await _applyVolume();
    dom_audio.forceUnmuteAllVideos(volume: _volume);
    if (kDebugMode) {
      debugPrint('Web audio unlock: ${dom_audio.describeVideoAudio()}');
    }
    try {
      await _video.play();
      _state = AppPlayingState.playing;
    } catch (_) {}
    notifyListeners();
  }

  void _notifyInit() {
    if (_initNotified) return;
    _initNotified = true;
    for (final l in List<VoidCallback>.from(_onInit)) {
      l();
    }
  }

  Duration get _absolutePosition => _originOffset + _video.value.position;

  void _onVideoChanged() {
    if (_swapping) return;
    final v = _video.value;
    if (v.hasError) {
      _state = AppPlayingState.error;
    } else if (!v.isInitialized) {
      _state = AppPlayingState.initializing;
    } else if (v.isCompleted) {
      final abs = _absolutePosition;
      final total = _forcedDuration;
      // Frag MP4 erken "bitti" diyebilir; gerçek sona gelmediyse devam ettir.
      if (_proxyHardSeek &&
          total != null &&
          abs < total - const Duration(seconds: 3)) {
        unawaited(seekTo(abs));
        return;
      }
      _state = AppPlayingState.ended;
    } else if (v.isBuffering) {
      _state = AppPlayingState.buffering;
    } else if (v.isPlaying) {
      _state = AppPlayingState.playing;
    } else {
      _state = AppPlayingState.paused;
    }
    notifyListeners();
  }

  @override
  AppPlayerValue get value {
    final v = _video.value;
    final duration = _forcedDuration ?? v.duration;
    final position = _proxyHardSeek ? _absolutePosition : v.position;
    return AppPlayerValue(
      duration: duration,
      position: position > duration && duration > Duration.zero
          ? duration
          : position,
      playingState: _state,
      isPlaying: v.isPlaying,
      isInitialized: v.isInitialized,
      isEnded: _state == AppPlayingState.ended,
      hasError: v.hasError || _state == AppPlayingState.error,
    );
  }

  @override
  dynamic get nativeVlcController => null;

  @override
  Future<void> play() async {
    await _applyVolume();
    dom_audio.forceUnmuteAllVideos(volume: _volume);
    audioUnlocked = true;
    await _video.play();
    _state = AppPlayingState.playing;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    await _video.pause();
    _state = AppPlayingState.paused;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    if (_proxyHardSeek) {
      await seekTo(Duration.zero);
      await pause();
      _state = AppPlayingState.stopped;
      notifyListeners();
      return;
    }
    await _video.pause();
    await _video.seekTo(Duration.zero);
    _state = AppPlayingState.stopped;
    notifyListeners();
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (!_proxyHardSeek) {
      await _video.seekTo(position);
      return;
    }
    if (_swapping) return;
    final src = _proxySource;
    if (src == null) return;

    _swapping = true;
    _state = AppPlayingState.buffering;
    notifyListeners();

    final target = position.isNegative ? Duration.zero : position;
    final newUrl = WebAacProxy.wrap(
      src,
      startSeconds: target.inMilliseconds / 1000.0,
    );

    final old = _video;
    old.removeListener(_onVideoChanged);
    try {
      await old.pause();
    } catch (_) {}

    final video = VideoPlayerController.networkUrl(
      Uri.parse(newUrl),
      httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
    );
    try {
      await video.initialize();
      await video.setVolume(_volume.clamp(0.0, 1.0));
      video.addListener(_onVideoChanged);
      _video = video;
      _playUrl = newUrl;
      _originOffset = target;
      _initNotified = true;
      await video.play();
      _state = AppPlayingState.playing;
      dom_audio.forceUnmuteAllVideos(volume: _volume);
      notifyListeners();
    } catch (e) {
      _state = AppPlayingState.error;
      notifyListeners();
      rethrow;
    } finally {
      _swapping = false;
      try {
        await old.dispose();
      } catch (_) {}
    }
  }

  @override
  Future<void> setVolume(int volume) async {
    _volume = (volume.clamp(0, 100)) / 100.0;
    await _applyVolume();
    if (_volume > 0) {
      audioUnlocked = true;
      dom_audio.forceUnmuteAllVideos(volume: _volume);
    }
  }

  @override
  Future<bool> isPlaying() async => _video.value.isPlaying;

  @override
  Future<void> setMediaFromNetwork(String url, {bool autoPlay = true}) async {
    throw UnsupportedError('Web: setMediaFromNetwork desteklenmiyor');
  }

  @override
  Future<Map<int, String>> getAudioTracks() async => const {};

  @override
  Future<Map<int, String>> getSpuTracks() async => const {};

  @override
  Future<int> getAudioTrack() async => -1;

  @override
  Future<int> getSpuTrack() async => -1;

  @override
  Future<void> setAudioTrack(int trackId) async {}

  @override
  Future<void> setSpuTrack(int trackId) async {}

  @override
  Future<void> castToRenderer(String rendererId) async {}

  @override
  Future<void> startRendererScanning() async {}

  @override
  Future<void> stopRendererScanning() async {}

  @override
  void addOnInitListener(VoidCallback listener) {
    _onInit.add(listener);
    if (_initNotified) listener();
  }

  @override
  void removeOnInitListener(VoidCallback listener) {
    _onInit.remove(listener);
  }

  @override
  Widget buildView({
    required double aspectRatio,
    Widget? placeholder,
  }) {
    if (!_video.value.isInitialized) {
      return placeholder ?? const SizedBox.shrink();
    }
    return AspectRatio(
      aspectRatio: _video.value.aspectRatio == 0
          ? aspectRatio
          : _video.value.aspectRatio,
      child: VideoPlayer(_video),
    );
  }

  @override
  Future<void> release() async {
    _video.removeListener(_onVideoChanged);
    _onInit.clear();
    try {
      await _video.dispose();
    } catch (_) {}
    dispose();
  }
}
