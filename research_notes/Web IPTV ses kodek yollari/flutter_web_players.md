# Flutter Web Video Player Seçenekleri (MKV/AC3, IPTV)

Bağlam: Bu repo web’de `video_player` + `dart:js_interop` DOM ses düzeltmesi (`lib/player/web_dom_player.dart`, `lib/player/web_dom_audio.dart`) kullanıyor; mobilde `flutter_vlc_player`. Sorun tipik olarak **görüntü var, ses yok** — çoğunlukla tarayıcının AC-3/E-AC-3/DTS sesi çözememesi, MKV konteynerinin ikincil etkeni.

---

## media_kit web yalnızca HTML5 mi kullanıyor (aynı kodek sınırları)?

### Takeaway

Evet. `media_kit` web’de **libmpv kullanmıyor**; oynatma **gömülü HTML `<video>`** ile yapılıyor. HLS için ek olarak **HLS.js** yükleniyor; bu da nihayetinde aynı `<video>` + tarayıcı MSE/codec desteğine bağlı. Native’deki “geniş format listesi” web’e taşınmıyor.

### Cited Findings

- Resmi dokümantasyon: “On the web, libmpv is not used. Video & audio playback is handled by embedding HTML `<video>` element. The format support depends upon the web browser. It happens to be extremely limited as compared to native platforms.” — [media_kit pub.dev documentation](https://pub.dev/documentation/media_kit/latest/)
- `media_kit` web uygulaması `dart:js_interop` + `package:web`, `platformViewRegistry.registerViewFactory`, HLS için dinamik `HLS.js` enjeksiyonu (`HLS.ensureInitialized`, `loadSource`, `attachMedia`) — [DeepWiki: media_kit Web Implementation](https://deepwiki.com/media-kit/media-kit/4.3-web-implementation); kaynak: [media_kit `hls.dart`](https://github.com/media-kit/media-kit/blob/main/media_kit/lib/src/player/web/utils/hls.dart)
- Bakımıcı (alexmercerind), RTSP/web codec konusunda: “support for media sources that can be played depends upon your web-browser” / “Not just Flutter for web... any web-browser with any frontend framework.” — [media-kit/media-kit#558](https://github.com/media-kit/media-kit/issues/558)
- `video_player_web` de tarayıcı codec matrisine yönlendirir; farklı paket değil, aynı HTML5 oynatma modeli — [video_player_web documentation](https://pub.dev/documentation/video_player_web/latest/)

### Inferences

- `video_player` → `media_kit` (web) geçişi, **AC-3’lü MKV/HLS/TS** için Chrome’da ses sorununu tek başına çözmez; yalnızca HLS segmentasyonu, altyazı/track API’si ve UI ergonomisi değişir.
- IPTV’de çoğu canlı akış zaten H.264 + AAC ise `media_kit` veya mevcut `video_player` yeterlidir; sorunlu başlıklar çoğunlukla **AC-3/E-AC-3** içeren VOD/MKV veya bazı TS varyantlarıdır.

### Gaps

- `media_kit`’in HLS.js yolunun **TS içi AC-3** için pratik başarı oranı (kanal/kaynak bazlı); genel dokümantasyon codec’i tarayıcıya devrediyor, ölçüm yok.

---

## Flutter, ffmpeg.wasm kullanan bir JS oynatıcıyı gömebilir mi?

### Takeaway

**Teknik olarak evet** (`HtmlElementView`, `registerViewFactory`, `dart:js_interop`, `index.html`’e script köprüsü). Fakat **canlı IPTV’de ffmpeg.wasm ile AC-3 çözüp ses vermek** üretim için uygunsuz: yüksek gecikme, CPU/RAM, SharedArrayBuffer/CORP kısıtları; paketler çoğunlukla **kısa dosya transcode/export** senaryosu için yazılmış, gerçek zamanlı remux/decode değil.

### Cited Findings

- Flutter web’de HTML gömme: `HtmlElementView.fromTagName('video', ...)`, `platformViewRegistry.registerViewFactory` — [Flutter: Embedding web content](https://docs.flutter.dev/platform-integration/web/web-content-in-flutter); [HtmlElementView API](https://api.flutter.dev/flutter/widgets/HtmlElementView-class.html)
- `ffmpeg_wasm` paketi: `index.html`’e `@ffmpeg/ffmpeg` script, geliştirmede `SharedArrayBuffer` bayrağı; çıktıyı `VideoPlayerController.network(XFile.fromData(bytes))` ile oynatma — [ffmpeg_wasm pub.dev](https://pub.dev/documentation/ffmpeg_wasm/latest/); [flutter_ffmpeg_wasm GitHub](https://github.com/redleafsofts/flutter_ffmpeg_wasm)
- Fluvie `fluvie_web_encoder`: tarayıcıda kare yakalayıp **ffmpeg.wasm ile MP4 encode**; “wasm build still determines which codecs… sharing the plan does not give every browser the desktop’s capabilities” — [Fluvie on-device web rendering](https://docs.fluvie.dev/guides/on-device-web-rendering/)
- Canlı decode örneği (H264 paketleri → wasm FFmpeg → WebGL): 1080p’de **80–120 ms** decode, “stuck”; 720p’de 10–30 ms — [RTSP H264 Wasm playback (ikuokuo RTS)](https://www.mo4tech.com/rtsp-h264-hevc-stream-wasm-playback.html) (üçüncü taraf teknik yazı, birincil kaynak değil ama ölçüm iddiası net)
- Dahua örneği: WebCodecs yoksa **ffmpeg.wasm fallback** — [dahua-rtspoverws](https://github.com/stalniy/dahua-rtspoverws)
- `dart:js_interop` + hls.js örneği ve DOM’a bağlanma zamanlaması (`MutationObserver` / `ResizeObserver` önerisi) — [Flutter#163940](https://github.com/flutter/flutter/issues/163940)

### Inferences

- Mevcut projede zaten `package:web` + `dart:js_interop` kullanılıyor; özel **HtmlElementView + hls.js/mpegts.js/Video.js** katmanı mümkün, fakat **AC-3 sesi ffmpeg.wasm ile çözmek** = tüm akışı istemcide demux+decode+PCM/WebAudio; IPTV bitrate’lerinde sürdürülebilir değil.
- `crossOriginIsolated` + ffmpeg.wasm, Firebase/CDN gibi kaynaklarda **CORP/CORS** ile `video_player` indirmelerini de zorlaştırabilir — [Stack Overflow: crossOriginIsolated video 206](https://stackoverflow.com/questions/77024805/video-download-problem-with-fluter-web-when-crossoriginisolated-true)

### Gaps

- Flutter içinde **tam entegre**, bakımlı, IPTV odaklı “ffmpeg.wasm live player” paketi bulunamadı; örnekler demo/POC seviyesinde.

---

## Üretimde Flutter web ile IPTV yayan uygulamalar var mı?

### Takeaway

Var, ancak çoğu **HLS + tarayıcı codec sınırlarını** kabul ediyor; desteklenmeyen akışlar için **desktop VLC/libVLC** veya mobil `media_kit`/mpv’ye yönlendirme pattern’i kullanılıyor. Web tarafında ses codec genişletmesi genelde **sunucu tarafı transcoding/remux** ile çözülüyor.

### Cited Findings

- **IPTV Flutter Multiplatform** (Android/iOS/desktop/web): `media_kit`, M3U/Xtream, “Web providers must allow CORS” — [Sobrio25/IPTV-Flutter-Multiplatform](https://github.com/Sobrio25/IPTV-Flutter-Multiplatform)
- **Chillz**: React web = HLS.js; Flutter desktop = **libVLC** worker; mobil = **media_kit (MPV)**; web’de oynatılamayanlar **VLC hand-off** — [Chillz engineering blog](https://blog.simiyonvinscentsamuel.tech/chillz-iptv-flutter/)
- **atba** (TorBox client, cross-platform): web’de `MediaKit` + özel CORS/userscript köprüsü (`dart:js_interop` `postMessage`) — [atba commit 3ec3db7](https://github.com/93Pd9s8Jt/atba/commit/3ec3db747229126a08523fb991557c4cde23a19f)
- **WEB_TV_APP**: Flutter web IPTV (M3U/Xtream/TMDB); player detayı belirsiz, tipik `video_player`/`media_kit` ailesi — [LukasSteinerr/WEB_TV_APP](https://github.com/LukasSteinerr/WEB_TV_APP)
- Mantle (Jellyfin benzeri) web/Android’de AC-3 sessizliği: Chromium MSE’de AC-3/E-AC-3/DTS/TrueHD **desteklenmiyor**; çözüm **çekirdekte Go ile AC-3 decode → FLAC remux** — [Mantle issue #38](https://codefloe.com/sotherdev/mantle/issues/38)

### Inferences

- Üretim IPTV Flutter ekosistemi **web’de VLC benzeri codec özgürlüğü aramıyor**; ya kaynak AAC’li, ya proxy transcode, ya native uygulama.
- Bu repo’nun mobil VLC + web `video_player` ayrımı sektörde yaygın ve mantıklı.

### Gaps

- Ticari kapalı kaynak Flutter web IPTV ürünlerinin codec stratejisi (çoğu public değil).

---

## better_player, flutter_vlc, hls.js, mpegts.js, Shaka/Video.js — AC-3’ü Chrome’da değiştirir mi?

### Takeaway

**flutter_vlc_player: web yok** (sadece iOS/Android). **better_player_web**: **Shaka Player** + HTML5; codec yine **tarayıcı MSE**. **hls.js / mpegts.js / Shaka** container/transmux yapar ama **AC-3 decode’u Chrome’da genelde veremez** (macOS Chrome’da özellikle). MKV konteyner desteği Chromium’da arttı; asıl kilit **ses codec’i**.

### Cited Findings

- `flutter_vlc_player`: “Flutter for web is not supported yet” / “no plans yet” — [solid-software/flutter_vlc_player#96](https://github.com/solid-software/flutter_vlc_player/issues/96); [pub.dev](https://pub.dev/packages/flutter_vlc_player) yalnızca iOS/Android
- `better_player_web`: Shaka Player; `index.html`’e shaka script — [better_player_web](https://pub.dev/packages/better_player_web)
- Shaka: “Shaka Player does not directly deal with formats or codecs… handled by the browser”; AC-3 transmux “depends on browser support via MediaSource” — [Shaka README](https://github.com/shaka-project/shaka-player/blob/main/README.md)
- mpegts.js: “ac-3 / ec-3 … supported by Safari (MacOS) / Edge (Windows), **not supported by Chrome**” — [mpegts.js#209](https://github.com/xqq/mpegts.js/issues/209)
- Chromium: AC-3/E-AC-3 için **platform decoder** (Windows; macOS için kod var ama `ENABLE_PLATFORM_AC3_EAC3_AUDIO` build flag ile) — [chromium commit 1ec72b6 (Windows)](https://github.com/chromium/chromium/commit/1ec72b6410df5f90eaf4f24f33074f8682c7ffc5); [enable-chromium-ac3-ec3-system-decoding](https://github.com/cjw1115/enable-chromium-ac3-ec3-system-decoding)
- MKV Matroska MIME Chromium’a eklendi; `mkv_audio_codecs` içinde AC-3 **yalnızca** `ENABLE_PLATFORM_AC3_EAC3_AUDIO` ile — [chromium commit d081300](https://github.com/chromium/chromium/commit/d0813004e27eb2f679dd4a9e26a13baeac4be9f2)
- hls.js AC-3: “Codec support depends on the browser” — [hls.js#7201](https://github.com/video-dev/hls.js/issues/7201)

### Inferences

- **Video.js / Plyr** = yine `<video>` sarmalayıcı; codec sınırı değişmez — Flutter’da `HtmlElementView` + Plyr örneği — [Stack Overflow Plyr + HtmlElementView](https://stackoverflow.com/questions/64998597/how-to-convert-flutter-web-view-to-htmlelementview-on-web-mode)
- macOS’ta geliştirici makinesi (user_info: darwin): **Chrome’da AC-3 beklentisi düşük**; Safari native `<video>` bazı AC-3 senaryolarında daha iyi olabilir (mpegts.js yorumu), fakat ürün hedefi “Chrome” ise bu yardımcı olmaz.
- **Windows Chrome + Edge** bazı AC-3 MP4/MKV varyantlarında ses verebilir; platforma göre farklı UX gerekir — deterministik değil.

### Gaps

- 2025+ Chromium MKV native oynatma ile **doğrudan URL MKV + AC-3** kombinasyonunun güncel Chrome sürümlerinde yüzdesel başarı oranı (kaynak/encoder’a bağlı).

---

## WebCodecs / Mediabunny ile istemci tarafı AC-3 decode (alternatif ffmpeg.wasm yolu)

### Takeaway

W3C **WebCodecs ses kaydı AC-3 içermiyor** — [WebCodecs Codec Registry](https://www.w3.org/TR/webcodecs-codec-registry/). **Mediabunny `@mediabunny/ac3`** yazılım decoder’ı ekliyor; teorik olarak özel bir **HtmlElementView + WebAudio** hattı kurulabilir. Bu, **canlı IPTV için ağır ve yeşil alan**; bakım maliyeti yüksek, üretim IPTV örnekleri görülmedi.

### Cited Findings

- Mediabunny: “AC-3 and E-AC-3 are not natively supported by WebCodecs”; `@mediabunny/ac3` ile register — [Mediabunny supported codecs](https://mediabunny.dev/guide/supported-formats-and-codecs)
- MDN WebCodecs codec seçimi tablosu: Opus, AAC, MP3, FLAC, Vorbis, PCM — AC-3 yok — [MDN WebCodecs codec selection](https://developer.mozilla.org/en-US/docs/Web/API/WebCodecs_API/Codec_selection)

### Inferences

- “Tarayıcıda VLC” ya **sunucu transcode** ya da **native app** ile yapılıyor; istemci AC-3 WASM decode IPTV ölçeğinde nadir ve riskli.

### Gaps

- Mediabunny AC-3 decoder’ın **canlı TS/HLS** (sürekli segment) ile latency/CPU ölçümleri — bulunamadı.

---

## Pratik öneri: “video var, ses yok” için olasılık sıralaması

### Takeaway

Chrome (özellikle macOS) hedefinde **oynayıcı paketi değiştirmek** tek başına en düşük getirili yol. En yüksek başarı: **akışı AAC (veya opus) içeren profile’a çevirmek** (sunucu/proxy/VOD remux); ikinci: **destek tespiti + native VLC/mobil yönlendirme**; üçüncü: **Windows Edge/Chrome** kullanıcıları için sınırlı iyileşme beklentisi; **ölü uçlar**: flutter_vlc web, saf ffmpeg.wasm canlı decode, hls.js/shaka/better_player/media_kit ile AC-3 “sihri”.

### Cited Findings

- Mevcut stack: `WebAppPlayerController` → `VideoPlayerController.networkUrl` + DOM `forceUnmuteAllVideos` (jest/autoplay değil, codec) — repo `lib/player/web_app_player.dart`, `lib/player/web_dom_audio.dart`
- Mantle modeli (sunucu tarafı AC-3 → FLAC/AAC benzeri tarayıcı codec) — [Mantle #38](https://codefloe.com/sotherdev/mantle/issues/38)
- Chillz modeli (web destekleyemez → VLC) — [Chillz blog](https://blog.simiyonvinscentsamuel.tech/chillz-iptv-flutter/)

### Inferences — sıralı liste (yüksek → düşük)

| Sıra | Yol | AC-3/MKV ses ihtimali | Not |
|------|-----|------------------------|-----|
| 1 | **Proxy/transcode** (FFmpeg sunucuda: `-c:v copy -c:a aac` veya tüm VOD remux) | **Yüksek** | IPTV sağlayıcı veya kendi edge’iniz; web client aynı kalabilir (`video_player`). |
| 2 | **Codec probe + UX**: `MediaSource.isTypeSupported` / manifest audio codec; sessiz içerik uyarısı, “mobil uygulamada aç” / masaüstü VLC deep link | **Yüksek (sorunu çözmek yerine doğru yönlendirme)** | Chrome’da false hope önlenir. |
| 3 | **Tarayıcı hedefi genişletme**: macOS’ta Safari (bazı AC-3), Windows’ta Edge (mpegts.js notları) | **Orta, parçalı** | Tek “Chrome everywhere” ürün stratejisiyle çelişir. |
| 4 | **HtmlElementView + hls.js/mpegts.js** (mevcut `video_player` yerine özelleştirilmiş web player) | **Düşük–orta** | HLS/TS demux iyileşir; AC-3 Chrome’da çoğunlukla aynı. |
| 5 | **media_kit** veya **better_player** (web) | **Düşük** | HLS/DASH/DRM ergonomisi; AC-3 kök nedeni değişmez. |
| 6 | **ffmpeg.wasm / özel WebCodecs+Mediabunny AC-3** istemci decode | **Çok düşük (canlı)** | VOD kısa klip/transcode dışında dead end. |
| 7 | **flutter_vlc_player web** | **Yok** | Plan yok. |

**Dead ends (dürüst liste):**

- Web’de **libVLC/mpV** (media_kit native motoru) — yok.
- **video_player_web ↔ media_kit ↔ better_player_web** üçlüsü arasında AC-3 farkı — pratikte yok.
- **hls.js / Shaka / mpegts.js** — Chrome AC-3 decode eklemez.
- **ffmpeg.wasm** tam akış remux — canlı IPTV için performans/CORP.

### Gaps

- Bu IPTV uygulamasının problemli başlıklarının **kaynak format dağılımı** (yüzde kaç AC-3 TS vs MKV VOD) ölçülmedi; öncelik transcode mu UX mi netleşir.
- Kullanıcı tabanının **Windows vs macOS Chrome** oranı bilinmiyor (Windows’ta AC-3 şansı biraz daha yüksek).

### Inferences — ürün stratejisi (mobil VLC korunarak)

- **Mobilde VLC**: korunmalı; web’in codec sınıfından üstün.
- **Web’de**: `video_player` + mevcut DOM unlock yeterli **AAC/H.264** için; AC-3 başlıklarda **sunucu ses parçası transcode** veya **“VLC ile aç” / mobil yönlendirme** en gerçekçi ikili.
- Gelecekte web player değiştirmek yalnızca **HLS.js entegrasyonu, track seçimi, DRM** gerekirse mantıklı; ses codec motivasyonuyla değil.