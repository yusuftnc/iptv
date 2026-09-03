import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:iptv_app/utils/logger.dart';
import '../models/content_item.dart';
import '../models/playlist_episode.dart';
import '../services/iptv_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import 'dart:async';
import 'dart:math' show max;

class PlayerScreen extends StatefulWidget {
  final String contentId;
  final String streamUrl;
  final String contentType;
  final String name;
  final String? streamIcon;
  final String historyId;
  final List<PlaylistEpisode>? playlist;
  final int? playlistIndex;

  /// Önceki bölümden geçişte yatay kilit durumunu koru.
  final bool lockLandscape;

  const PlayerScreen({
    Key? key,
    required this.contentId,
    required this.streamUrl,
    required this.contentType,
    this.name = '',
    this.streamIcon,
    required this.historyId,
    this.playlist,
    this.playlistIndex,
    this.lockLandscape = false,
  }) : super(key: key);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VlcPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final IptvService _iptvService = IptvService();
  final DatabaseService _databaseService = DatabaseService();
  final StorageService _storageService = StorageService();
  bool _isFavorite = false;

  // Kontrol paneli için değişkenler
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _positionUpdateTimer;
  bool _isDraggingProgress = false;
  double _currentVolume = 100;
  bool _isMuted = false;
  Map<int, String> _availableSubtitles = {}; // id -> name
  int? _currentSubtitleId; // VLC track id, -1 => Kapalı
  Map<int, String> _audioTracks = {};
  int? _currentAudioId;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Tam ekran değişkenini ekle
  bool _isFullScreen = false;

  // Pozisyon ayarlama denemelerini başlat
  bool _seekAttemptsStarted = false;
  int? _initialSeekPosition;
  bool _shouldSeekToInitialPosition = false;
  int _seekAttemptCount = 0;
  final int _maxSeekAttempts = 5;

  // İzleme geçmişi anahtarı
  late final String _historyId;

  /// player_api çözümledikten sonra kullanılan gerçek URL (veritabanına yazılır)
  String? _resolvedStreamUrl;

  List<PlaylistEpisode>? _playlist;
  int? _playlistIndex;
  bool _handledEpisodeEnd = false;
  bool _showNextEpisodeCta = false;
  bool _autoPlayNext = true;

  /// Ses/altyazı tercihleri — seek sonrası VLC sıfırladığı için tekrar uygulanır.
  String? _preferredAudioLabel;
  String? _preferredSubtitleLabel;
  bool _audioPrefApplied = false;
  bool _subtitlePrefApplied = false;
  Timer? _trackPrefTimer;
  int _trackPrefAttempts = 0;
  int _lastAudioTracksCount = -1;
  int _lastSpuTracksCount = -1;
  bool _syncingTracks = false;

  String get _streamUrlForStorage =>
      (_resolvedStreamUrl != null && _resolvedStreamUrl!.isNotEmpty)
          ? _resolvedStreamUrl!
          : widget.streamUrl;

  bool get _hasPreviousEpisode =>
      _playlist != null &&
      _playlistIndex != null &&
      _playlistIndex! > 0;

  bool get _hasNextEpisode =>
      _playlist != null &&
      _playlistIndex != null &&
      _playlistIndex! < _playlist!.length - 1;

  void _cancelSeekAttempts() {
    // Gelecekteki denemeleri engelle
    _seekAttemptCount = _maxSeekAttempts;
    _seekAttemptsStarted = true;
  }

  // Last saved position
  Duration? _lastSavedPosition;

  /// Sonraki/önceki bölüme geçerken dispose portreye zorlamasın.
  bool _navigatingToEpisode = false;

  @override
  void initState() {
    super.initState();
    _historyId = widget.historyId;
    _playlist = widget.playlist;
    _playlistIndex = widget.playlistIndex;
    _isFullScreen = widget.lockLandscape;

    _applyPlayerOrientations();
    // pushReplacement sırasında eski dispose bazen sonra çalışır; yönü pekiştir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyPlayerOrientations();
    });
    // Status bar (saat/pil) görünsün
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    _loadAutoPlaySetting();
    _loadTrackPreferences();
    _ensurePlaylist();

    _checkWatchPosition().then((_) {
      _initializePlayer();
      _checkIfFavorite();
      _startHideControlsTimer();
    });
  }

  void _applyPlayerOrientations() {
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _restoreExitOrientations() {
    if (_navigatingToEpisode) return;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _loadTrackPreferences() async {
    final audio = await _storageService.getPreferredAudioTrack();
    final sub = await _storageService.getPreferredSubtitleTrack();
    if (!mounted) return;
    _preferredAudioLabel = audio;
    _preferredSubtitleLabel = sub;
    Log.d('DBG', 'Track prefs loaded audio=$audio sub=$sub');
  }

  Future<void> _loadAutoPlaySetting() async {
    try {
      final settings = await _databaseService.getUserSettings();
      if (mounted) {
        setState(() => _autoPlayNext = settings.autoPlayNext);
      } else {
        _autoPlayNext = settings.autoPlayNext;
      }
    } catch (_) {}
  }

  Future<void> _ensurePlaylist() async {
    if (widget.contentType != 'series') return;

    if (_playlist != null && _playlist!.isNotEmpty) {
      _playlistIndex ??=
          _playlist!.indexWhere((e) => e.id == widget.contentId);
      if (_playlistIndex == -1) _playlistIndex = null;
      if (mounted) setState(() {});
      return;
    }

    final seriesId = widget.historyId;
    if (seriesId.isEmpty) return;

    try {
      final episodesBySeason =
          await _iptvService.getSeriesEpisodes(seriesId);
      final seasons = episodesBySeason.keys.toList();
      seasons.sort((a, b) {
        final ai = int.tryParse(a);
        final bi = int.tryParse(b);
        if (ai != null && bi != null) return ai.compareTo(bi);
        return a.compareTo(b);
      });

      var seriesTitle = widget.name.trim();
      final titleMatch = RegExp(r'\s-\sS\d+E').firstMatch(seriesTitle);
      if (titleMatch != null && titleMatch.start > 0) {
        seriesTitle = seriesTitle.substring(0, titleMatch.start).trim();
      }

      final flat = <PlaylistEpisode>[];
      for (final season in seasons) {
        final eps = episodesBySeason[season] ?? [];
        for (final episode in eps) {
          final epNum = episode['episode_num'];
          final epLabel = (epNum == null || epNum.toString() == 'null')
              ? '?'
              : epNum.toString();
          final streamUrl = episode['container_extension'] != null &&
                  episode['container_extension'].toString().isNotEmpty
              ? '${_iptvService.getServerUrl()}/series/${_iptvService.getUsername()}/${_iptvService.getPassword()}/${episode['id']}.${episode['container_extension']}'
              : null;
          flat.add(PlaylistEpisode(
            id: episode['id'].toString(),
            name:
                '$seriesTitle - S${season}E$epLabel - ${episode['title'] ?? ''}',
            streamUrl: streamUrl,
            season: season,
            episodeLabel: epLabel,
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _playlist = flat;
        final idx = flat.indexWhere((e) => e.id == widget.contentId);
        _playlistIndex = idx >= 0 ? idx : null;
      });
    } catch (e) {
      Log.d('DBG', 'Playlist yüklenemedi: $e');
    }
  }

  Future<void> _checkIfFavorite() async {
    final isFavorite = await _databaseService.isFavorite(widget.contentId);
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await _databaseService.removeFavorite(widget.contentId);
    } else {
      await _databaseService.addFavorite(ContentItem(
        id: widget.contentId,
        name: widget.name,
        streamUrl: _streamUrlForStorage,
        streamType: widget.contentType,
        streamIcon: widget.streamIcon,
        historyId: _historyId,
      ));
    }

    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  Future<void> _addToWatchHistory() async {
    try {
      Log.d("DBG",
          "Debug - İlk izleme pozisyonu kontrolü başlatılıyor: ${widget.contentId}");
      Log.d("DBG", "Debug - İzleme geçmişine ekleniyor: ${widget.contentId}");

      // İlk olarak izleme geçmişine ekle
      await _databaseService.addToWatchHistory(ContentItem(
        id: widget.contentId,
        name: widget.name,
        streamUrl: _streamUrlForStorage,
        streamType: widget.contentType,
        streamIcon: widget.streamIcon,
        historyId: _historyId,
      ));
      Log.d("DBG", "Debug - İzleme geçmişine eklendi");
    } catch (e) {
      Log.d("DBG", "Debug - İzleme geçmişine eklenirken hata: $e");
    }
  }

  Future<void> _updateWatchPosition() async {
    try {
      if (_controller != null &&
          _currentPosition.inSeconds > 0 &&
          _totalDuration.inSeconds > 0 &&
          _currentPosition.inSeconds < _totalDuration.inSeconds) {
        Log.d("DBG",
            "Debug - İzleme pozisyonu güncelleniyor: ${_currentPosition.inSeconds} / ${_totalDuration.inSeconds}");
        Log.d("DBG", "Debug - ContentItem ID: ${widget.contentId}");

        final contentItem = ContentItem(
          id: widget.contentId,
          name: widget.name,
          streamUrl: _streamUrlForStorage,
          streamType: widget.contentType,
          streamIcon: widget.streamIcon,
          position: _currentPosition.inSeconds,
          duration: _totalDuration.inSeconds,
          historyId: _historyId,
        );

        await _databaseService.addToWatchHistory(contentItem);

        // Veritabanına kaydedilen pozisyonu doğrula
        final savedPosition =
            await _databaseService.getWatchPosition(_historyId);
        Log.d("DBG",
            "Debug - Kaydedilen pozisyon kontrolü: ${savedPosition?.position} / ${savedPosition?.duration}");
        Log.d("DBG", "Debug - İzleme pozisyonu güncellendi");
      } else {
        Log.d("DBG",
            "Debug - İzleme pozisyonu güncellenemiyor: ${_controller != null ? 'Controller var' : 'Controller yok'}, Pozisyon: ${_currentPosition.inSeconds}");
      }
    } catch (e) {
      Log.d("DBG", "Debug - İzleme pozisyonu güncellenirken hata: $e");
      Log.d("DBG", "Debug - Hata türü: ${e.runtimeType}");
    }
  }

  Future<void> _checkWatchPosition() async {
    try {
      // Canlı yayında süre/pozisyon genelde anlamsızdır; seek diyalogu ve seekTo siyah ekran/kilit yapabilir.
      if (widget.contentType == 'live') {
        return;
      }
      Log.d("DBG",
          "Debug - İzleme pozisyonu kontrol ediliyor: ${widget.contentId}");
      final watchHistory = await _databaseService.getWatchPosition(_historyId);
      Log.d("DBG",
          "Debug - Alınan izleme geçmişi: ${watchHistory?.position} / ${watchHistory?.duration}");
      Log.d("DBG",
          "Debug - İzleme geçmişi contentId: ${watchHistory?.contentId}");
      Log.d("DBG", "Debug - Current contentItem id: ${widget.contentId}");

      final sameEpisode = watchHistory?.contentId == widget.contentId;
      if (!sameEpisode && watchHistory != null) {
        Log.d("DBG",
            "Debug - Kayıt başka bir bölüme ait (${watchHistory.contentId} vs ${widget.contentId}), devam diyalogu atlanıyor");
      }

      if (watchHistory != null &&
          sameEpisode &&
          watchHistory.position != null &&
          watchHistory.position! > 10 &&
          watchHistory.duration != null &&
          watchHistory.position! < (watchHistory.duration! - 30)) {
        Log.d("DBG", "Debug - İzleme pozisyonu bulundu, diyalog gösteriliyor");

        if (mounted) {
          final result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Kaldığınız Yerden Devam Et'),
              content: Text(
                  'Bu içeriği daha önce ${_formatDuration(Duration(seconds: watchHistory.position!))} kadar izlediniz. Kaldığınız yerden devam etmek istiyor musunuz?'),
              actions: [
                TextButton(
                  onPressed: () {
                    // Baştan başla seçildiğinde pozisyonu sıfırla
                    _databaseService.addToWatchHistory(ContentItem(
                      id: widget.contentId,
                      name: widget.name,
                      streamUrl: _streamUrlForStorage,
                      streamType: widget.contentType,
                      streamIcon: widget.streamIcon,
                      position: 0,
                      duration: watchHistory.duration,
                      historyId: _historyId,
                    ));
                    Navigator.pop(context, false);
                  },
                  child: const Text('Hayır, Baştan Başla'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Evet, Devam Et'),
                ),
              ],
            ),
          );
          Log.d("DBG", "Debug - Kullanıcı tercihi: $result");

          if (result == true && _controller != null) {
            Log.d("DBG",
                "Debug - Video ${watchHistory.position!} saniyeye ilerletiliyor");

            // Birden fazla kez seekTo dene (controller'ın tamamen hazır olması için)
            try {
              await _controller!
                  .seekTo(Duration(seconds: watchHistory.position!));

              // Kontrol etmek için 1 saniye sonra tekrar dene
              Future.delayed(const Duration(seconds: 1), () async {
                if (_controller != null && mounted) {
                  final currentPos = _controller!.value.position.inSeconds;
                  Log.d("DBG",
                      "Debug - İlerleme sonrası pozisyon kontrolü: $currentPos");

                  // Eğer pozisyon hala başlangıçtaysa tekrar dene
                  if (currentPos < 3) {
                    Log.d("DBG",
                        "Debug - Pozisyon doğru ayarlanmamış, tekrar deneniyor");
                    await _controller!
                        .seekTo(Duration(seconds: watchHistory.position!));
                  }
                }
              });
            } catch (e) {
              Log.d("DBG", "Debug - seekTo sırasında hata: $e");

              // Diğer yöntemi dene
              Future.delayed(const Duration(seconds: 2), () async {
                if (_controller != null && mounted) {
                  try {
                    Log.d("DBG",
                        "Debug - Alternatif yöntemle ilerleme deneniyor");
                    await _controller!
                        .seekTo(Duration(seconds: watchHistory.position!));
                  } catch (e) {
                    Log.d("DBG",
                        "Debug - Alternatif ilerleme sırasında hata: $e");
                  }
                }
              });
            }
            Log.d("DBG", "Debug - Video pozisyon ayarlaması tamamlandı");
          }
        }
      } else {
        Log.d("DBG",
            "Debug - Devam diyalogu gösterilmedi (koşullar sağlanmadı)");
        if (watchHistory == null) {
          Log.d("DBG", "Debug - İzleme geçmişi bulunamadı");
        } else if (!sameEpisode) {
          Log.d("DBG",
              "Debug - Kayıt son izlenen bölüme (${watchHistory.contentId}) ait, şu anki bölüm ${widget.contentId}; bu bölüm baştan oynatılır");
        } else if (watchHistory.position == null) {
          Log.d("DBG", "Debug - İzleme pozisyonu null");
        } else if (watchHistory.position! <= 10) {
          Log.d("DBG",
              "Debug - İzleme pozisyonu çok kısa: ${watchHistory.position}");
        } else if (watchHistory.duration == null) {
          Log.d("DBG", "Debug - Video süresi null");
        } else if (watchHistory.position! >= (watchHistory.duration! - 30)) {
          Log.d("DBG",
              "Debug - İzleme pozisyonu videonun sonuna çok yakın: ${watchHistory.position} / ${watchHistory.duration}");
        }
      }
    } catch (e) {
      Log.d("DBG", 'Debug - İzleme pozisyonu kontrol edilirken hata: $e');
      Log.d("DBG", 'Debug - Hata türü: ${e.runtimeType}');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });

      // İçerik türüne göre stream URL'ini al
      String? streamUrl;

      if (widget.streamUrl != null && widget.streamUrl.isNotEmpty) {
        // Eğer ContentItem'da zaten bir URL varsa, onu kullan
        streamUrl = widget.streamUrl;
        Log.d("DBG", 'Debug - ContentItem\'dan URL kullanılıyor: $streamUrl');
      } else {
        // Yoksa, servis üzerinden URL'i al
        final streamType = widget.contentType ?? 'live';

        // Eğer dizi bölümü ise, özel işlem yap
        if (streamType == 'series' && widget.contentId.isNotEmpty) {
          // Dizi bölüm ID'sini kullanarak stream URL'ini al
          streamUrl = await _iptvService.getStreamUrl(
            streamId: widget.contentId,
            streamType: 'series',
          );

          // Eğer URL alınamazsa, alternatif formatları dene
          if (streamUrl == null || streamUrl.isEmpty) {
            final serverUrl = _iptvService.getServerUrl();
            final username = _iptvService.getUsername();
            final password = _iptvService.getPassword();

            if (serverUrl != null && username != null && password != null) {
              // Farklı formatları dene
              final formats = [
                '$serverUrl/series/$username/$password/${widget.contentId}.mp4',
                '$serverUrl/series/$username/$password/${widget.contentId}.mkv',
                '$serverUrl/series/$username/$password/${widget.contentId}.ts',
                '$serverUrl/series/$username/$password/${widget.contentId}.m3u8',
                '$serverUrl/series/$username/$password/series/${widget.contentId}.mp4',
                '$serverUrl/series/$username/$password/series/${widget.contentId}.mkv',
                '$serverUrl/series/$username/$password/series/${widget.contentId}.ts',
                '$serverUrl/series/$username/$password/series/${widget.contentId}.m3u8',
              ];

              // İlk formatı kullan (daha sonra diğerlerini deneyebiliriz)
              streamUrl = formats.first;
              Log.d("DBG", 'Debug - Alternatif URL kullanılıyor: $streamUrl');
            }
          }
        } else {
          // Normal içerik için stream URL'ini al
          streamUrl = await _iptvService.getStreamUrl(
            streamId: widget.contentId,
            streamType: streamType,
          );
        }
        Log.d("DBG", 'Debug - Servis üzerinden URL alındı: $streamUrl');
      }
      Log.d("DBG", 'Debug - Stream URL: $streamUrl');
      Log.d("DBG", 'Debug - Content Type: ${widget.contentType}');
      Log.d("DBG", 'Debug - Content ID: ${widget.contentId}');

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('Stream URL bulunamadı');
      }
      _resolvedStreamUrl = streamUrl;

      // İlk önce izleme pozisyonunu al
      Log.d("DBG",
          "Debug - Video yüklenmeden önce izleme pozisyonu kontrol ediliyor.");
      final watchHistory = await _databaseService.getWatchPosition(_historyId);
      Log.d("DBG",
          "Debug - İzleme geçmişi: ${watchHistory?.position} / ${watchHistory?.duration}");

      // İzleme pozisyonu uygun mu kontrol et
      bool shouldResume = false;
      int? resumePosition;

      final recordMatchesThisVideo =
          watchHistory?.contentId == widget.contentId;
      if (widget.contentType != 'live' &&
          watchHistory != null &&
          recordMatchesThisVideo &&
          watchHistory.position != null &&
          watchHistory.position! > 10 &&
          watchHistory.duration != null &&
          watchHistory.position! < (watchHistory.duration! - 30)) {
        shouldResume = true;
        resumePosition = watchHistory.position;
        Log.d("DBG", "Debug - Video ${resumePosition} saniyeden devam edecek");
      } else if (watchHistory != null &&
          !recordMatchesThisVideo &&
          widget.contentType == 'series') {
        Log.d("DBG",
            "Debug - Veritabanındaki kayıt başka bölüm; otomatik seek yapılmıyor");
      }

      // İzleme pozisyonu uygulama başlatılacağı pozisyonu (seekTo pozisyonunu) kaydet
      // Bunu yapmamızın sebebi onInit sırasında kullanmak yerine, daha sonra kullanabilmek
      _initialSeekPosition = resumePosition;
      _shouldSeekToInitialPosition = shouldResume;

      // Önceki controller'ı temizle
      await _controller?.dispose();

      // Yeni controller oluştur
      final initialOptions = VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(2000),
        ]),
        http: VlcHttpOptions([
          VlcHttpOptions.httpReconnect(true),
        ]),
        video: VlcVideoOptions([
          VlcVideoOptions.dropLateFrames(true),
          VlcVideoOptions.skipFrames(true),
        ]),
      );
      Log.d("DBG", "Debug - VLC Player controller oluşturuluyor");

      // Controller'ı eğer izleme pozisyonu varsa ve bu bir film/diziyse (live değilse)
      // autoPlay:false ile başlat, böylece ilk frame'de pozisyona atlaması daha kolay olur
      final isLiveContent = widget.contentType == 'live';
      final shouldAutoPlay = isLiveContent || !shouldResume;

      _controller = VlcPlayerController.network(
        streamUrl,
        autoPlay: shouldAutoPlay,
        options: initialOptions,
      );

      // Pozisyon güncelleme timeri başlat
      _startPositionUpdateTimer();

      // Controller hazır olduğunda çalışacak listener
      _controller!.addOnInitListener(() async {
        Log.d("DBG", "Debug - Video controller initialize oldu");
        _startTrackPreferenceWatcher();
        await _syncPreferredTracks(force: true);

        if (!shouldAutoPlay) {
          Log.d("DBG", "Debug - Pozisyon ayarlanana kadar video duraklatıldı");
        }

        if (_shouldSeekToInitialPosition && _initialSeekPosition != null) {
          Log.d("DBG",
              "Debug - Controller hazır, pozisyon ayarlamayı deneyeceğiz");
          _startSeekAttempts(_initialSeekPosition!);
        }
      });

      // Video durumunu dinlemek için listener ekleniyor
      _controller!.addListener(() {
        if (_controller == null || !mounted) return;

        final v = _controller!.value;
        if (v.isInitialized &&
            v.isPlaying &&
            v.position.inSeconds > 0 &&
            _shouldSeekToInitialPosition &&
            _initialSeekPosition != null) {
          if (!_seekAttemptsStarted) {
            Log.d("DBG",
                "Debug - Video oynamaya başladı, pozisyon ayarlamayı deneyeceğiz");
            _startSeekAttempts(_initialSeekPosition!);
          }
        }

        // Track sayısı değişince / oynatma başlayınca tercihleri yeniden uygula
        if (v.isInitialized &&
            (v.audioTracksCount != _lastAudioTracksCount ||
                v.spuTracksCount != _lastSpuTracksCount ||
                (v.isPlaying &&
                    (!_audioPrefApplied || !_subtitlePrefApplied)))) {
          _lastAudioTracksCount = v.audioTracksCount;
          _lastSpuTracksCount = v.spuTracksCount;
          _syncPreferredTracks();
        }
      });

      setState(() {
        _isLoading = false;
      });

      // İzleme geçmişine ekle (başlangıç kaydı)
      _addToWatchHistory();
    } catch (e) {
      Log.d("DBG", 'Debug - Hata oluştu: $e');
      Log.d("DBG", 'Debug - Hata türü: ${e.runtimeType}');
      setState(() {
        _hasError = true;
        _errorMessage = 'Video oynatıcı başlatılamadı: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isDraggingProgress) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideControlsTimer();
      }
    });
  }

  void _seekForward() {
    if (_controller != null) {
      final currentPos = _controller!.value.position.inSeconds;
      _controller!.seekTo(Duration(seconds: currentPos + 10));
      _audioPrefApplied = false;
      _subtitlePrefApplied = false;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _syncPreferredTracks(force: true);
      });
      _startHideControlsTimer();
    }
  }

  void _seekBackward() {
    if (_controller != null) {
      final currentPos = _controller!.value.position.inSeconds;
      _controller!.seekTo(Duration(seconds: max(0, currentPos - 10)));
      _audioPrefApplied = false;
      _subtitlePrefApplied = false;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _syncPreferredTracks(force: true);
      });
      _startHideControlsTimer();
    }
  }

  void _setVolume(double value) {
    if (_controller != null) {
      setState(() {
        _currentVolume = value.clamp(0.0, 100.0);
        _isMuted = _currentVolume == 0;
        _controller!.setVolume(_currentVolume.toInt());
      });
      _startHideControlsTimer();
    }
  }

  void _toggleMute() {
    if (_controller != null) {
      setState(() {
        if (_isMuted) {
          // Unmute
          _isMuted = false;
          _controller!.setVolume(_currentVolume.toInt());
        } else {
          // Mute
          _isMuted = true;
          _controller!.setVolume(0);
        }
      });
      _startHideControlsTimer();
    }
  }

  Future<void> _loadSubtitles() async {
    await _syncPreferredTracks(force: true);
  }

  Future<void> _setSubtitle(int trackId) async {
    if (_controller == null) return;
    try {
      await _controller!.setSpuTrack(trackId);
      setState(() {
        _currentSubtitleId = trackId;
      });
      final label = trackId == -1
          ? StorageService.subtitleOffSentinel
          : (_availableSubtitles[trackId] ?? 'Altyazı $trackId');
      _preferredSubtitleLabel = label;
      _subtitlePrefApplied = true;
      await _storageService.savePreferredSubtitleTrack(label);
      Log.d('DBG', 'Subtitle preference saved: $label');
      _startHideControlsTimer();
    } catch (e) {
      Log.d("DBG", 'Altyazı seçilirken hata: $e');
    }
  }

  void _startTrackPreferenceWatcher() {
    _trackPrefTimer?.cancel();
    _trackPrefAttempts = 0;
    _audioPrefApplied = false;
    _subtitlePrefApplied = false;
    _trackPrefTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || _controller == null) {
        timer.cancel();
        return;
      }
      _trackPrefAttempts++;
      await _syncPreferredTracks();
      if ((_audioPrefApplied && _subtitlePrefApplied) ||
          _trackPrefAttempts >= 45) {
        timer.cancel();
      }
    });
  }

  /// Seek/play sonrası VLC varsayılana dönebiliyor; gerçek track id ile doğrula.
  Future<void> _syncPreferredTracks({bool force = false}) async {
    if (_controller == null || !mounted) return;
    if (_syncingTracks) return;
    _syncingTracks = true;
    try {
      if (_preferredAudioLabel == null && _preferredSubtitleLabel == null) {
        await _loadTrackPreferences();
      }

      Map<int, String> audioTracks = _audioTracks;
      Map<int, String> spuTracks = _availableSubtitles;
      try {
        audioTracks = await _controller!.getAudioTracks();
      } catch (_) {}
      try {
        spuTracks = await _controller!.getSpuTracks();
      } catch (_) {}

      int? activeAudio;
      int? activeSpu;
      try {
        activeAudio = await _controller!.getAudioTrack();
      } catch (_) {}
      try {
        activeSpu = await _controller!.getSpuTrack();
      } catch (_) {}

      if (mounted) {
        setState(() {
          if (audioTracks.isNotEmpty) _audioTracks = audioTracks;
          if (spuTracks.isNotEmpty) _availableSubtitles = spuTracks;
          if (activeAudio != null) _currentAudioId = activeAudio;
          _currentSubtitleId = activeSpu ?? _currentSubtitleId ?? -1;
        });
      }

      // --- Ses ---
      final audioPref = _preferredAudioLabel;
      if (audioPref != null &&
          audioPref.isNotEmpty &&
          audioTracks.isNotEmpty &&
          (!_audioPrefApplied || force)) {
        final matchId = _findBestTrackId(audioTracks, audioPref);
        if (matchId != null) {
          if (activeAudio != matchId) {
            try {
              await _controller!.setAudioTrack(matchId);
              await Future.delayed(const Duration(milliseconds: 250));
              activeAudio = await _controller!.getAudioTrack();
            } catch (e) {
              Log.d('DBG', 'setAudioTrack failed: $e');
            }
          }
          if (activeAudio == matchId) {
            _audioPrefApplied = true;
            if (mounted) setState(() => _currentAudioId = matchId);
            Log.d('DBG', 'Audio pref OK: $audioPref -> $matchId');
          } else {
            _audioPrefApplied = false;
            Log.d('DBG',
                'Audio pref pending: want $matchId got $activeAudio ($audioPref)');
          }
        } else {
          Log.d('DBG', 'Audio pref no match for "$audioPref" in $audioTracks');
        }
      } else if (audioPref == null || audioPref.isEmpty) {
        _audioPrefApplied = true; // tercih yok
      }

      // --- Altyazı ---
      final subPref = _preferredSubtitleLabel;
      if (subPref != null && (!_subtitlePrefApplied || force)) {
        if (subPref == StorageService.subtitleOffSentinel) {
          if (activeSpu != -1) {
            try {
              await _controller!.setSpuTrack(-1);
              await Future.delayed(const Duration(milliseconds: 250));
              activeSpu = await _controller!.getSpuTrack();
            } catch (_) {}
          }
          if (activeSpu == -1 || activeSpu == null) {
            _subtitlePrefApplied = true;
            if (mounted) setState(() => _currentSubtitleId = -1);
          } else {
            _subtitlePrefApplied = false;
          }
        } else if (spuTracks.isNotEmpty) {
          final matchId = _findBestTrackId(spuTracks, subPref);
          if (matchId != null) {
            if (activeSpu != matchId) {
              try {
                await _controller!.setSpuTrack(matchId);
                await Future.delayed(const Duration(milliseconds: 250));
                activeSpu = await _controller!.getSpuTrack();
              } catch (e) {
                Log.d('DBG', 'setSpuTrack failed: $e');
              }
            }
            if (activeSpu == matchId) {
              _subtitlePrefApplied = true;
              if (mounted) setState(() => _currentSubtitleId = matchId);
              Log.d('DBG', 'Subtitle pref OK: $subPref -> $matchId');
            } else {
              _subtitlePrefApplied = false;
              Log.d('DBG',
                  'Subtitle pref pending: want $matchId got $activeSpu ($subPref)');
            }
          } else {
            Log.d('DBG', 'Subtitle pref no match for "$subPref" in $spuTracks');
          }
        }
      } else if (subPref == null) {
        _subtitlePrefApplied = true;
      }
    } finally {
      _syncingTracks = false;
    }
  }

  Future<void> _applyPreferredSubtitle() async {
    await _syncPreferredTracks(force: true);
  }

  Future<void> _applyPreferredAudio() async {
    await _syncPreferredTracks(force: true);
  }

  void _startPositionUpdateTimer() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_controller != null && mounted) {
        final position = _controller!.value.position;
        final duration = _controller!.value.duration;
        final isEnded = _controller!.value.isEnded;

        if (position.inMilliseconds >= 0 && duration.inMilliseconds > 0) {
          final remaining = duration - position;
          final nearEnd = remaining.inSeconds <= 120 &&
              remaining.inSeconds > 0 &&
              _hasNextEpisode;

          setState(() {
            _currentPosition = position;
            _totalDuration = duration;
            _showNextEpisodeCta = nearEnd;
          });

          if ((position.inSeconds % 5 == 0 ||
                  (position.inSeconds - (_lastSavedPosition?.inSeconds ?? 0))
                          .abs() >=
                      5) &&
              position.inSeconds > 0 &&
              !isEnded) {
            _updateWatchPosition();
            _lastSavedPosition = position;
          }
        }

        if (isEnded && !_handledEpisodeEnd) {
          _onEpisodeEnded();
        }
      }
    });
  }

  Future<void> _onEpisodeEnded() async {
    if (_handledEpisodeEnd) return;
    _handledEpisodeEnd = true;

    // Bölüm bitti: pozisyonu sona yakın kaydet ki "Devam Et" yanlış yerden açılmasın
    if (_totalDuration.inSeconds > 0) {
      try {
        await _databaseService.addToWatchHistory(ContentItem(
          id: widget.contentId,
          name: widget.name,
          streamUrl: _streamUrlForStorage,
          streamType: widget.contentType,
          streamIcon: widget.streamIcon,
          position: _totalDuration.inSeconds,
          duration: _totalDuration.inSeconds,
          historyId: _historyId,
        ));
      } catch (_) {}
    }

    if (_autoPlayNext && _hasNextEpisode) {
      _playAdjacentEpisode(1);
      return;
    }

    // Sonraki yoksa başa sarılabilir durumda bırak; play butonu stop+play ile çalışır
    if (mounted) {
      setState(() {
        _showControls = true;
        _showNextEpisodeCta = _hasNextEpisode;
      });
    }
  }

  void _playAdjacentEpisode(int delta) {
    if (_playlist == null || _playlistIndex == null) return;
    final nextIndex = _playlistIndex! + delta;
    if (nextIndex < 0 || nextIndex >= _playlist!.length) return;
    if (!mounted) return;

    final next = _playlist![nextIndex];

    // Eski ekranın dispose'u portreye çevirmesin
    _navigatingToEpisode = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
          contentId: next.id,
          historyId: _historyId,
          streamUrl: next.streamUrl ?? '',
          contentType: 'series',
          name: next.name,
          streamIcon: widget.streamIcon,
          playlist: _playlist,
          playlistIndex: nextIndex,
          lockLandscape: _isFullScreen,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 150),
      ),
    );
  }

  Future<void> _togglePlayPause() async {
    if (_controller == null) return;

    if (_controller!.value.isEnded ||
        _controller!.value.playingState == PlayingState.ended ||
        _controller!.value.playingState == PlayingState.stopped) {
      try {
        await _controller!.stop();
        await _controller!.play();
        _handledEpisodeEnd = false;
      } catch (e) {
        Log.d('DBG', 'Replay hatası: $e');
        try {
          await _controller!.seekTo(Duration.zero);
          await _controller!.play();
          _handledEpisodeEnd = false;
        } catch (e2) {
          Log.d('DBG', 'Replay alternatif hatası: $e2');
        }
      }
      if (mounted) setState(() {});
      _startHideControlsTimer();
      return;
    }

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _cancelSeekAttempts();
      } else {
        _controller!.play();
      }
    });
    _startHideControlsTimer();
  }

  // Pozisyon ayarlama denemelerini başlat
  void _startSeekAttempts(int position) async {
    if (_seekAttemptsStarted) {
      return; // Zaten başlatılmış
    }

    _seekAttemptsStarted = true;
    _seekAttemptCount = 0;

    // İlk deneme, controller başlatıldıktan hemen sonra
    _performSeekAttempt(position);

    // Sonraki denemeleri zamanla gerçekleştir
    // 1, 2, 4, 8 saniye aralıklarla dene
    for (int i = 1; i <= 4; i++) {
      Future.delayed(Duration(seconds: i * i), () {
        if (_controller != null &&
            mounted &&
            _seekAttemptCount < _maxSeekAttempts) {
          _performSeekAttempt(position);
        }
      });
    }
  }

  void _performSeekAttempt(int position) async {
    _seekAttemptCount++;

    try {
      if (_controller == null || !mounted) {
        Log.d("DBG",
            "Debug - Deneme $_seekAttemptCount: Controller yok veya widget artık mounted değil");
        return;
      }

      // Eğer oynatma henüz başlamamışsa başlat
      if (!_controller!.value.isPlaying && !_controller!.value.isBuffering) {
        Log.d("DBG",
            "Debug - Deneme $_seekAttemptCount: Video oynamıyor, oynatmayı başlatıyorum");
        await _controller!.play();

        // Oynatmayı başlattıktan sonra kısa bir süre bekle ve pozisyonu ayarla
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final currentPos = _controller!.value.position.inSeconds;

      // Eğer zaten istenen pozisyonda veya daha ilerideyse, işlem yapmaya gerek yok
      if (currentPos >= position - 5) {
        Log.d("DBG",
            "Debug - Deneme $_seekAttemptCount: Zaten doğru pozisyona yakın (Şu anki: $currentPos, Hedef: $position)");
        // Seek sonrası VLC ses/altyazıyı sıfırlamış olabilir
        _audioPrefApplied = false;
        _subtitlePrefApplied = false;
        await _syncPreferredTracks(force: true);
        return;
      }
      Log.d("DBG",
          "Debug - Deneme $_seekAttemptCount: Video $position saniyeye ilerletiliyor (Şu anki: $currentPos)");

      // Önce videoyu duraklat
      await _controller!.pause();

      // Pozisyonu ayarla
      await _controller!.seekTo(Duration(seconds: position));

      // Kısa bir beklemeden sonra tekrar oynat
      await Future.delayed(const Duration(milliseconds: 300));
      await _controller!.play();

      // Son pozisyonu kontrol et
      await Future.delayed(const Duration(milliseconds: 700));
      final newPos = _controller!.value.position.inSeconds;
      Log.d("DBG",
          "Debug - Deneme $_seekAttemptCount: Pozisyon ayarlama sonrası: $newPos");

      // Seek audio/subtitle track'i varsayılana döndürebilir
      _audioPrefApplied = false;
      _subtitlePrefApplied = false;
      await _syncPreferredTracks(force: true);
      _startTrackPreferenceWatcher();

      // Eğer pozisyon değişmediyse, farklı bir yöntem dene (agresif yöntem)
      if (newPos < 3 || (newPos - currentPos).abs() < 3) {
        Log.d("DBG",
            "Debug - Deneme $_seekAttemptCount: Pozisyon değişmedi, farklı yöntem deneniyor");
      }
    } catch (e) {
      Log.d("DBG", "Debug - Deneme $_seekAttemptCount sırasında hata: $e");
    }
  }

  void _videoListener() {
    if (!mounted) return;

    final position = _controller?.value.position;
    if (position != null) {
      setState(() {
        _currentPosition = position;
      });
    }
  }

  void _startPositionTimer() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_controller?.value.isPlaying ?? false) {
        _updateWatchPosition();
      }
    });
  }

  Future<void> _loadAudioTracks() async {
    await _syncPreferredTracks(force: true);
  }

  /// Track id'ler bölümden bölüme değişir; etiket/dil anahtar kelimesiyle eşle.
  int? _findBestTrackId(Map<int, String> tracks, String preferred) {
    final pref = preferred.trim().toLowerCase();
    if (pref.isEmpty) return null;

    for (final e in tracks.entries) {
      if (e.value.trim().toLowerCase() == pref) return e.key;
    }
    for (final e in tracks.entries) {
      final name = e.value.toLowerCase();
      if (name.contains(pref) || pref.contains(name)) return e.key;
    }

    final tokens = _languageTokens(pref);
    int? best;
    var bestScore = 0;
    for (final e in tracks.entries) {
      final name = e.value.toLowerCase();
      var score = 0;
      for (final t in tokens) {
        if (name.contains(t)) score += t.length;
      }
      if (score > bestScore) {
        bestScore = score;
        best = e.key;
      }
    }
    return bestScore > 0 ? best : null;
  }

  List<String> _languageTokens(String label) {
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
        l.contains('İng') ||
        l.contains('ingiliz') ||
        l.contains('anglais')) {
      tokens.addAll(['eng', 'english', 'anglaisiliz', 'ingiliz', 'anglais', 'anglaisilizce']);
    }
    if (l.contains('fran') || l.contains('frans') || l.contains('french')) {
      tokens.addAll(['fran', 'french', 'fra', 'fr', 'français']);
    }
    if (l.contains('deu') || l.contains('ger') || l.contains('almanca')) {
      tokens.addAll(['deu', 'ger', 'german', 'almanca', 'deutsch']);
    }
    return tokens.toList();
  }

  Future<void> _setAudioTrack(int id) async {
    if (_controller == null) return;
    await _controller!.setAudioTrack(id);
    setState(() => _currentAudioId = id);
    final label = _audioTracks[id] ?? 'Parça $id';
    _preferredAudioLabel = label;
    _audioPrefApplied = true;
    await _storageService.savePreferredAudioTrack(label);
    Log.d('DBG', 'Audio preference saved: $label');
    _startHideControlsTimer();
  }

  Future<void> _showAudioDialog() async {
    if (_controller != null) {
      await _syncPreferredTracks(force: true);
    }
    if (!mounted) return;
    final items = _audioTracks.isEmpty ? {-1: 'Varsayılan'} : _audioTracks;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ses Parçası Seç'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: items.entries.map((e) {
              final id = e.key;
              final name = e.value;
              return ListTile(
                title: Text(name.isNotEmpty ? name : 'Parça $id'),
                trailing: id == _currentAudioId
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  _setAudioTrack(id);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Video kapanmadan önce son pozisyonu kaydet
    if (_controller != null &&
        _currentPosition.inSeconds > 0 &&
        !_handledEpisodeEnd) {
      _updateWatchPosition();
    }
    _positionUpdateTimer?.cancel();
    _hideControlsTimer?.cancel();
    _trackPrefTimer?.cancel();
    _controller?.dispose();

    _restoreExitOrientations();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) async {
        if (_controller != null) {
          await _controller!.stop();
        }

        _restoreExitOrientations();
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 16),
            Text(
              'Video yükleniyor...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializePlayer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Tekrar Dene'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Geri Dön',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (_controller == null) {
      return const Center(
        child: Text(
          'Video oynatıcı hazırlanamadı',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        // Video Player
        Center(
          child: VlcPlayer(
            controller: _controller!,
            aspectRatio: 16 / 9,
            placeholder: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),

        // Gelişmiş Kontroller
        _buildControls(),

        if (_showNextEpisodeCta && _hasNextEpisode)
          Positioned(
            right: 16,
            bottom: 96,
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: () => _playAdjacentEpisode(1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.skip_next),
                label: const Text('Sonraki Bölüm'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControls() {
    if (!_showControls) {
      return GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.transparent,
        ),
      );
    }

    // Ekran yönlendirmesini al
    final orientation = MediaQuery.of(context).orientation;

    // Sabit değerler
    const double controlPaddingHorizontal = 16;
    const double controlPaddingVertical = 8;
    const double iconSize = 48;
    const double playIconSize = 64;
    const double spacing = 32;

    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black38,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Üst kontrol çubuğu - oryantasyona göre farklı görünümler
            SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: controlPaddingHorizontal,
                    vertical: controlPaddingVertical),
                color: Colors.black54,
                child: orientation == Orientation.portrait
                    ? _buildPortraitTopControls() // Dikey mod
                    : _buildLandscapeTopControls(), // Yatay mod
              ),
            ),

            // Orta alan - İleri/geri sarma + önceki/sonraki bölüm
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasPreviousEpisode) ...[
                      IconButton(
                        iconSize: iconSize,
                        icon: const Icon(Icons.skip_previous,
                            color: Colors.white),
                        onPressed: () => _playAdjacentEpisode(-1),
                        tooltip: 'Önceki Bölüm',
                      ),
                      const SizedBox(width: spacing / 2),
                    ],
                    IconButton(
                      iconSize: iconSize,
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                      onPressed: _seekBackward,
                    ),
                    const SizedBox(width: spacing),
                    IconButton(
                      iconSize: playIconSize,
                      icon: Icon(
                        _controller != null && _controller!.value.isPlaying
                            ? Icons.pause_circle_filled
                            : (_controller != null &&
                                    _controller!.value.isEnded
                                ? Icons.replay_circle_filled
                                : Icons.play_circle_filled),
                        color: Colors.white,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                    const SizedBox(width: spacing),
                    IconButton(
                      iconSize: iconSize,
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                      onPressed: _seekForward,
                    ),
                    if (_hasNextEpisode) ...[
                      const SizedBox(width: spacing / 2),
                      IconButton(
                        iconSize: iconSize,
                        icon:
                            const Icon(Icons.skip_next, color: Colors.white),
                        onPressed: () => _playAdjacentEpisode(1),
                        tooltip: 'Sonraki Bölüm',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Alt kontrol çubuğu - İlerleme çubuğu ve ses kontrolü
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: controlPaddingHorizontal,
                  vertical: controlPaddingVertical),
              color: Colors.black54,
              child: Column(
                children: [
                  // İlerleme çubuğu
                  Row(
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: const TextStyle(color: Colors.white),
                      ),
                      Expanded(
                        child: Slider(
                          value: _currentPosition.inSeconds.toDouble() >= 0 &&
                                  _totalDuration.inSeconds > 0 &&
                                  _currentPosition.inSeconds <=
                                      _totalDuration.inSeconds
                              ? _currentPosition.inSeconds.toDouble()
                              : 0.0,
                          min: 0,
                          max: _totalDuration.inSeconds.toDouble() > 0
                              ? _totalDuration.inSeconds.toDouble()
                              : 1,
                          onChanged: (value) {
                            _controller!
                                .seekTo(Duration(seconds: value.toInt()));
                            _startHideControlsTimer();
                          },
                          onChangeStart: (value) {
                            setState(() {
                              _isDraggingProgress = true;
                            });
                          },
                          onChangeEnd: (value) {
                            setState(() {
                              _isDraggingProgress = false;
                            });
                            _startHideControlsTimer();
                          },
                        ),
                      ),
                      Text(
                        _formatDuration(_totalDuration),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dikey mod için üst kontroller
  Widget _buildPortraitTopControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Geri butonu - sol tarafta
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Video ekranından çıkarken normal ekran modunu geri yükle
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);

            Navigator.pop(context);
          },
        ),

        // İçerik başlığı - ortada
        Expanded(
          child: Text(
            '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // 3-nokta menü butonu - sağda
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: _handleMenuSelection,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'favorite',
              child: Row(
                children: [
                  Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : null,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(_isFavorite ? 'Favorilerden Çıkar' : 'Favorilere Ekle'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'audio',
              child: Row(
                children: [
                  Icon(Icons.volume_up, size: 20),
                  const SizedBox(width: 10),
                  Text('Ses Parçası'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'subtitles',
              child: Row(
                children: [
                  Icon(Icons.subtitles, size: 20),
                  SizedBox(width: 10),
                  Text('Altyazı'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'fullscreen',
              child: Row(
                children: [
                  Icon(
                    _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(_isFullScreen ? 'Tam Ekrandan Çık' : 'Tam Ekran'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Yatay mod için üst kontroller
  Widget _buildLandscapeTopControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Geri butonu - sol tarafta
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Video ekranından çıkarken normal ekran modunu geri yükle
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);

            Navigator.pop(context);
          },
        ),

        // İçerik başlığı - ortada
        Expanded(
          child: Text(
            '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Sağ taraftaki kontrol butonları
        Row(
          children: [
            // Favori butonu
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : Colors.white,
              ),
              onPressed: _toggleFavorite,
            ),
            // Altyazı butonu (dinamik liste)
            IconButton(
              icon: const Icon(Icons.subtitles, color: Colors.white),
              onPressed: _showSubtitlesDialog,
            ),
            // Ses butonu
            IconButton(
              icon: const Icon(Icons.volume_up, color: Colors.white),
              onPressed: _showAudioDialog,
            ),
            // Ekran döndürme kilidi ikonuna geçtik
            IconButton(
              iconSize: 24,
              icon: Icon(
                _isFullScreen
                    ? Icons.screen_lock_rotation
                    : Icons.screen_rotation,
                color: Colors.white,
              ),
              onPressed: () {
                // Döndürme kilidini değiştir ve UI'yı güncelle
                setState(() {
                  _isFullScreen = !_isFullScreen;
                });

                // Ekran yönlendirmesini ayarla
                if (_isFullScreen) {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]);
                } else {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]);
                }

                _startHideControlsTimer();
              },
            ),
          ],
        ),
      ],
    );
  }

  // PopupMenu seçimlerini işle
  void _handleMenuSelection(String value) {
    switch (value) {
      case 'favorite':
        _toggleFavorite();
        break;
      case 'audio':
        _showAudioDialog();
        break;
      case 'subtitles':
        _showSubtitlesDialog();
        break;
      case 'fullscreen':
        setState(() {
          _isFullScreen = !_isFullScreen;
        });

        // Ekran yönlendirmesini ayarla
        if (_isFullScreen) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
        break;
    }
    _startHideControlsTimer();
  }

  // Altyazı seçim diyaloğunu göster
  Future<void> _showSubtitlesDialog() async {
    if (_controller != null) {
      await _syncPreferredTracks(force: true);
    }
    if (!mounted) return;

    final items = {
      -1: 'Kapalı',
      ..._availableSubtitles,
    };
    Log.d("DBG", 'Subtitles dialog: $items current=$_currentSubtitleId pref=$_preferredSubtitleLabel');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Altyazı Seç'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: items.entries.map((entry) {
              final id = entry.key;
              final name = entry.value;
              return ListTile(
                title: Text(name.isNotEmpty ? name : 'Altyazı $id'),
                trailing: id == _currentSubtitleId
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  _setSubtitle(id);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}
