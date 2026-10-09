import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/discover_title.dart';

class DiscoverService {
  static const _moviesUrl = 'https://api.anyplay.stream/v1/movies';
  static const _seriesUrl = 'https://api.anyplay.stream/v1/series';
  static const _moviesAsset = 'assets/movies.json';
  static const _seriesAsset = 'assets/series.json';

  Future<List<DiscoverTitle>> popularMovies() {
    return _load(_moviesUrl, fallbackAsset: _moviesAsset, isSeries: false);
  }

  Future<List<DiscoverTitle>> popularSeries() {
    return _load(_seriesUrl, fallbackAsset: _seriesAsset, isSeries: true);
  }

  Future<List<DiscoverTitle>> _load(
    String url, {
    required String fallbackAsset,
    required bool isSeries,
  }) async {
    try {
      return await _parse(await _fetchRemote(url), isSeries: isSeries);
    } catch (_) {
      return _parse(await rootBundle.loadString(fallbackAsset), isSeries: isSeries);
    }
  }

  Future<String> _fetchRemote(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Liste alınamadı (${response.statusCode})');
    }
    return response.body;
  }

  List<DiscoverTitle> _parse(String raw, {required bool isSeries}) {
    final body = jsonDecode(raw) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map((item) => DiscoverTitle.fromJson(item, isSeries: isSeries))
        .where((item) => item.title.isNotEmpty)
        .toList();
  }
}
