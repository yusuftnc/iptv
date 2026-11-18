/// Ortak oynatma durumu (VLC PlayingState karşılığı).
enum AppPlayingState {
  initializing,
  initialized,
  buffering,
  playing,
  paused,
  stopped,
  ended,
  error,
}

class AppPlayerValue {
  const AppPlayerValue({
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.playingState = AppPlayingState.initializing,
    this.isPlaying = false,
    this.isInitialized = false,
    this.isEnded = false,
    this.hasError = false,
    this.audioTracksCount = 0,
    this.spuTracksCount = 0,
  });

  final Duration duration;
  final Duration position;
  final AppPlayingState playingState;
  final bool isPlaying;
  final bool isInitialized;
  final bool isEnded;
  final bool hasError;
  final int audioTracksCount;
  final int spuTracksCount;

  AppPlayerValue copyWith({
    Duration? duration,
    Duration? position,
    AppPlayingState? playingState,
    bool? isPlaying,
    bool? isInitialized,
    bool? isEnded,
    bool? hasError,
    int? audioTracksCount,
    int? spuTracksCount,
  }) {
    return AppPlayerValue(
      duration: duration ?? this.duration,
      position: position ?? this.position,
      playingState: playingState ?? this.playingState,
      isPlaying: isPlaying ?? this.isPlaying,
      isInitialized: isInitialized ?? this.isInitialized,
      isEnded: isEnded ?? this.isEnded,
      hasError: hasError ?? this.hasError,
      audioTracksCount: audioTracksCount ?? this.audioTracksCount,
      spuTracksCount: spuTracksCount ?? this.spuTracksCount,
    );
  }
}
