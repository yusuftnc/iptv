import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../models/content_item.dart';
import '../services/iptv_service.dart';

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

  @override
  void dispose() {
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
        
        // Kontroller
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.black54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller!.value.isPlaying
                          ? _controller!.pause()
                          : _controller!.play();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.fullscreen_exit,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
        
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
} 