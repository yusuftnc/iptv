import 'package:flutter/widgets.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

import 'app_player.dart';

class VlcAppPlayerController extends AppPlayerController {
  VlcAppPlayerController._(this._vlc);

  final VlcPlayerController _vlc;
  final List<VoidCallback> _onInit = [];

  static Future<AppPlayerController> create({
    required String url,
    required bool autoPlay,
    required bool isLive,
  }) async {
    final options = VlcPlayerOptions(
      advanced: VlcAdvancedOptions([
        VlcAdvancedOptions.networkCaching(isLive ? 800 : 2000),
      ]),
      http: VlcHttpOptions([
        VlcHttpOptions.httpReconnect(true),
        VlcHttpOptions.httpUserAgent('Mozilla/5.0'),
      ]),
      video: VlcVideoOptions([
        VlcVideoOptions.dropLateFrames(true),
        VlcVideoOptions.skipFrames(true),
      ]),
    );
    final vlc = VlcPlayerController.network(
      url,
      autoPlay: autoPlay,
      options: options,
    );
    final wrapper = VlcAppPlayerController._(vlc);
    vlc.addListener(wrapper._onVlcChanged);
    return wrapper;
  }

  void _onVlcChanged() => notifyListeners();

  AppPlayingState _mapState(PlayingState state) {
    switch (state) {
      case PlayingState.initializing:
        return AppPlayingState.initializing;
      case PlayingState.initialized:
        return AppPlayingState.initialized;
      case PlayingState.buffering:
        return AppPlayingState.buffering;
      case PlayingState.playing:
      case PlayingState.recording:
        return AppPlayingState.playing;
      case PlayingState.paused:
        return AppPlayingState.paused;
      case PlayingState.stopped:
        return AppPlayingState.stopped;
      case PlayingState.ended:
        return AppPlayingState.ended;
      case PlayingState.error:
        return AppPlayingState.error;
    }
  }

  @override
  AppPlayerValue get value {
    final v = _vlc.value;
    return AppPlayerValue(
      duration: v.duration,
      position: v.position,
      playingState: _mapState(v.playingState),
      isPlaying: v.isPlaying,
      isInitialized: v.isInitialized,
      isEnded: v.isEnded,
      hasError: v.hasError,
      audioTracksCount: v.audioTracksCount,
      spuTracksCount: v.spuTracksCount,
    );
  }

  @override
  dynamic get nativeVlcController => _vlc;

  @override
  Future<void> play() => _vlc.play();

  @override
  Future<void> pause() => _vlc.pause();

  @override
  Future<void> stop() => _vlc.stop();

  @override
  Future<void> seekTo(Duration position) => _vlc.seekTo(position);

  @override
  Future<void> setVolume(int volume) => _vlc.setVolume(volume);

  @override
  Future<bool> isPlaying() async => await _vlc.isPlaying() ?? false;

  @override
  Future<void> setMediaFromNetwork(String url, {bool autoPlay = true}) =>
      _vlc.setMediaFromNetwork(url, autoPlay: autoPlay);

  @override
  Future<Map<int, String>> getAudioTracks() => _vlc.getAudioTracks();

  @override
  Future<Map<int, String>> getSpuTracks() => _vlc.getSpuTracks();

  @override
  Future<int> getAudioTrack() async => await _vlc.getAudioTrack() ?? -1;

  @override
  Future<int> getSpuTrack() async => await _vlc.getSpuTrack() ?? -1;

  @override
  Future<void> setAudioTrack(int trackId) => _vlc.setAudioTrack(trackId);

  @override
  Future<void> setSpuTrack(int trackId) => _vlc.setSpuTrack(trackId);

  @override
  Future<void> castToRenderer(String rendererId) =>
      _vlc.castToRenderer(rendererId);

  @override
  Future<void> startRendererScanning() => _vlc.startRendererScanning();

  @override
  Future<void> stopRendererScanning() => _vlc.stopRendererScanning();

  @override
  void addOnInitListener(VoidCallback listener) {
    _onInit.add(listener);
    _vlc.addOnInitListener(listener);
  }

  @override
  void removeOnInitListener(VoidCallback listener) {
    _onInit.remove(listener);
    _vlc.removeOnInitListener(listener);
  }

  @override
  Widget buildView({
    required double aspectRatio,
    Widget? placeholder,
  }) {
    return VlcPlayer(
      controller: _vlc,
      aspectRatio: aspectRatio,
      placeholder: placeholder ?? const SizedBox.shrink(),
    );
  }

  @override
  Future<void> release() async {
    _vlc.removeListener(_onVlcChanged);
    for (final l in List<VoidCallback>.from(_onInit)) {
      try {
        _vlc.removeOnInitListener(l);
      } catch (_) {}
    }
    _onInit.clear();
    try {
      await _vlc.dispose();
    } catch (_) {}
    dispose();
  }
}
