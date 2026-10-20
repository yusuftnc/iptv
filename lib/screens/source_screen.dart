import 'package:flutter/material.dart';

import '../models/saved_playlist.dart';
import '../services/cloud_sync_service.dart';
import '../services/iptv_service.dart';
import '../services/m3u_parser.dart';
import '../services/playlist_content.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'm3u_add_screen.dart';
import 'm3u_list_screen.dart';
import 'player_screen.dart';
import 'single_stream_screen.dart';

class SourceScreen extends StatefulWidget {
  const SourceScreen({super.key});

  @override
  State<SourceScreen> createState() => _SourceScreenState();
}

class _SourceScreenState extends State<SourceScreen> {
  final StorageService _storage = StorageService();
  List<SavedPlaylist> _playlists = [];
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final playlists = await _storage.getPlaylists();
      if (!mounted) return;
      setState(() => _playlists = playlists);
    } catch (_) {
      if (!mounted) return;
      setState(() => _playlists = []);
    }
  }

  Future<void> _open(SavedPlaylist playlist) async {
    if (_openingId != null) return;
    setState(() => _openingId = playlist.id);
    try {
      if (playlist.isXtream) {
        await _openXtream(playlist);
      } else {
        await _openM3u(playlist);
      }
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  Future<void> _openXtream(SavedPlaylist playlist) async {
    final iptv = IptvService();
    await iptv.initialize(
      host: playlist.host,
      port: playlist.port,
      username: playlist.username,
      password: playlist.password,
    );
    final ok = await iptv.login();
    if (!mounted) return;
    if (!ok) {
      _showMessage('Giriş başarısız. Playlist kaydı duruyor.');
      return;
    }
    await _storage.setActivePlaylistId(playlist.id);
    await CloudSyncService.instance.start(
      host: playlist.host,
      port: playlist.port,
      username: playlist.username,
      password: playlist.password,
    );
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  Future<void> _openM3u(SavedPlaylist playlist) async {
    final M3uParseResult parsed;
    try {
      parsed = await PlaylistContent.load(playlist);
    } catch (_) {
      if (!mounted) return;
      _showMessage(playlist.isRemoteM3u ? 'Liste alınamadı.' : 'Dosya açılamadı.');
      return;
    }
    if (!mounted) return;
    if (!parsed.isValid) {
      _showMessage('Geçersiz liste.');
      return;
    }
    await _storage.setActivePlaylistId(playlist.id);
    if (!mounted) return;

    if (parsed.isHls) {
      final uri = playlist.m3uPath.isNotEmpty
          ? Uri.file(playlist.m3uPath).toString()
          : playlist.m3uUrl;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            contentId: playlist.id,
            streamUrl: uri,
            contentType: 'live',
            name: playlist.name,
            historyId: playlist.id,
          ),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => M3uListScreen(
          title: playlist.name,
          entries: parsed.entries,
        ),
      ),
    );
  }

  Future<void> _delete(SavedPlaylist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playlist silinsin mi?'),
        content: Text(playlist.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true) return;
    await PlaylistContent.deleteLocalFile(playlist);
    await _storage.deletePlaylist(playlist.id);
    await _loadPlaylists();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.tv, color: Colors.blue, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Kaynak seç',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              if (_playlists.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    itemCount: _playlists.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final playlist = _playlists[index];
                      final opening = _openingId == playlist.id;
                      return Material(
                        color: Colors.grey[900],
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        child: ListTile(
                          leading: opening
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  playlist.isXtream ? Icons.dns_outlined : Icons.playlist_play,
                                  color: Colors.blue,
                                ),
                          title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            playlist.isXtream ? 'Xtream' : 'M3U',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: IconButton(
                            tooltip: 'Sil',
                            onPressed: opening ? null : () => _delete(playlist),
                            icon: const Icon(Icons.delete_outline, color: Colors.white54),
                          ),
                          onTap: opening ? null : () => _open(playlist),
                        ),
                      );
                    },
                  ),
                )
              else
                const SizedBox(height: 8),
              _SourceCard(
                icon: Icons.dns_outlined,
                label: 'XTREAM',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                  await _loadPlaylists();
                },
              ),
              const SizedBox(height: 14),
              _SourceCard(
                icon: Icons.play_circle_outline,
                label: 'TEK YAYIN',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SingleStreamScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),
              _SourceCard(
                icon: Icons.playlist_play,
                label: 'M3U',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const M3uAddScreen()),
                  );
                  await _loadPlaylists();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SourceCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[900],
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: SizedBox(
          height: 92,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: Colors.blue),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
