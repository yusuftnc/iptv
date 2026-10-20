import 'package:flutter_test/flutter_test.dart';
import 'package:sutu_player/models/saved_playlist.dart';

void main() {
  test('eski host ve port tek adreste playlist olur', () {
    final playlist = playlistFromLegacyCredentials({
      'host': 'ornek.com',
      'port': '8080',
      'username': 'ali',
      'password': 'gizli',
    });

    expect(playlist, isNotNull);
    expect(playlist!.id, 'legacy');
    expect(playlist.kind, 'xtream');
    expect(playlist.host, 'http://ornek.com:8080');
    expect(playlist.name, 'ornek.com');
    expect(playlist.password, 'gizli');
  });

  test('eksik girişten playlist üretmez', () {
    expect(
      playlistFromLegacyCredentials({
        'host': 'ornek.com',
        'port': '8080',
        'username': '',
        'password': '',
      }),
      isNull,
    );
  });
}
