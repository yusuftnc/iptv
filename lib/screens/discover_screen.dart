import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/discover_title.dart';
import '../services/app_settings.dart';
import '../services/discover_service.dart';
import 'login_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final DiscoverService _service = DiscoverService();
  List<DiscoverTitle> _movies = [];
  List<DiscoverTitle> _series = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final results = await Future.wait([
        _service.popularMovies(),
        _service.popularSeries(),
      ]);
      if (!mounted) return;
      setState(() {
        _movies = results[0];
        _series = results[1];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Listeler yüklenemedi.';
        _isLoading = false;
      });
    }
  }

  void _openConnection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _openTitle(DiscoverTitle title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DiscoverDetailsScreen(
          title: title,
          onConnect: _openConnection,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: const Text('Keşfet'),
        backgroundColor: context.accent,
        actions: [
          IconButton(
            tooltip: 'Bağlantı',
            onPressed: _openConnection,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.palette.muted),
                        ),
                        const SizedBox(height: 16),
                        TextButton(onPressed: _load, child: const Text('Tekrar dene')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      if (_movies.isNotEmpty) ...[
                        _sectionHeader('Filmler', _movies.length),
                        _contentGrid(_movies),
                      ],
                      if (_series.isNotEmpty) ...[
                        _sectionHeader('Diziler', _series.length),
                        _contentGrid(_series),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.palette.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: context.palette.text,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contentGrid(List<DiscoverTitle> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final poster = item.posterUrl;
        final iconWidget = item.isSeries
            ? Icon(Icons.video_library, size: 30, color: context.palette.text)
            : Icon(Icons.movie, size: 30, color: context.palette.text);

        return Card(
          clipBehavior: Clip.antiAlias,
          color: Colors.grey[900],
          child: InkWell(
            onTap: () => _openTitle(item),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (poster != null)
                  CachedNetworkImage(
                    imageUrl: poster,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        Container(color: Colors.grey[800], child: iconWidget),
                  )
                else
                  Container(color: Colors.grey[800], child: iconWidget),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    color: Colors.black54,
                    child: Text(
                      item.title,
                      style: TextStyle(color: context.palette.text, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DiscoverDetailsScreen extends StatelessWidget {
  final DiscoverTitle title;
  final VoidCallback onConnect;

  const _DiscoverDetailsScreen({
    required this.title,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final cover = title.posterUrl ?? '';

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(title.title),
        backgroundColor: context.accent,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: Colors.black,
              child: cover.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const SizedBox(
                        height: 250,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => const SizedBox(
                        height: 250,
                        child: Icon(Icons.error, color: Colors.red, size: 50),
                      ),
                    )
                  : SizedBox(
                      height: 250,
                      child: Icon(
                        title.isSeries ? Icons.video_library : Icons.movie,
                        color: context.palette.muted,
                        size: 50,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.palette.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _detailRow(context, 'Tür', title.isSeries ? 'Dizi' : 'Film'),
                  if (title.year != null) ...[
                    const SizedBox(height: 8),
                    _detailRow(context, 'Yıl', title.year!),
                  ],
                  if (title.voteAverage > 0) ...[
                    const SizedBox(height: 8),
                    _detailRow(context, 'Puan', title.voteAverage.toStringAsFixed(1)),
                  ],
                  if (title.overview.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Açıklama',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.palette.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title.overview,
                      style: TextStyle(
                        color: context.palette.text,
                        fontSize: 16,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  /*
                    const Text(
                    'Oynatma, bağlandığın sağlayıcının kataloğuna bağlı.',
                    style: TextStyle(color: context.palette.text54, fontSize: 13),
                  ),
                  */
                ],
              ),
            ),
          ],
        ),
      ),
      /*
        floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context);
          onConnect();
        },
        backgroundColor: context.accent,
        icon: const Icon(Icons.link),
        label: const Text('Sağlayıcıya bağlan'),
      ),
      */
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.palette.text,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
