import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Yerel FFmpeg AAC proxy (`tools/web_aac_proxy/proxy.py`).
class WebAacProxy {
  WebAacProxy._();

  static const baseUrl = String.fromEnvironment(
    'WEB_AAC_PROXY',
    defaultValue: 'http://127.0.0.1:8787',
  );

  static bool get isEnabled => kIsWeb;

  static bool isProxied(String url) =>
      url.contains('/play?') && url.startsWith(baseUrl);

  static bool shouldWrap(String url) {
    if (!isEnabled || url.isEmpty) return false;
    if (isProxied(url)) return false;
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return false;
    if (lower.contains('.mp4')) return false;
    if (lower.contains('.mkv') ||
        lower.contains('.avi') ||
        RegExp(r'\.ts($|\?)').hasMatch(lower)) {
      return true;
    }
    if (lower.contains('/movie/') ||
        lower.contains('/series/') ||
        lower.contains('/vod/')) {
      return true;
    }
    return false;
  }

  static String? unwrapSource(String proxied) {
    final uri = Uri.tryParse(proxied);
    if (uri == null) return null;
    return uri.queryParameters['src'];
  }

  static String wrap(String url, {double startSeconds = 0}) {
    final source =
        isProxied(url) ? (unwrapSource(url) ?? url) : url;
    final params = <String, String>{
      'src': source,
      'ua': 'Mozilla/5.0',
    };
    if (startSeconds > 0.5) {
      params['ss'] = startSeconds.toStringAsFixed(3);
    }
    return Uri.parse('$baseUrl/play').replace(queryParameters: params).toString();
  }

  static Future<Duration?> fetchDuration(String originalOrProxied) async {
    if (!isEnabled) return null;
    final source = isProxied(originalOrProxied)
        ? (unwrapSource(originalOrProxied) ?? originalOrProxied)
        : originalOrProxied;
    if (source.isEmpty) return null;
    try {
      final uri = Uri.parse('$baseUrl/meta').replace(
        queryParameters: {'src': source, 'ua': 'Mozilla/5.0'},
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 45));
      if (res.statusCode != 200) return null;
      final map = jsonDecode(res.body);
      if (map is! Map) return null;
      final sec = (map['duration'] as num?)?.toDouble() ?? 0;
      if (sec <= 1) return null;
      return Duration(milliseconds: (sec * 1000).round());
    } catch (_) {
      return null;
    }
  }
}
