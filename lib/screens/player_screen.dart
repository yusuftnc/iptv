import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../models/content_item.dart';
import '../services/iptv_service.dart';
import 'dart:async';
import 'dart:math' show max;

class PlayerScreen extends StatefulWidget {
  final ContentItem contentItem;

  const PlayerScreen({
    super.key,
    required this.contentItem,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VlcPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final IptvService _iptvService = IptvService();

  // Kontrol paneli için değişkenler
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _positionUpdateTimer;
  bool _isDraggingProgress = false;
  double _currentVolume = 100;
  bool _isMuted = false;
  List<String> _availableSubtitles = [];
  String? _currentSubtitle;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    // Tam ekran modu
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Kontrolleri otomatik gizlemek için timer başlat
    _startHideControlsTimer();
    
    // Pozisyon güncellemesi için timer başlat
    _startPositionUpdateTimer();
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
      
      if (widget.contentItem.streamUrl != null && widget.contentItem.streamUrl!.isNotEmpty) {
        // Eğer ContentItem'da zaten bir URL varsa, onu kullan
        streamUrl = widget.contentItem.streamUrl;
        print('Debug - ContentItem\'dan URL kullanılıyor: $streamUrl');
      } else {
        // Yoksa, servis üzerinden URL'i al
        final streamType = widget.contentItem.streamType ?? 'live';
        
        // Eğer dizi bölümü ise, özel işlem yap
        if (streamType == 'series' && widget.contentItem.id.isNotEmpty) {
          // Dizi bölüm ID'sini kullanarak stream URL'ini al
          streamUrl = await _iptvService.getStreamUrl(
            streamId: widget.contentItem.id,
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
                '$serverUrl/series/$username/$password/${widget.contentItem.id}.mp4',
                '$serverUrl/series/$username/$password/${widget.contentItem.id}.mkv',
                '$serverUrl/series/$username/$password/${widget.contentItem.id}.ts',
                '$serverUrl/series/$username/$password/${widget.contentItem.id}.m3u8',
                '$serverUrl/series/$username/$password/series/${widget.contentItem.id}.mp4',
                '$serverUrl/series/$username/$password/series/${widget.contentItem.id}.mkv',
                '$serverUrl/series/$username/$password/series/${widget.contentItem.id}.ts',
                '$serverUrl/series/$username/$password/series/${widget.contentItem.id}.m3u8',
              ];
              
              // İlk formatı kullan (daha sonra diğerlerini deneyebiliriz)
              streamUrl = formats.first;
              print('Debug - Alternatif URL kullanılıyor: $streamUrl');
            }
          }
        } else {
          // Normal içerik için stream URL'ini al
          streamUrl = await _iptvService.getStreamUrl(
            streamId: widget.contentItem.id,
            streamType: streamType,
          );
        }
        
        print('Debug - Servis üzerinden URL alındı: $streamUrl');
      }
      
      print('Debug - Stream URL: $streamUrl');
      print('Debug - Content Type: ${widget.contentItem.streamType}');
      print('Debug - Content ID: ${widget.contentItem.id}');

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('Stream URL bulunamadı');
      }

      // Önceki controller'ı temizle
      await _controller?.dispose();
      
      // Yeni controller oluştur
      _controller = VlcPlayerController.network(
        streamUrl,
        autoPlay: true,
        options: VlcPlayerOptions(
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
        ),
      );

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      print('Debug - Hata oluştu: $e');
      print('Debug - Hata türü: ${e.runtimeType}');
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
      _startHideControlsTimer();
    }
  }
  
  void _seekBackward() {
    if (_controller != null) {
      final currentPos = _controller!.value.position.inSeconds;
      _controller!.seekTo(Duration(seconds: max(0, currentPos - 10)));
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
  
  void _loadSubtitles() async {
    try {
      // VLC Player'ın altyazı API'sini kullanarak mevcut altyazıları yükle
      if (_controller != null) {
        // Not: Bu kısım VLC Player'ın API'sine bağlı olarak değişebilir
        // Şu anda flutter_vlc_player paketi doğrudan altyazı listesi almayı desteklemiyor
        // Bu nedenle bu kısım şimdilik simüle edilmiştir
        
        // Gerçek uygulamada, altyazıları sunucudan veya video dosyasından yüklemeniz gerekebilir
        setState(() {
          _availableSubtitles = ['Türkçe', 'İngilizce', 'Kapalı'];
          _currentSubtitle = 'Kapalı';
        });
      }
    } catch (e) {
      print('Altyazılar yüklenirken hata: $e');
    }
  }
  
  void _setSubtitle(String? subtitle) {
    if (_controller != null) {
      setState(() {
        _currentSubtitle = subtitle;
        // VLC Player'ın altyazı API'sini kullanarak altyazıyı ayarla
        // Not: Bu kısım VLC Player'ın API'sine bağlı olarak değişebilir
        if (subtitle == 'Kapalı') {
          // Altyazıyı kapat
          // _controller!.setSpuTrack(-1);
        } else if (subtitle == 'Türkçe') {
          // Türkçe altyazıyı seç
          // _controller!.setSpuTrack(0);
        } else if (subtitle == 'İngilizce') {
          // İngilizce altyazıyı seç
          // _controller!.setSpuTrack(1);
        }
      });
      _startHideControlsTimer();
    }
  }

  void _startPositionUpdateTimer() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_controller != null && mounted) {
        final position = _controller!.value.position;
        final duration = _controller!.value.duration;
        
        // Pozisyon ve süre değerlerinin geçerli olduğundan emin ol
        if (position.inMilliseconds >= 0 && duration.inMilliseconds > 0) {
          setState(() {
            _currentPosition = position;
            _totalDuration = duration;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _positionUpdateTimer?.cancel();
    _controller?.dispose();
    // Normal ekran moduna dön
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) async {
        if (_controller != null) {
          await _controller!.stop();
        }
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
        
        // İçerik adı
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.contentItem.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
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
    
    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black38,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Üst kontrol çubuğu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      // Altyazı butonu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.subtitles, color: Colors.white),
                        onSelected: _setSubtitle,
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'Kapalı',
                            child: Text('Kapalı'),
                          ),
                          const PopupMenuItem(
                            value: 'Türkçe',
                            child: Text('Türkçe'),
                          ),
                          const PopupMenuItem(
                            value: 'İngilizce',
                            child: Text('İngilizce'),
                          ),
                        ],
                      ),
                      // Ses butonu
                      IconButton(
                        icon: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                        ),
                        onPressed: _toggleMute,
                      ),
                      // Tam ekran butonu
                      IconButton(
                        icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Orta alan - İleri/geri sarma butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 48,
                  icon: const Icon(Icons.replay_10, color: Colors.white),
                  onPressed: _seekBackward,
                ),
                const SizedBox(width: 32),
                IconButton(
                  iconSize: 64,
                  icon: Icon(
                    _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (_controller!.value.isPlaying) {
                      _controller!.pause();
                    } else {
                      _controller!.play();
                    }
                    // Force UI update immediately after changing playback state
                    setState(() {});
                    _startHideControlsTimer();
                  },
                ),
                const SizedBox(width: 32),
                IconButton(
                  iconSize: 48,
                  icon: const Icon(Icons.forward_10, color: Colors.white),
                  onPressed: _seekForward,
                ),
              ],
            ),
            
            // Alt kontrol çubuğu - İlerleme çubuğu ve ses kontrolü
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                 _currentPosition.inSeconds <= _totalDuration.inSeconds
                              ? _currentPosition.inSeconds.toDouble()
                              : 0.0,
                          min: 0,
                          max: _totalDuration.inSeconds.toDouble() > 0 ? _totalDuration.inSeconds.toDouble() : 1,
                          onChanged: (value) {
                            _controller!.seekTo(Duration(seconds: value.toInt()));
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