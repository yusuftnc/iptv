import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/m3u_parser.dart';
import 'player_screen.dart';
import 'source_screen.dart';

class M3uListScreen extends StatelessWidget {
  final String title;
  final List<M3uEntry> entries;
  final bool backToSources;

  const M3uListScreen({
    super.key,
    required this.title,
    required this.entries,
    this.backToSources = false,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _rows(entries);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue,
        leading: backToSources
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const SourceScreen()),
                  );
                },
              )
            : null,
      ),
      body: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row.header != null) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
              child: Text(
                row.header!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            );
          }

          final entry = row.entry!;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            horizontalTitleGap: 14,
            minLeadingWidth: 72,
            leading: _logo(entry.logo),
            title: Text(entry.name, style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                    contentId: entry.url,
                    streamUrl: entry.url,
                    contentType: 'live',
                    name: entry.name,
                    streamIcon: entry.logo,
                    historyId: entry.url,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _logo(String? url) {
    return Container(
      width: 72,
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        //color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: url == null
          ? const Icon(Icons.live_tv, color: Colors.black45, size: 20)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              errorWidget: (context, url, error) =>
                  const Icon(Icons.live_tv, color: Colors.black45, size: 20),
            ),
    );
  }
}

class _ListRow {
  final String? header;
  final M3uEntry? entry;

  const _ListRow.header(this.header) : entry = null;
  const _ListRow.entry(this.entry) : header = null;
}

List<_ListRow> _rows(List<M3uEntry> entries) {
  final rows = <_ListRow>[];
  String? current;
  for (final entry in entries) {
    final group = entry.group;
    if (group != null && group != current) {
      current = group;
      rows.add(_ListRow.header(group));
    }
    rows.add(_ListRow.entry(entry));
  }
  return rows;
}
