import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_player_types.dart';
import 'vlc_app_player.dart';
import 'web_app_player.dart';

export 'app_player_types.dart';

/// Mobilde VLC, webde HTML5 [video_player].
abstract class AppPlayerController extends ChangeNotifier {
  AppPlayerValue get value;

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seekTo(Duration position);
  Future<void> setVolume(int volume);
  Future<bool> isPlaying();
  Future<void> setMediaFromNetwork(String url, {bool autoPlay = true});

  Future<Map<int, String>> getAudioTracks();
  Future<Map<int, String>> getSpuTracks();
  Future<int> getAudioTrack();
  Future<int> getSpuTrack();
  Future<void> setAudioTrack(int trackId);
  Future<void> setSpuTrack(int trackId);

  Future<void> castToRenderer(String rendererId);
  Future<void> startRendererScanning();
  Future<void> stopRendererScanning();

  /// Cast UI için; webde null.
  dynamic get nativeVlcController;

  void addOnInitListener(VoidCallback listener);
  void removeOnInitListener(VoidCallback listener);

  Widget buildView({
    required double aspectRatio,
    Widget? placeholder,
  });

  /// Oynatıcı kaynaklarını bırak (ChangeNotifier.dispose dahil).
  Future<void> release();

  static Future<AppPlayerController> network(
    String url, {
    required bool autoPlay,
    required bool isLive,
  }) {
    if (kIsWeb) {
      return WebAppPlayerController.create(
        url: url,
        autoPlay: autoPlay,
      );
    }
    return VlcAppPlayerController.create(
      url: url,
      autoPlay: autoPlay,
      isLive: isLive,
    );
  }
}
