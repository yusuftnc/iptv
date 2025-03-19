import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../models/content_item.dart';
import '../services/iptv_service.dart';
import '../services/database_service.dart';
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
  final DatabaseService _databaseService = DatabaseService();
  bool _isFavorite = false;

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

  // Tam ekran değişkenini ekle
  bool _isFullScreen = false;

  // Pozisyon ayarlama denemelerini başlat
  bool _seekAttemptsStarted = false;
  int? _initialSeekPosition;
  bool _shouldSeekToInitialPosition = false;
  int _seekAttemptCount = 0;
  final int _maxSeekAttempts = 5;

  @override
  void initState() {
    super.initState();
    
    // Tam ekran modu ayarla
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Video oynatıcıyı başlat
    _initializePlayer();
    
    // Favorilerde olup olmadığını kontrol et
    _checkIfFavorite();
    
    // Kontrolleri göster
    _startHideControlsTimer();
  }

  Future<void> _checkIfFavorite() async {
    final isFavorite = await _databaseService.isFavorite(widget.contentItem.id);
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await _databaseService.removeFavorite(widget.contentItem.id);
    } else {
      await _databaseService.addFavorite(widget.contentItem);
    }
    
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  Future<void> _addToWatchHistory() async {
    try {
      print("Debug - İlk izleme pozisyonu kontrolü başlatılıyor: ${widget.contentItem.id}");
      print("Debug - İzleme geçmişine ekleniyor: ${widget.contentItem.id}");
      
      // İlk olarak izleme geçmişine ekle (pozisyon olmadan)
      await _databaseService.addToWatchHistory(widget.contentItem);
      
      // Kaydedilmiş pozisyonu kontrol et
      final watchHistory = await _databaseService.getWatchPosition(widget.contentItem.id);
      print("Debug - İlk kontrol - Bulunan izleme geçmişi: ${watchHistory?.position} / ${watchHistory?.duration}");
      
      print("Debug - İzleme geçmişine eklendi");
      
    } catch (e) {
      print("Debug - İzleme geçmişine eklenirken hata: $e");
    }
  }

  Future<void> _updateWatchPosition() async {
    try {
      if (_controller != null && _currentPosition.inSeconds > 0) {
        print("Debug - İzleme pozisyonu güncelleniyor: ${_currentPosition.inSeconds} / ${_totalDuration.inSeconds}");
        print("Debug - ContentItem ID: ${widget.contentItem.id}");
        
        await _databaseService.addToWatchHistory(
          widget.contentItem,
          position: _currentPosition.inSeconds,
          duration: _totalDuration.inSeconds,
        );
        
        // Veritabanına kaydedilen pozisyonu doğrula
        final savedPosition = await _databaseService.getWatchPosition(widget.contentItem.id);
        print("Debug - Kaydedilen pozisyon kontrolü: ${savedPosition?.position} / ${savedPosition?.duration}");
        
        print("Debug - İzleme pozisyonu güncellendi");
      } else {
        print("Debug - İzleme pozisyonu güncellenemiyor: ${_controller != null ? 'Controller var' : 'Controller yok'}, Pozisyon: ${_currentPosition.inSeconds}");
      }
    } catch (e) {
      print("Debug - İzleme pozisyonu güncellenirken hata: $e");
      print("Debug - Hata türü: ${e.runtimeType}");
    }
  }

  Future<void> _checkWatchPosition() async {
    try {
      print("Debug - İzleme pozisyonu kontrol ediliyor: ${widget.contentItem.id}");
      final watchHistory = await _databaseService.getWatchPosition(widget.contentItem.id);
      
      print("Debug - Alınan izleme geçmişi: ${watchHistory?.position} / ${watchHistory?.duration}");
      print("Debug - İzleme geçmişi contentId: ${watchHistory?.contentId}");
      print("Debug - Current contentItem id: ${widget.contentItem.id}");
      
      if (watchHistory != null && 
          watchHistory.position != null && 
          watchHistory.position! > 10 &&
          watchHistory.duration != null && 
          watchHistory.position! < (watchHistory.duration! - 30)) {
        
        print("Debug - İzleme pozisyonu bulundu, diyalog gösteriliyor");
        
        if (mounted) {
          final result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Kaldığınız Yerden Devam Et'),
              content: Text(
                'Bu içeriği daha önce ${_formatDuration(Duration(seconds: watchHistory.position!))} kadar izlediniz. Kaldığınız yerden devam etmek istiyor musunuz?'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Hayır, Baştan Başla'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Evet, Devam Et'),
                ),
              ],
            ),
          );
          
          print("Debug - Kullanıcı tercihi: $result");
          
          if (result == true && _controller != null) {
            print("Debug - Video ${watchHistory.position!} saniyeye ilerletiliyor");
            
            // Birden fazla kez seekTo dene (controller'ın tamamen hazır olması için)
            try {
              await _controller!.seekTo(Duration(seconds: watchHistory.position!));
              
              // Kontrol etmek için 1 saniye sonra tekrar dene
              Future.delayed(const Duration(seconds: 1), () async {
                if (_controller != null && mounted) {
                  final currentPos = _controller!.value.position.inSeconds;
                  print("Debug - İlerleme sonrası pozisyon kontrolü: $currentPos");
                  
                  // Eğer pozisyon hala başlangıçtaysa tekrar dene
                  if (currentPos < 3) {
                    print("Debug - Pozisyon doğru ayarlanmamış, tekrar deneniyor");
                    await _controller!.seekTo(Duration(seconds: watchHistory.position!));
                  }
                }
              });
            } catch (e) {
              print("Debug - seekTo sırasında hata: $e");
              
              // Diğer yöntemi dene
              Future.delayed(const Duration(seconds: 2), () async {
                if (_controller != null && mounted) {
                  try {
                    print("Debug - Alternatif yöntemle ilerleme deneniyor");
                    await _controller!.seekTo(Duration(seconds: watchHistory.position!));
                  } catch (e) {
                    print("Debug - Alternatif ilerleme sırasında hata: $e");
                  }
                }
              });
            }
            
            print("Debug - Video pozisyon ayarlaması tamamlandı");
          }
        }
      } else {
        print("Debug - Devam etmek için uygun pozisyon bulunamadı veya izleme geçmişi yok");
        if (watchHistory == null) {
          print("Debug - İzleme geçmişi bulunamadı");
        } else if (watchHistory.position == null) {
          print("Debug - İzleme pozisyonu null");
        } else if (watchHistory.position! <= 10) {
          print("Debug - İzleme pozisyonu çok kısa: ${watchHistory.position}");
        } else if (watchHistory.duration == null) {
          print("Debug - Video süresi null");
        } else if (watchHistory.position! >= (watchHistory.duration! - 30)) {
          print("Debug - İzleme pozisyonu videonun sonuna çok yakın: ${watchHistory.position} / ${watchHistory.duration}");
        }
      }
    } catch (e) {
      print('Debug - İzleme pozisyonu kontrol edilirken hata: $e');
      print('Debug - Hata türü: ${e.runtimeType}');
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

      // İlk önce izleme pozisyonunu al
      print("Debug - Video yüklenmeden önce izleme pozisyonu kontrol ediliyor.");
      final watchHistory = await _databaseService.getWatchPosition(widget.contentItem.id);
      print("Debug - İzleme geçmişi: ${watchHistory?.position} / ${watchHistory?.duration}");
      
      // İzleme pozisyonu uygun mu kontrol et
      bool shouldResume = false;
      int? resumePosition;
      
      if (watchHistory != null && 
          watchHistory.position != null && 
          watchHistory.position! > 10 &&
          watchHistory.duration != null && 
          watchHistory.position! < (watchHistory.duration! - 30)) {
        shouldResume = true;
        resumePosition = watchHistory.position;
        print("Debug - Video ${resumePosition} saniyeden devam edecek");
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
      
      print("Debug - VLC Player controller oluşturuluyor");
      
      // Controller'ı eğer izleme pozisyonu varsa ve bu bir film/diziyse (live değilse)
      // autoPlay:false ile başlat, böylece ilk frame'de pozisyona atlaması daha kolay olur
      final isLiveContent = widget.contentItem.streamType == 'live';
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
        print("Debug - Video controller initialize oldu");
        
        if (!shouldAutoPlay) {
          // Eğer autoPlay false ise, video durmuş halde. 
          // Pozisyonu ayarladıktan sonra oynatmaya başlayacağız
          print("Debug - Pozisyon ayarlanana kadar video duraklatıldı");
        }
        
        // İzleme pozisyonuna gitmeyi daha sonra deneyelim,
        // controller tam olarak hazır olduğunda
        if (_shouldSeekToInitialPosition && _initialSeekPosition != null) {
          print("Debug - Controller hazır, pozisyon ayarlamayı deneyeceğiz");
          _startSeekAttempts(_initialSeekPosition!);
        }
      });

      // Video durumunu dinlemek için listener ekleniyor
      _controller!.addListener(() {
        if (_controller!.value.isInitialized && 
            _controller!.value.isPlaying && 
            _controller!.value.position.inSeconds > 0 &&
            _shouldSeekToInitialPosition && 
            _initialSeekPosition != null) {
          
          // Video oynamaya başladığında ve henüz pozisyon ayarlanmadıysa
          // pozisyonu ayarlamayı deneyelim
          if (!_seekAttemptsStarted) {
            print("Debug - Video oynamaya başladı, pozisyon ayarlamayı deneyeceğiz");
            _startSeekAttempts(_initialSeekPosition!);
          }
        }
      });

      setState(() {
        _isLoading = false;
      });

      // İzleme geçmişine ekle (başlangıç kaydı)
      _addToWatchHistory();

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
          
          // Her 15 saniyede bir izleme pozisyonunu veritabanına kaydet (daha sık kaydet)
          if (position.inSeconds % 15 == 0 && position.inSeconds > 0) {
            _updateWatchPosition();
          }
        }
      }
    });
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
        if (_controller != null && mounted && _seekAttemptCount < _maxSeekAttempts) {
          _performSeekAttempt(position);
        }
      });
    }
  }
  
  void _performSeekAttempt(int position) async {
    _seekAttemptCount++;
    
    try {
      if (_controller == null || !mounted) {
        print("Debug - Deneme $_seekAttemptCount: Controller yok veya widget artık mounted değil");
        return;
      }
      
      // Eğer oynatma henüz başlamamışsa başlat
      if (!_controller!.value.isPlaying && !_controller!.value.isBuffering) {
        print("Debug - Deneme $_seekAttemptCount: Video oynamıyor, oynatmayı başlatıyorum");
        await _controller!.play();
        
        // Oynatmayı başlattıktan sonra kısa bir süre bekle ve pozisyonu ayarla
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      final currentPos = _controller!.value.position.inSeconds;
      
      // Eğer zaten istenen pozisyonda veya daha ilerideyse, işlem yapmaya gerek yok
      if (currentPos >= position - 5) {
        print("Debug - Deneme $_seekAttemptCount: Zaten doğru pozisyona yakın (Şu anki: $currentPos, Hedef: $position)");
        return;
      }
      
      print("Debug - Deneme $_seekAttemptCount: Video $position saniyeye ilerletiliyor (Şu anki: $currentPos)");
      
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
      print("Debug - Deneme $_seekAttemptCount: Pozisyon ayarlama sonrası: $newPos");
      
      // Eğer pozisyon değişmediyse, farklı bir yöntem dene (agresif yöntem)
      if (newPos < 3 || (newPos - currentPos).abs() < 3) {
        print("Debug - Deneme $_seekAttemptCount: Pozisyon değişmedi, farklı yöntem deneniyor");
        
        // MediaPlayer'ı doğrudan al ve time ayarla (VLC Player native API)
        // Not: Bu yöntem Flutter VLC Player paketine bağlı olarak değişebilir
        // await _controller!.setTime(position * 1000); // milisaniye cinsinden
      }
    } catch (e) {
      print("Debug - Deneme $_seekAttemptCount sırasında hata: $e");
    }
  }

  @override
  void dispose() {
    // Video kapanırken izleme pozisyonunu kaydet
    if (_controller != null && _currentPosition.inSeconds > 0) {
      print("Debug - Ekran kapanırken son izleme pozisyonu kaydediliyor: ${_currentPosition.inSeconds}");
      // Senkron olarak çalıştırmak için hemen güncelle
      try {
        _databaseService.addToWatchHistory(
          widget.contentItem,
          position: _currentPosition.inSeconds,
          duration: _totalDuration.inSeconds,
        );
        print("Debug - Son izleme pozisyonu kaydedildi: ${_currentPosition.inSeconds} / ${_totalDuration.inSeconds}");
      } catch (e) {
        print("Debug - Son izleme pozisyonu kaydedilirken hata: $e");
      }
    }
    
    // Timer'ları iptal et
    _hideControlsTimer?.cancel();
    _positionUpdateTimer?.cancel();
    
    // Kontrolcüyü temizle
    _controller?.stop();
    _controller?.dispose();
    
    // Uygulama kapanınca normal moda dönüş
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
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
        
        // Video ekranından çıkarken normal ekran modunu geri yükle
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
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
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: controlPaddingHorizontal, 
                vertical: controlPaddingVertical
              ),
              color: Colors.black54,
              child: orientation == Orientation.portrait
                  ? _buildPortraitTopControls() // Dikey mod
                  : _buildLandscapeTopControls(), // Yatay mod
            ),
            
            // Orta alan - İleri/geri sarma butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                        : Icons.play_circle_filled,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (_controller == null) return;
                    
                    setState(() {
                      if (_controller!.value.isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                    });
                    
                    _startHideControlsTimer();
                  },
                ),
                const SizedBox(width: spacing),
                IconButton(
                  iconSize: iconSize,
                  icon: const Icon(Icons.forward_10, color: Colors.white),
                  onPressed: _seekForward,
                ),
              ],
            ),
            
            // Alt kontrol çubuğu - İlerleme çubuğu ve ses kontrolü
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: controlPaddingHorizontal, 
                vertical: controlPaddingVertical
              ),
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
            widget.contentItem.name,
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
              value: 'mute',
              child: Row(
                children: [
                  Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(_isMuted ? 'Sesi Aç' : 'Sesi Kapat'),
                ],
              ),
            ),
            const PopupMenuItem(
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
            widget.contentItem.name,
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
            // Altyazı butonu
            PopupMenuButton<String>(
              icon: const Icon(Icons.subtitles, color: Colors.white),
              onSelected: _setSubtitle,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'Kapalı',
                  child: Text('Kapalı'),
                ),
                PopupMenuItem(
                  value: 'Türkçe',
                  child: Text('Türkçe'),
                ),
                PopupMenuItem(
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
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: () {
                // Tam ekran durumunu değiştir ve UI'yı güncelle
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
      case 'mute':
        _toggleMute();
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
  void _showSubtitlesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Altyazı Seç'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Kapalı'),
              onTap: () {
                _setSubtitle('Kapalı');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Türkçe'),
              onTap: () {
                _setSubtitle('Türkçe');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('İngilizce'),
              onTap: () {
                _setSubtitle('İngilizce');
                Navigator.pop(context);
              },
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