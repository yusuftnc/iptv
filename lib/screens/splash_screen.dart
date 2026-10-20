import 'package:flutter/material.dart';
import '../models/saved_playlist.dart';
import '../services/cloud_sync_service.dart';
import '../services/iptv_service.dart';
import '../services/m3u_parser.dart';
import '../services/playlist_content.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';
import 'm3u_list_screen.dart';
import 'player_screen.dart';
import 'source_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }
  
  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final storage = StorageService();
    SavedPlaylist? active;
    try {
      final playlists = await storage.getPlaylists();
      final activeId = await storage.getActivePlaylistId();
      for (final playlist in playlists) {
        if (playlist.id == activeId) {
          active = playlist;
          break;
        }
      }
    } catch (_) {
      active = null;
    }
    if (!mounted) return;

    if (active != null && active.isXtream) {
      final opened = await _openXtream(active);
      if (!mounted) return;
      if (opened) return;
    } else if (active != null) {
      final opened = await _openM3u(active);
      if (!mounted) return;
      if (opened) return;
    }

    _go(const SourceScreen());
  }

  Future<bool> _openXtream(SavedPlaylist playlist) async {
    final iptv = IptvService();
    await iptv.initialize(
      host: playlist.host,
      port: playlist.port,
      username: playlist.username,
      password: playlist.password,
    );
    final ok = await iptv.login();
    if (!ok || !mounted) return false;
    await CloudSyncService.instance.start(
      host: playlist.host,
      port: playlist.port,
      username: playlist.username,
      password: playlist.password,
    );
    if (!mounted) return false;
    _go(const HomeScreen());
    return true;
  }

  Future<bool> _openM3u(SavedPlaylist playlist) async {
    try {
      final parsed = await PlaylistContent.load(playlist);
      if (!mounted || !parsed.isValid) return false;
      if (parsed.isHls) {
        final uri = playlist.m3uPath.isNotEmpty
            ? Uri.file(playlist.m3uPath).toString()
            : playlist.m3uUrl;
        _go(PlayerScreen(
          contentId: playlist.id,
          streamUrl: uri,
          contentType: 'live',
          name: playlist.name,
          historyId: playlist.id,
        ));
        return true;
      }
      _go(M3uListScreen(
        title: playlist.name,
        entries: parsed.entries,
        backToSources: true,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  void _go(Widget page) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 100),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.tv,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'SUTU Player',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
