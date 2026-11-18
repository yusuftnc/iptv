import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Flutter video_player_web öğelerini DOM üzerinden sesli hale getir.
void forceUnmuteAllVideos({double volume = 1.0}) {
  final videos = web.document.querySelectorAll('video');
  for (var i = 0; i < videos.length; i++) {
    final node = videos.item(i);
    if (node == null) continue;
    final video = node as web.HTMLVideoElement;
    video.muted = false;
    video.volume = volume.clamp(0.0, 1.0);
    // Bazı tarayıcılarda play Promise'i jest ister; yut.
    video.play().toDart.catchError((_) => null);
  }
}

/// Video elementinde muted / volume durumu (debug).
String describeVideoAudio() {
  final videos = web.document.querySelectorAll('video');
  if (videos.length == 0) return 'video yok';
  final parts = <String>[];
  for (var i = 0; i < videos.length; i++) {
    final node = videos.item(i);
    if (node == null) continue;
    final video = node as web.HTMLVideoElement;
    parts.add(
      '#$i muted=${video.muted} vol=${video.volume} paused=${video.paused}',
    );
  }
  return parts.join(' | ');
}
