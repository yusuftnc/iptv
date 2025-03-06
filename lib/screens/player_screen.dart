import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VlcPlayerController _controller;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    
    try {
      _controller = VlcPlayerController.network(
        widget.streamUrl,
        hwAcc: HwAcc.full,
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
      
      // Hata dinleyicisi ekle - VLC player'ın desteklediği bir yöntem kullanıyoruz
      _controller.addOnInitListener(() {
        print('VLC player initialized successfully');
      });
      
      // VLC player'da addOnErrorListener metodu yok, bu yüzden try-catch kullanıyoruz
    } catch (e) {
      print('VLC player initialization error: $e');
      // Hata durumunda kullanıcıya bilgi ver ve geri dön
      Future.microtask(() {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Video oynatıcı başlatılamadı: $e')),
          );
          Navigator.pop(context);
        }
      });
      return;
    }

    // Tam ekran moduna geç
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    try {
      if (_controller != null) {
        _controller.dispose();
      }
    } catch (e) {
      print('VLC player dispose error: $e');
    }
    
    // Normal ekran moduna dön
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Player
            Center(
              child: Builder(
                builder: (context) {
                  try {
                    return VlcPlayer(
                      controller: _controller,
                      aspectRatio: 16 / 9,
                      placeholder: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  } catch (e) {
                    print('VLC player build error: $e');
                    // Hata durumunda basit bir hata mesajı göster
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 50, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Video oynatılamıyor: $e',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Geri Dön'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
            
            // Kontroller
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: Colors.black54,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                          _isPlaying = !_isPlaying;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.stop,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        _controller.stop();
                        Navigator.pop(context);
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.fullscreen_exit,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            // Başlık
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                color: Colors.black54,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 