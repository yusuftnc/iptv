import 'package:flutter/material.dart';

import '../models/saved_playlist.dart';
import '../services/app_settings.dart';
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
      _showMessage(AppText.get('loginFailed'));
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
      _showMessage(AppText.get(playlist.isRemoteM3u ? 'listFailed' : 'fileFailed'));
      return;
    }
    if (!mounted) return;
    if (!parsed.isValid) {
      _showMessage(AppText.get('invalidList'));
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
        title: Text(AppText.get('deletePlaylistTitle')),
        content: Text(playlist.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppText.get('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(AppText.get('delete'))),
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

  Future<void> _openAdd(Widget page, {bool reload = false}) async {
    dismissKeyboard();
    await Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    if (!mounted) return;
    dismissKeyboard();
    if (reload) await _loadPlaylists();
  }

  Future<void> _showAddSheet() async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.accent;
    final cardColor = dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final titleColor = dark ? Colors.white : Colors.black87;
    final sheetColor = dark ? Colors.black : Colors.white;
    dismissKeyboard();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(sheetContext).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: dark ? Colors.white24 : Colors.black26,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              _addCards(
                cardColor: cardColor,
                titleColor: titleColor,
                accent: accent,
                beforeNavigate: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _addCards({
    required Color cardColor,
    required Color titleColor,
    required Color accent,
    VoidCallback? beforeNavigate,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SourceCard(
          color: cardColor,
          labelColor: titleColor,
          iconColor: accent,
          icon: Icons.dns_outlined,
          label: 'XTREAM',
          onTap: () {
            beforeNavigate?.call();
            _openAdd(const LoginScreen(), reload: true);
          },
        ),
        const SizedBox(height: 14),
        _SourceCard(
          color: cardColor,
          labelColor: titleColor,
          iconColor: accent,
          icon: Icons.play_circle_outline,
          label: AppText.get('singleStream'),
          onTap: () {
            beforeNavigate?.call();
            _openAdd(const SingleStreamScreen());
          },
        ),
        const SizedBox(height: 14),
        _SourceCard(
          color: cardColor,
          labelColor: titleColor,
          iconColor: accent,
          icon: Icons.featured_play_list_outlined,
          customIcon: _M3uMark(color: accent),
          label: 'M3U',
          onTap: () {
            beforeNavigate?.call();
            _openAdd(const M3uAddScreen(), reload: true);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.accent;
    final background = dark ? Colors.black : Colors.white;
    final titleColor = dark ? Colors.white : Colors.black87;
    final cardColor = dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final muted = dark ? Colors.white54 : Colors.black45;

    final hasPlaylists = _playlists.isNotEmpty;
    return Scaffold(
      backgroundColor: background,
      floatingActionButton: hasPlaylists
          ? FloatingActionButton(
              onPressed: _showAddSheet,
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _RoundControl(
                    color: cardColor,
                    child: IconButton(
                      onPressed: () => AppSettings.instance.setDarkMode(!dark),
                      icon: Icon(
                        dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                        color: accent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _RoundControl(
                    color: cardColor,
                    padding: const EdgeInsets.only(left: 22, right: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: AppSettings.instance.language,
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
                        dropdownColor: cardColor,
                        icon: Icon(Icons.expand_more, color: muted),
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'tr', child: Text('TR')),
                          DropdownMenuItem(value: 'en', child: Text('EN')),
                        ],
                        onChanged: (value) {
                          if (value != null) AppSettings.instance.setLanguage(value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  children: [
                    if (!hasPlaylists) const Spacer(flex: 3),
                    Icon(Icons.tv, color: accent, size: hasPlaylists ? 48 : 72),
                    const SizedBox(height: 16),
                    Text(
                      AppText.get('sourceTitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (hasPlaylists) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            AppText.get('saved'),
                            style: TextStyle(
                              color: muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: _playlists.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final playlist = _playlists[index];
                            final opening = _openingId == playlist.id;
                            return Material(
                              color: cardColor,
                              borderRadius: const BorderRadius.all(Radius.circular(18)),
                              child: InkWell(
                                onTap: opening ? null : () => _open(playlist),
                                borderRadius: const BorderRadius.all(Radius.circular(18)),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: Center(
                                          child: opening
                                              ? SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: accent,
                                                  ),
                                                )
                                              : playlist.isXtream
                                                  ? Icon(Icons.dns_outlined, color: accent, size: 26)
                                                  : _M3uMark(color: accent, size: 26),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              playlist.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: titleColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              playlist.isXtream ? 'Xtream' : 'M3U',
                                              style: TextStyle(color: muted, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: AppText.get('delete'),
                                        onPressed: opening ? null : () => _delete(playlist),
                                        icon: Icon(Icons.delete_outline, color: muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (!hasPlaylists) ...[
                      _addCards(
                        cardColor: cardColor,
                        titleColor: titleColor,
                        accent: accent,
                      ),
                      const Spacer(flex: 2),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  final Color color;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  const _RoundControl({
    required this.color,
    required this.child,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _M3uMark extends StatelessWidget {
  final Color color;
  final double size;

  const _M3uMark({required this.color, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _M3uMarkPainter(color)),
    );
  }
}

class _M3uMarkPainter extends CustomPainter {
  final Color color;

  const _M3uMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.06,
        size.height * 0.14,
        size.width * 0.7,
        size.height * 0.72,
      ),
      Radius.circular(size.width * 0.12),
    );
    canvas.drawRRect(card, stroke);

    final lineLeft = size.width * 0.2;
    final lineRight = size.width * 0.48;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.34 + i * 0.16);
      canvas.drawLine(Offset(lineLeft, y), Offset(lineRight, y), stroke);
    }

    final play = Path()
      ..moveTo(size.width * 0.64, size.height * 0.34)
      ..lineTo(size.width * 0.64, size.height * 0.66)
      ..lineTo(size.width * 0.9, size.height * 0.5)
      ..close();
    canvas.drawPath(play, fill);
  }

  @override
  bool shouldRepaint(covariant _M3uMarkPainter oldDelegate) => oldDelegate.color != color;
}

class _SourceCard extends StatelessWidget {
  final Color color;
  final Color labelColor;
  final Color iconColor;
  final IconData icon;
  final Widget? customIcon;
  final String label;
  final VoidCallback? onTap;

  const _SourceCard({
    required this.color,
    required this.labelColor,
    required this.iconColor,
    required this.icon,
    this.customIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: SizedBox(
          height: 92,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              customIcon ?? Icon(icon, size: 30, color: iconColor),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
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
