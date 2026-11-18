# Server-side / edge transcoding ve remux (IPTV web hedefi: H.264 + AAC + HLS)

Bu notlar, Flutter web (SUTU Player) için tarayıcıda güvenilir oynatım hedefiyle hazırlanmıştır. Rapor yazarı için: her iddia kaynaklıdır; spekülasyonlar **Inferences** altında.

---

## Remux vs transcode: ne zaman remux yeterli?

### Takeaway
Tarayıcıda **H.264 video + AAC ses** zaten kaynakta varsa ve sorun yalnızca **konteyner** (MKV, bazı TS paketlemeleri) veya **HLS segment paketi** ise **remux** (`-c:v copy -c:a copy` veya yalnızca mux değişimi) yeterlidir; CPU yükü Jellyfin/Plex/Emby ölçeğinde en düşük kategoridedir. **AC3/EAC3, HEVC (tarayıcıya göre), DTS** veya **MKV + Firefox/Safari** gibi kombinasyonlarda remux yetmez; en az **ses transcode** (çoğunlukla AAC stereo), gerekirse **video transcode** (H.264) gerekir.

### Cited Findings
- Jellyfin dört oynatma modunu CPU yükü sırasıyla tanımlar: Direct Play < Remux < Direct Stream (ses transcode) < Transcode (video) — [Jellyfin Transcoding](https://jellyfin.org/docs/general/post-install/transcoding/)
- Konteyner desteklenmiyorsa remux; video kodek desteklenmiyorsa transcode; ses uyumsuzsa ses transcode — [Jellyfin Codec Support](https://jellyfin.org/docs/general/clients/codec-support.md)
- Emby remux'un yeniden encode etmediğini, paket başlığı/çerçeveleme değişikliği olduğunu açıklar; video kopyalanırken sesin AAC'ye çevrilebileceği karışık mod mümkündür — [Emby Playback Remuxing](https://emby.media/learn/articles/playback-streaming/from-server/Playback-Remuxing.html)
- Plex: konteyner uyumsuzluğunda Direct Stream (remux benzeri); video **veya** ses kodek uyumsuzluğunda transcode — [Plex Streaming Overview](https://support.plex.tv/articles/200430303-streaming-overview/)
- MKV Chrome/Firefox/Safari'de doğrudan oynatılamaz; Jellyfin çoğu web oturumunda HLS+TS remux'a düşer — [Jellyfin Codec Support (Container table)](https://jellyfin.org/docs/general/clients/codec-support.md)
- MSE/HLS için pratik taban: H.264 + AAC + MP4/fMP4 — [MDN Media Source Extensions](https://developer.mozilla.org/en-US/docs/Web/API/Media_Source_Extensions_API)
- Jellyfin web istemcisi uyumsuz içerik için HLS; client device profile ile Direct Play > Direct Stream > Transcode seçer — [Jellyfin Streaming Decision Engine (community doc mirror)](https://deepwiki.com/jellyfin/jellyfin-web/4.5-streaming-decision-engine)

### Inferences
- **IPTV VOD tipik senaryo** (`H.264 + AC3` MKV/MP4): remux tek başına web için **yetersiz** (Chrome'da AC3 MSE'de genelde yok; bkz. sonraki bölüm). Pratik hedef: `-c:v copy -c:a aac -b:a 128k` + HLS fMP4 veya TS.
- **H.264 + AAC** zaten **MP4** veya uygun **HLS** ise: Xtream URL'sini doğrudan veya reverse proxy ile vermek remux katmanına gerek kalmadan yeterli olabilir.
- **Canlı `.m3u8` + H.264 + AAC** panel çıktısı: remux'sız proxy bile yeterli olabilir; AC3 içeren TS canlı yayınlarda ses transcode gerekir.

### Gaps
- Jellyfin dokümantasyonunda Chrome için AC3 tablosu "✅" gösterirken Plex forumları Chrome'da AC3'ün transcode gerektirdiğini söyler; bu, **doğrudan MP4 oynatma** ile **HLS/MSE TS içi AC3** ayrımından kaynaklanıyor olabilir — tek resmi Jellyfin/Plex matrisi yok; üretimde `MediaSource.isTypeSupported` ile doğrulama şart.

---

## Tarayıcı kodek gerçekleri (MKV/AC3 neden kırılıyor?)

### Takeaway
Web hedefi için güvenli varsayılan **H.264 (8-bit, yuv420p) + AAC-LC (çoğu zaman stereo)** ve **HLS (TS veya fMP4)**. AC3: Edge tarihsel olarak desteklemiş olsa da Chromium ailesinde MSE yoluyla güvenilir değil; Plex/Jellyfin ekosistemi web için AAC'ye düşer.

### Cited Findings
- H.264 tarayıcı desteği yaygın — [Can I use MPEG-4/H.264](https://caniuse.com/mpeg4)
- Plex Web + Chrome: AAC direct play, AC3 için sunucu ses transcode — [Plex Forums: alternate audio formats](https://forums.plex.tv/t/how-does-plex-deal-with-alternate-audio-formats/846282)
- MPEG-TS içinde AC3 için mpegts.js: tarayıcı AC3 desteklemiyorsa çalışmaz — [mpegts.js issue #115](https://github.com/xqq/mpegts.js/issues/115)
- Örnek Chrome 145 MSE matrisi: `audio/ac3` → desteklenmiyor, `audio/aac` → evet — [browser-media-support.pages.dev/mse](https://browser-media-support.pages.dev/mse)
- Edge Dolby AC-3/E-AC-3 duyurusu (legacy Edge); diğer tarayıcılara fallback önerisi — [Microsoft Edge Blog 2015](https://blogs.windows.com/msedgedev/2015/05/26/announcing-dolby-audio-for-high-performance-audio-in-microsoft-edge/)

### Inferences
- SUTU **Flutter web**: `video_player` / `hls` / MSE tabanlı oynatıcılar AC3+MKV muxed akışı **native olmadan** çözemez; sunucu tarafı veya panelden AAC+HLS şart.
- Mobil Flutter (Android/iOS) ve VLC engine farklı kurallara tabi; bu not **web istemcisi** odaklıdır.

### Gaps
- Jellyfin AC3 "Chrome ✅" satırı ile pratik MSE testleri çelişiyor; nihai karar cihaz/tarayıcı sürümüne bağlı.

---

## On-the-fly FFmpeg proxy desenleri (Xtream Codes VOD URL'leri)

### Takeaway
Xtream VOD URL'leri genelde **tek dosya progressive download** (`/movie/user/pass/id.mkv|mp4`) döner; panel **HLS VOD manifest'i üretmez**. Indie uygulama için yaygın desen: **oturum başına FFmpeg child process**, kaynak URL'yi `-i` ile okuyup **stdout/pipe veya disk üzerinde rolling HLS** üretmek; seek için HTTP Range → FFmpeg `-ss` ile segment yenileme (Jellyfin `DynamicHlsController` modeli).

### Cited Findings
- VOD URL kalıbı: `http://SERVER:PORT/movie/USER/PASS/STREAM_ID.EXT`; `container_extension` API'den gelir (mp4, mkv, avi…) — [Xtream-Masters player_api guide](https://xtream-masters.com/guide/xtream_codes_api_player_api_documentation.php)
- VOD için HTTP 206 Partial Content desteklenir (seek) — [DeepWiki VOD streaming](https://deepwiki.com/worldofiptvcom/xtream-codes-api/8.2-vod-and-series-streaming)
- Jellyfin VOD HLS uç noktası parametreleri: `enableAutoStreamCopy`, `audioCodec=aac`, `segmentContainer`, `Videos/{id}/main.m3u8` — [Jellyfin DynamicHlsController (source)](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Api/Controllers/DynamicHlsController.cs)
- Jellyfin FFmpeg HLS VOD: `-hls_playlist_type vod`, `-hls_list_size 0`, varsayılan segment ~6 sn — [DeepWiki Jellyfin HLS](https://deepwiki.com/lucienlmy/jellyfin/5.2-hls-streaming)
- MediaFlow Proxy: Xtream API proxy + isteğe bağlı **fMP4 H.264/AAC** transcode; MKV+AC3 için "fast-path" video copy + ses transcode — [mediaflow-proxy README](https://github.com/mhdzumair/mediaflow-proxy?tab=readme-ov-file), [Remuxer engine doc mirror](https://deepwiki.com/mhdzumair/mediaflow-proxy/4.4-remuxer-and-transcoding-engine)
- Lunarr modeli: probe ayrı, oynatma için FFmpeg HLS; H.264/AAC uyumlu ise **copy remux HLS**, aksi halde transcode — [lunarr-go transcoding-runtime.md](https://github.com/lunarr-app/lunarr-go/blob/main/docs/transcoding-runtime.md)
- RTMP/H.264/AAC kaynak için `ffmpeg -c copy -f hls` passthrough örneği — [StreamHub passthrough docs](https://streamhub.studio/docs/features/rtmp-passthrough)

### Inferences
**Örnek minimal VOD proxy komut ailesi** (kaynak: AC3+MKV/H.264):

```bash
ffmpeg -hide_banner -loglevel error \
  -i "http://panel/movie/u/p/12345.mkv" \
  -map 0:v:0 -map 0:a:0 \
  -c:v copy -c:a aac -b:a 128k -ac 2 \
  -f hls -hls_time 4 -hls_playlist_type vod \
  -hls_list_size 0 -hls_segment_type fmp4 \
  -hls_fmp4_init_filename init.mp4 \
  /tmp/sess123/out.m3u8
```

- **Güvenlik**: Xtream kimlik bilgileri proxy'de saklanır; istemciye yalnızca kısa ömürlü oynatma token'ı verilmeli (MediaFlow'un encrypted URL modeli buna yakın).
- **Ölçek**: eşzamanlı VOD = eşzamanlı FFmpeg; indie için **transcodeConcurrency** benzeri sınır şart (Stremio settings: `transcodeConcurrency` — [stremio-core response.rs](https://stremio.github.io/stremio-core/src/stremio_core/types/streaming_server/response.rs.html)).

### Gaps
- Xtream panelinin sunucu tarafında "web için AAC variant" sunup sunmadığına dair resmi API alanı yok; yalnızca `container_extension` ve canlı için `allowed_output_formats` belgelenmiş.

---

## Jellyfin / Plex / Emby / Stremio: mimari kalıplar

### Takeaway
Hepsi aynı karar ağacını uygular: **istemci capability profile** → direct play / remux to HLS / audio-only transcode / full transcode. Stremio, torrent/HTTP için yerel **streaming-server** (FFmpeg) kullanır; Chromecast'te `forceTranscoding` zorlanabilir. Indie IPTV için Jellyfin'in tam stack'ini kopyalamak yerine **yalnızca Dynamic HLS + FFmpeg process manager** katmanı daha hafiftir.

### Cited Findings
- Jellyfin remux → HLS/TS; audio remux HLS konteyner kısıtına takılırsa transcode — [Jellyfin PR #11399 discussion](https://github.com/jellyfin/jellyfin/pull/11399)
- Plex Chrome HEVC için custom client profile ile HLS transcode hedefi örneği — [Plexopedia Chrome HEVC](https://www.plexopedia.com/plex-media-server/general/chrome-play-hevc/)
- Emby web: sunucu istemci+tarayıcı yoluna göre paketler; HLS varlığı transcode tipini göstermez — [Emby HLS Learn](https://emby.media/learn/articles/playback-streaming/delivery/hls/Playback-HLS.html)
- Stremio web: localhost:11470 streaming server; cast'te `streamingServer.baseUrl`; `forceTranscoding` query — [DeepWiki Stremio streaming server](https://deepwiki.com/Stremio/stremio-web/4.6-streaming-server-integration)
- Stremio cast transcode hatası: parse başarısız olunca tüm akış gereksiz libx264+vorbis — [stremio-bugs #2787](https://github.com/stremio/stremio-bugs/issues/2787)

### Inferences
- SUTU için **device profile JSON** (Jellyfin `TranscodingProfiles`: container `ts` veya `mp4`, video `h264`, audio `aac`) web istemcisine göre sabitlenebilir.
- Stremio öğretisi: cast/web uyumu için transcode pipeline'da **stream probe + explicit `-map` + copy path** şart; aksi halde CPU ve uyumsuz ses (Vorbis) riski.

### Gaps
- Stremio'nun resmi dokümantasyonu IPTV/Xtream için değil; kalıp aktarımı çıkarımsal.

---

## Threadfin / xTeVe / nginx-rtmp / Cloudflare Workers

### Takeaway
- **Threadfin/xTeVe**: IPTV → Plex/Jellyfin **canlı TV tuner** proxy; FFmpeg buffer ile **canlı** akışı yeniden paketler; varsayılan remux, Plex uyumu için ses → MP3/AAC transcode seçenekleri. **VOD transcode platformu değil**.
- **nginx-rtmp**: RTMP ingest + **hls on**; girdi zaten H.264/AAC değilse `exec ffmpeg` ile transcode. IPTV HTTP kaynağı için doğrudan uygun değil, araya publisher gerekir.
- **Cloudflare Workers**: FFmpeg binary çalıştıramaz; kuyruk + **Containers** veya **Stream Media Transformations** (kısa klip/MP4/AAC çıktı) — **canlı Xtream passthrough için uygun değil**, VOD batch/cache için düşünülebilir.

### Cited Findings
- Threadfin: xTeVe fork; HLS/M3U8 buffer, tuner sayısı — [Threadfin GitHub](https://github.com/Threadfin/Threadfin)
- Threadfin FFmpeg buffer Plex için; default remux — [IPTVshift Plex+Threadfin guide](https://community.iptvshift.com/t/plex-live-tv-threadfin/)
- xTeVe FFmpeg varsayılan remux; Plex DVR için `-c:v copy -c:a libmp3lame -f mpegts` — [xTeVe stream buffering doc mirror](https://deepwiki.com/xteve-project/xTeVe-Documentation/6.1-stream-buffering-and-transcoding)
- nginx-rtmp: HLS için girdi H.264/AAC; aksi halde `exec` — [arut/nginx-rtmp-module README](https://github.com/arut/nginx-rtmp-module/blob/master/README.md)
- Cloudflare Workers transcoding: kontrol düzlemi Workers, ağır iş Container/R2 — [Cloudflare Perspectives](https://www.cloudflare.com/perspectives/choosing-a-serverless-platform-for-video-transcoding-pipelines/), [kentcdodds FFmpeg offload](https://kentcdodds.com/blog/offloading-ffmpeg-with-cloudflare)
- Cloudflare Media binding: `mode: video` → H.264/AAC MP4 çıktı — [Cloudflare Stream Media Transformations](https://developers.cloudflare.com/stream/transform-videos/bindings/)

### Inferences
- SUTU **canlı IPTV web**: panel `.m3u8` veriyorsa Threadfin benzeri buffer gerekmez; AC3 TS ise küçük bir **FFmpeg live-to-HLS** relay (video copy, ses AAC) daha doğru araç.
- Indie için **tek VPS + Caddy/nginx + Go/Node relay + FFmpeg** Cloudflare edge transcoding'den düşük maliyet ve daha öngörülebilir latency (edge CPU sınırlı/ pahalı).

### Gaps
- Cloudflare Stream **canlı** IPTV re-stream fiyat/limitleri bu araştırmada derinleştirilmedi.

---

## Ticari OTT (VOD vs canlı) kalıpları

### Takeaway
OTT genelde **upstream encode** (H.264/AAC veya çoklu ABR ladder) + **origin packaging** (HLS/DASH/CMAF) + CDN. "Edge transcoding" çoğu zaman **ABR paketleme ve cache**, kullanıcı başına gerçek zamanlı FFmpeg değil. Canlıda origin transcoder (Elemental, Harmonic vb.) veya **just-in-time packager**; VOD'da **batch MediaConvert** + CloudFront.

### Cited Findings
- AWS VOD: S3 upload → Lambda → MediaConvert HLS paketleri → CloudFront — [AWS serverless VOD blog](https://aws.amazon.com/blogs/networking-and-content-delivery/serverless-video-on-demand-vod-workflow/)
- MediaConvert ABR: her çıktı HLS paketinde bir rendition — [AWS MediaConvert ABR outputs](https://docs.aws.amazon.com/mediaconvert/latest/ug/outputs-file-ABR.html)

### Inferences
- IPTV paneli çoğu zaman OTT kadar **normalize edilmiş ladder** sunmaz; web uyumu istemci veya ara katmanda çözülür.
- Ticari ölçekte maliyet **depolama + CDN çıkışı + önceden encode**; indie relay'de maliyet **CPU dakikası × eşzamanlı izleyici**.

### Gaps
- Netflix/YouTube özel edge transcode mimarileri kamu kaynakta yeterince detaylı değil; genelleme sınırlı.

---

## Maliyet ve gecikme: VOD vs canlı

### Takeaway
| Mod | CPU | Tipik başlangıç gecikmesi | Bant genişliği |
|-----|-----|---------------------------|----------------|
| Remux (copy/copy) | Çok düşük | ~0–2 sn (HLS ilk segment) | Kaynak bitrate × 1 |
| Ses transcode only | Düşük–orta; genelde 1× realtime üstü | +1–6 sn | Benzer veya biraz düşük |
| Video transcode | Yüksek; HW şart (canlı) | Canlı: segment süresi (3–6 sn); VOD: pre-buffer veya progressive | Çıkış bitrate'e bağlı |

### Cited Findings
- Jellyfin remux RPi3 bile yeterli sayılır; video transcode HDR'de çok ağır — [Jellyfin Transcoding](https://jellyfin.org/docs/general/post-install/transcoding/)
- HLS passthrough: re-encode yok, düşük CPU — [StreamHub passthrough](https://streamhub.studio/docs/features/rtmp-passthrough)
- Stremio düşük güçlü sunucuda transcode 90% CPU — [stremio-service issue #71](https://github.com/Stremio/stremio-service/issues/71)
- Jellyfin VOD HLS segment varsayılan 6 sn: daha uzun segment = daha yavaş başlangıç — [DeepWiki Jellyfin HLS](https://deepwiki.com/lucienlmy/jellyfin/5.2-hls-streaming)

### Inferences
- **VOD**: ilk izleyici gecikmesi yüksek olabilir (FFmpeg playlist yazana kadar); cache (tam veya kısmi HLS dizini) ile ikinci istek hızlanır.
- **Canlı**: ses-only transcode ile 1× realtime korunamazsa buffer artar; **video transcode canlıda indie için riskli**.

### Gaps
- Somut $/1000 saat transcode için güncel VPS fiyatı bölgeye göre değişir; sayı verilmedi.

---

## Panel zaten .mp4 / .m3u8 varyantı sunuyor mu?

### Takeaway
**Canlı:** çoğu Xtream uyumlu panel `allowed_output_formats` içinde `m3u8` ve `ts` listeler; URL `.../live/user/pass/id.m3u8` ile üretilir — **kodek panel transcode'una bağlı** (çoğu zaman H.264/AAC değil MPEG-TS içinde AC3). **VOD:** API tek `container_extension` (mp4/mkv) verir; **ayrı HLS VOD veya "web AAC" varyantı standart değil**. M3U export `output=m3u8` canlı listesi içindir — [Xtream-Masters guide](https://xtream-masters.com/guide/xtream_codes_api_player_api_documentation.php).

### Cited Findings
- `allowed_output_formats`: ör. `["m3u8", "ts", "rtmp"]` — [Mayk IPTV API guide](https://maykiptv.com/en/xtream-codes-api-format/)
- VOD extension listesi: mp4, mkv, avi… — [IPTV patterns doc](https://github.com/worldofiptvcom/xtream-codes-api-documentation/blob/master/IPTV_PATTERNS_AND_INTEGRATIONS.md)
- py-xtream-codes: stream URL kullanıcı tarafından inşa edilir; tam link API'de yok — [xtream.py comments](https://github.com/chazlarson/py-xtream-codes/blob/master/xtream.py)

### Inferences
- SUTU web: VOD'da `.mp4` + H.264 + AAC şansını `get_vod_info` / probe ile seçmek mantıklı; değilse relay.
- Cast/Chromecast için panelden `.m3u8` denemesi (canlı path'in VOD'a uygulanması) **panel bağımlı** ve genelde belgelenmemiş (yerel proje chat notlarında hipotez olarak geçiyor; doğrulanmadı).

### Gaps
- Belirli panel yazılımlarının (XUI, Xtream UI fork) gizli transcode parametreleri kamuya kapalı; "her panel AC3→AAC yapar" iddiası doğrulanamadı.

---

## SUTU Player (indie Flutter) için pratik mimari seçenekleri ve effort/maliyet sıralaması

### Takeaway
Küçük ekip için önerilen sıra: (1) **kaynak seçimi + client capability** ile mümkün olduğunca direct HLS/MP4, (2) **kendi hafif transcode relay** (ses-only öncelik), (3) tam media server fork'u veya edge serverless — son ikisi maliyet/karmaşıklık yüksek.

### Cited Findings
- MediaFlow Proxy: Xtream + transcode + HLS proxy tek paket — [mediaflow-proxy](https://github.com/mhdzumair/mediaflow-proxy)
- Jellyfin Dynamic HLS: referans mimari — [DynamicHlsController](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Api/Controllers/DynamicHlsController.cs)

### Inferences

**A. İstemci öncelikli (effort: düşük, maliyet: ~0)**  
- Web'de önce HLS URL; VOD'da `container_extension=mp4` ve mümkünse probe (ffprobe sunucuda veya metadata API).  
- Mobil/desktop'ta VLC/native; web'de uyumsuz içerik için net UX ("web'de oynatılamaz" / relay gerekli).

**B. Kullanıcı başına veya paylaşımlı mini relay (effort: orta, maliyet: VPS $5–40/ay + trafik)**  
- Tek Docker: MediaFlow Proxy light veya özel Go servis + FFmpeg 7.  
- Politika: max eşzamanlı transcode 1–2; ses-only default.

**C. Jellyfin/Emby sadece transcode motoru olarak (effort: orta-yüksek, maliyet: VPS)**  
- IPTV katalog Jellyfin'de değilse overkill; yine de battle-tested HLS parametreleri kopyalanabilir.

**D. Threadfin (effort: düşük-orta, maliyet: düşük)**  
- Yalnızca **canlı** ve Plex/Jellyfin DVR entegrasyonu; SUTU doğrudan web oynatıcı değil.

**E. nginx-rtmp + FFmpeg exec (effort: orta)**  
- RTMP publisher'ınız varsa; HTTP Xtream için ek ingest katmanı gerekir.

**F. Cloudflare Workers/Stream (effort: yüksek, maliyet: değişken)**  
- VOD kısa klip/thumbnail veya batch normalization; **7/24 canlı transcode için uygun değil** — [Cloudflare Perspectives](https://www.cloudflare.com/perspectives/choosing-a-serverless-platform-for-video-transcoding-pipelines/).

**Önerilen effort / recurring cost sıralaması (1=en iyi indie fit):**

| Sıra | Yaklaşım | Geliştirme effort | İşletim maliyeti | Web H.264+AAC+HLS güvenilirliği |
|------|----------|-------------------|------------------|--------------------------------|
| 1 | Panel HLS + client doğrulama | Düşük | Yok | Kaynağa bağlı |
| 2 | Self-hosted ses-only FFmpeg proxy | Orta | Düşük | Yüksek |
| 3 | MediaFlow Proxy (Xtream hazır) | Düşük-orta | Düşük | Yüksek |
| 4 | Full video transcode relay (SW) | Orta | Orta-yüksek | Yüksek |
| 5 | Threadfin canlı buffer | Düşük | Düşük | Canlı için orta |
| 6 | nginx-rtmp stack | Orta | Orta | Senaryo bağımlı |
| 7 | Cloudflare Containers batch | Yüksek | Orta-yüksek | VOD odaklı |
| 8 | Jellyfin/Emby kurulumu sadece transcode | Yüksek | Orta | Yüksek ama ağır |

### Gaps
- SUTU'nun mevcut kod tabanında relay yok; uygulama mimarisi kararı ürün/ops tercihi.

---

## Özet karar ağacı (rapor yazarı için)

```
Kaynak probe
├─ Video ≠ H.264 (veya web HEVC policy kapalı) → video transcode → H.264
├─ Audio ≠ AAC (AC3/DTS/EAC3) → audio transcode → AAC (-ac 2 web default)
├─ Container ≠ MP4/fMP4/HLS uyumlu → remux veya HLS segmenter
└─ Hepsi uyumlu → direct URL (Range/HLS)
```

Tüm web istemcilerinde **AAC+H.264+HLS** garantisi için panel çıktısına güvenmek yeterli değil; **kontrol sizde değilse ara katman** (B veya C) gerekir.