import 'package:flutter_test/flutter_test.dart';
import 'package:sutu_player/services/m3u_parser.dart';

void main() {
  test('kanal listesini ad, grup ve adres olarak ayırır', () {
    const raw = '''
#EXTM3U
#EXTINF:-1 tvg-logo="http://img/a.png" group-title="Spor",Kanal, Bir
http://example.com/a.m3u8
#EXTINF:-1 group-title="Haber",Kanal İki
https://example.com/b
''';

    final result = parseM3u(raw);

    expect(result.isHls, isFalse);
    expect(result.isValid, isTrue);
    expect(result.entries, hasLength(2));
    expect(result.entries.first.name, 'Kanal, Bir');
    expect(result.entries.first.group, 'Spor');
    expect(result.entries.first.logo, 'http://img/a.png');
    expect(result.entries.first.url, 'http://example.com/a.m3u8');
    expect(result.entries.last.name, 'Kanal İki');
  });

  test('HLS dosyasını kanal listesi saymaz', () {
    const raw = '''
#EXTM3U
#EXT-X-TARGETDURATION:6
#EXTINF:6,
seg0.ts
''';

    final result = parseM3u(raw);

    expect(result.isHls, isTrue);
    expect(result.isValid, isTrue);
    expect(result.entries, isEmpty);
  });

  test('düz adres satırını geçersiz sayar', () {
    const raw = 'https://tinyurl.com/ByteFixRepairs2026';

    final result = parseM3u(raw);

    expect(result.isValid, isFalse);
    expect(result.entries, isEmpty);
  });

  test('başlığı olup kanalı olmayan dosyayı geçersiz sayar', () {
    final result = parseM3u('#EXTM3U\n');

    expect(result.isValid, isFalse);
    expect(result.entries, isEmpty);
  });
}
