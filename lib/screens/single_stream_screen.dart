import 'package:flutter/material.dart';

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
      setState(() => _error = 'Geçerli bir yayın adresi gir.');
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Tek yayın'),
        backgroundColor: Colors.blue,
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
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Yayın adresi',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                filled: true,
                fillColor: Colors.white10,
                labelStyle: TextStyle(color: Colors.white70),
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
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.white12,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Oynat', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
