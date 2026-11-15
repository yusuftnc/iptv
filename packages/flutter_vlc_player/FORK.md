# flutter_vlc_player fork

Paketi `path:` ile sabitliyoruz; pub’dan kör yükseltme yok.

## Neden fork?

- Sürüm ve native bağımlılıkları kontrol altında tutmak
- Uygulama cast / player akışı bu API’ye bağlı; sürpriz kırılma istemiyoruz

## 16 KB (2026)

Upstream `7.4.4` Android’de `libvlc-all:3.6.3` kullanıyor (16 KB page size).
Bu fork’ta yalnızca o bağımlılık hizalandı; tüm upstream tree merge edilmedi
(bizdeki AGP/Kotlin zaten daha yeni).

## Güncelleme kuralı

1. Upstream changelog’a bak
2. Mümkünse tek dosyalık / tek bağımlılık cherry-pick
3. Film/dizi oynatma + TV yansıt smoke test
