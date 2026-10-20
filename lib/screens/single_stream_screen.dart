import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import 'player_screen.dart';

class SingleStreamScreen extends StatefulWidget {
  const SingleStreamScreen({super.key});

  @override
  State<SingleStreamScreen> createState() => _SingleStreamScreenState();
}

class _SingleStreamScreenState extends State<SingleStreamScreen> {
  final _controller = TextEditingController();
  String _error = '';
  bool _hasUrl = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onUrlChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final hasUrl = _controller.text.trim().isNotEmpty;
    if (hasUrl == _hasUrl && _error.isEmpty) return;
    setState(() {
      _hasUrl = hasUrl;
      if (hasUrl) _error = '';
    });
  }

  void _play() {
    final text = _controller.text.trim();
    final uri = Uri.tryParse(text);
    final scheme = uri?.scheme.toLowerCase();
    final allowed = scheme == 'http' || scheme == 'https' || scheme == 'rtsp' || scheme == 'rtmp' || scheme == 'rtsps';
    if (uri == null || !uri.hasScheme || !allowed || uri.host.isEmpty) {
      setState(() => _error = AppText.get('streamAddressInvalid'));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          contentId: text,
          streamUrl: text,
          contentType: 'live',
          name: 'Yayın',
          historyId: text,
          allowFavorite: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text(AppText.get('singleStream')),
        backgroundColor: context.accent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: TextStyle(color: p.text),
              decoration: InputDecoration(
                labelText: AppText.get('streamAddress'),
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                filled: true,
                fillColor: p.field,
                labelStyle: TextStyle(color: p.label),
              ),
              onSubmitted: (_) => _play(),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _hasUrl ? _play : null,
              style: FilledButton.styleFrom(
                backgroundColor: context.accent,
                disabledBackgroundColor: p.disabledButton,
                foregroundColor: Colors.white,
                disabledForegroundColor: p.disabledButtonText,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(AppText.get('play'), style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
