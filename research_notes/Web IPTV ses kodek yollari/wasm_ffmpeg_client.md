# Client-side WASM/FFmpeg ve alternatif demuxer çözümleri (AC-3/DTS/MKV)

**Kapsam:** Tarayıcıda HTML5 `<video>`/MSE ile oynatılamayan ses (AC-3/E-AC-3/DTS) ve konteynerler (MKV, ham MPEG-TS) için istemci tarafı yaklaşımlar; IPTV/VOD için Xtream benzeri HTTP progressive URL’lerle uyumluluk ve üretim olgunluğu.

**Özet matris (yüksek seviye):**

| Yaklaşım | Canlı TS (Xtream `.ts`) | VOD progressive (`.mkv`/`.mp4` + Range) | AC-3 Chrome | DTS Chrome | Olgunluk |
|----------|-------------------------|----------------------------------------|-------------|------------|----------|
| mpegts.js + MSE | Evet (H.264+AAC) | Sınırlı (seek yok) | Hayır (MSE yok) | Hayır | Üretim (AAC yolları) |
| ferrite.js / skyfire-player | Evet | Evet (PR’larda belirtilmiş) | Evet (WASM) | Belirsiz / genelde hayır | Erken üretim (IPTV örnekleri) |
| libav-wasm remux + MSE | TS/MKV parça parça | Evet (sadece ses transcode) | Evet (ses yeniden kodlama) | Evet (ses yeniden kodlama) | Deneysel–orta |
| Mediabunny + `@mediabunny/ac3` / `@mediabunny/dts` | Demux+decode pipeline gerekir | Evet (Range ile) | Evet | Evet (dts paketi) | Orta (MakeAudio/Leyla kullanımı) |
| ffmpeg.wasm tam transcode | Pratikte hayır (tam indirme) | Evet ama tam dosya bellekte | Evet | Evet | Deneysel (oynatma değil batch) |
| WebCodecs + web-demuxer | Mümkün (özel oynatıcı) | Evet (Range) | Hayır (WASM eklenti gerekir) | Hayır | Orta (demuxer olgun, AC-3 değil) |
| libmpv-wasm | Teorik | Teorik | Evet | Evet | Deneysel / performans zayıf |
| Broadway.js | Hayır (H.264 Baseline only) | Hayır | Hayır | Hayır | Legacy |

---

## ffmpeg.wasm progressive ağ akışlarında çalışır mı, yoksa yalnızca yerel dosyalarda mı?

### Takeaway

`ffmpeg.wasm` FFmpeg’in tarayıcı içi HTTP/TCP protokol yığınını taşımaz; giriş ya sanal dosya sistemine yazılmış tam bir blob ya da `fetchFile(url)` ile önce belleğe/FS’ye alınmış veridir. Gerçek zamanlı “pipe/HTTP `-i http://…`” ile progressive oynatma desteklenmez; Xtream tarzı uzun VOD için tam indirme + transcode desenine yakınsır, canlı TS için uygun değildir.

### Cited Findings

- ffmpeg.wasm bakımcısı HTTP input protokolünün “şimdilik mevcut olmadığını”, uzun vadeli hedef olduğunu belirtmiştir — [GitHub #108](https://github.com/ffmpegwasm/ffmpeg.wasm/issues/108#issuecomment-726716809).
- `ffmpeg.run("-i", "http://…")` ile uzaktan segment birleştirme denemelerinde “Connection refused” ve `https protocol not found` hataları; uzaktan okumanın Emscripten FS’ye yüklenmiş dosyalarla çalıştığı, akış girdisinin desteklenmediği tartışılmıştır — [GitHub #304](https://github.com/ffmpegwasm/ffmpeg.wasm/issues/304#issuecomment-704409748).
- Resmi `@ffmpeg/util` `fetchFile` HTTP(S) URL’den `arrayBuffer()` ile **tüm** yanıtı indirir; isteğe bağlı `downloadWithProgress` parça parça okur ama yine sonunda tek buffer oluşturur — [packages/util/src/index.ts](https://github.com/ffmpegwasm/ffmpeg.wasm/blob/main/packages/util/src/index.ts).
- Proje README’si paketi **“stability-experimental”** olarak işaretler; tarayıcıda multithread için `SharedArrayBuffer` ve COOP/COEP başlıkları gerekir — [README 0.11.x](https://github.com/ffmpegwasm/ffmpeg.wasm/blob/0.11.x/README.md).
- Konvrt benchmark’ı: MKV→MP4 (FLAC→AAC) `ffmpeg.wasm` ile çalışır; WebCodecs MKV demux/FLAC/AAC’yi desteklemez — [Konvrt 2026 karşılaştırması](https://konvrt.dev/blog/ffmpeg-wasm-vs-webcodecs-2026).
- Jellyfin topluluk deneyi: ~1.3 GB MKV HEVC transcode masaüstü FFmpeg’e göre ~0.5× hız (WASM), gerçek zamanlı oynatma için yetersiz — [Jellyfin Feature Request](https://features.jellyfin.org/posts/1958/leverage-client-side-wasm-mpv-or-ffmpeg-to-decode).

### Inferences

- AC-3/DTS **çözme** FFmpeg çekirdeğinde mümkün olsa da, IPTV canlı akışında ffmpeg.wasm’ın rolü pratikte **sunucu transcode yerine batch/ön-işleme** veya kısa klipler olur.
- VOD için Range ile parça indirip birleştirip sonra `writeFile` + `exec` mümkün; ancak oynatma başlamadan önce indirme/transcode gecikmesi büyüktür.
- MP4 progressive için moov atom eksikliği, parça parça wasm girdisinde “Invalid data” riski taşır (blog analizi) — [博客园 teknik özet](https://www.cnblogs.com/longmo666/p/19778666).

### Gaps

- 2025–2026 arası ffmpeg.wasm’da HTTP input için resmi bir milestone veya merged PR bulunamadı; Issue #108 hâlâ açık görünüyor.
- Varsayılan `@ffmpeg/core` derlemesinin AC-3 decoder’ı içerip içermediği sürüme göre değişir; decode-only minimal core için ayrı build dokümantasyonu net değil.

---

## mpegts.js, jmuxer, Broadway, wasm mpv ve benzeri kütüphaneler AC-3’ü açar mı?

### Takeaway

**mpegts.js** MPEG-TS’i fMP4’e transmux eder; AC-3 yolu yalnızca **tarayıcının MSE’sinin AC-3 kabul ettiği** ortamlarda işe yarar (macOS Safari, Windows Edge). **Chrome/Firefox’ta AC-3 sessiz kalır veya `addSourceBuffer` hatası verir** — demuxer değil, codec/MSE sınırıdır. **jmuxer** yalnızca H.264/H.265 + **AAC (ADTS)** muxer’dır; AC-3/DTS/TS demux yoktur. **Broadway** yalnızca H.264 Baseline yazılım çözücüsüdür; ses yoktur, AC-3 ile ilgisi yoktur. **libmpv-wasm** deneyseldir ve topluluk geri bildirimi performansı zayıftır. **ferrite.js** ve **@firemedia/skyfire-player** gibi daha yeni player’lar WASM ile AC-3/E-AC-3 çözerek Web Audio’ya verir; IPTV projelerinde (IPTVnator PR) entegrasyon örneği vardır.

### Cited Findings

- mpegts.js: HTTP(S) üzerinde canlı MPEG-TS, DVB tarzı düşük gecikme; özellik listesi H.264/H.265 + AAC; TODO hâlâ “MP3/AC3” içerir — [mpegts.js README](https://github.com/xqq/mpegts.js/blob/master/README.md).
- v1.7.3 sürüm notu “ATSC AC-3 … MPEG-TS” der; bakımcı monyone: “ac-3 / ec-3 … Safari (MacOS) / Edge (Windows) tarafından desteklenir, Chrome tarafından değil” — [Issue #209](https://github.com/xqq/mpegts.js/issues/209#issuecomment-2371175448).
- Xtream benzeri canlı `.ts?extension=ts` URL + AC-3: Chrome’da hata; maintainer aynı açıklama — [Issue #115](https://github.com/xqq/mpegts.js/issues/115#issuecomment-2371175448).
- jMuxer: girdi olarak **ham H264 + AAC ADTS** bekler; “dumb muxer”, TS demux yapmaz — [jmuxer README](https://github.com/webstream-labs/jmuxer).
- Broadway: “JavaScript H.264 decoder”; MP4/wrapper değil NAL beslemesi; Baseline/CAVLC sınırları — [Broadway README](https://github.com/mbebenita/Broadway).
- libmpv-wasm: mpv’yi WASM’da çalıştırmayı hedefler; mpv upstream issue’da WASM performansının “horrible” olduğu tartışılmıştır — [mpv #13575](https://github.com/mpv-player/mpv/issues/13575#issuecomment-1963898998).
- ferrite.js (IPTVnator): MPEG-TS/MP4/MKV; AAC/AC-3/E-AC-3/MP2/MP3; canlı+VOD; canvas+WebAudio; COOP/COEP + SharedArrayBuffer — [PR #1091](https://github.com/4gray/iptvnator/pull/1091).
- skyfire-player: MPEG-TS demux + WebCodecs video + **WASM AC-3/E-AC-3** → AudioWorklet; progressive `.ts` URL örneği — [rust-skyfire](https://github.com/fishloa/rust-skyfire).
- Jellyfin codec tablosu: Chrome’da AC-3/E-AC-3 için tik, **DTS için çarpı** (web) — [codec-support.md](https://github.com/jellyfin/jellyfin-docs/blob/master/general/clients/codec-support.md).
- IPTV-Manager: mpegts.js + AC-3 MSE hatası; çözüm olarak sunucu tarafı HLS/transcode zinciri — [PR #132](https://github.com/Bladestar2105/IPTV-Manager/pull/132).

### Inferences

- Xtream **live.php / … &extension=ts** URL’leri mpegts.js ile **H.264+AAC** için üretime yakın; **AC-3 kanallar Chrome’da istemci tarafında mpegts.js ile çözülmez** — ya Edge/Safari ya WASM player ya sunucu transcode.
- **DTS** için mpegts.js + MSE genelde işe yaramaz (Jellyfin web DTS yok); ferrite listesinde DTS yok; **Mediabunny `@mediabunny/dts`** ayrı WASM yolu sunar — [Mediabunny codec listesi](https://mediabunny.dev/guide/supported-formats-and-codecs).

### Gaps

- ferrite.js bağımsız npm dokümantasyonu ve DTS desteği resmi özellik listesinde net değil (IPTVnator PR’da DTS sayılmamış).
- libmpv-wasm’ın HTTP canlı akış ve AC-3 ile gerçek IPTV demo kanıtı sınırlı.

---

## WebCodecs + özel demux (MKV/TS) mimarisi

### Takeaway

WebCodecs ham `EncodedVideoChunk` / `EncodedAudioChunk` çözer; **konteyner demux WebCodecs’in dışındadır**. Üretime yaklaşan parçalar: **web-demuxer** (Bilibili, ffmpeg demux WASM), **libav-wasm** (Range ile akışlı remux), **avbridge** / **Mediabunny** (strateji seçimi: native → remux → hybrid → full WASM). AC-3/E-AC-3 için WebCodecs’e **native destek yok**; demux sonrası **@mediabunny/ac3**, audiojs `decode-eac3`, veya tam ffmpeg.wasm decode gerekir. MKV + HEVC + AC-3 senaryosunda yaygın desen: WASM demux → video WebCodecs (donanım) → ses WASM decode → PCM/Web Audio veya sesi AAC/Opus’a WebCodecs `AudioEncoder` ile yeniden kodlayıp MSE’ye fMP4.

### Cited Findings

- MDN: WebCodecs AAC/Opus/PCM odaklı; AC-3 listelenmez — [MDN WebCodecs](https://developer.mozilla.org/en-US/docs/Web/API/WebCodecs_API).
- `@mediabunny/ac3`: WebCodecs’te AC-3/E-AC-3 yok; FFmpeg WASM kodlayıcı/çözücü eklentisi — [Mediabunny AC-3 guide](https://mediabunny.dev/guide/extensions/ac3).
- web-demuxer: MKV/TS/FLV vb.; `getDecoderConfig`, `read()` ReadableStream; Full WASM ~1131 kB gzip — [web-demuxer](https://github.com/bilibili/web-demuxer).
- libav-wasm: `read(offset,size)` ile HTTP Range; video copy remux, **ses her zaman yeniden işlenir**; desteklenmeyen video codec’de red — [libav-wasm README](https://github.com/Banou26/libav-wasm).
- avbridge: MKV→remux, uzak URL için **Range zorunlu**; fallback WASM decode mobilde ağır — [avbridge](https://github.com/keishi/avbridge/).
- Jellyfin meta tartışması #132: istemci remux + WebCodecs video + Opus/AAC ses; **Safari’de Opus-in-MP4 MSE sorunu**; önerilen AAC çıkış varyantı — [Discussion #132](https://github.com/jellyfin/jellyfin-meta/discussions/132).
- Movi Player / DEV özet: File→WASM demux→WebCodecs; HTTP Range ile seek — [DEV.to](https://dev.to/mrujjwalg/play-hevc-av1-and-mkv-in-the-browser-with-webcodecs-no-server-transcoding-57).

### Inferences

- **Xtream VOD** (`/movie/.../id.mkv` veya `.mp4`): sunucu **Accept-Ranges** veriyorsa libav-wasm / web-demuxer + custom player ile **sunucusuz ses düzeltme** mümkün; Jellyfin hâlâ sunucu transcode’a güvenir.
- Canlı TS için demux genelde sürekli byte akışı; web-demuxer dosya/seek odaklı API’si canlıda ekstra buffer mantığı ister (Bilibili worker demux canlıda farklı ürünleştirilmiş).

### Gaps

- Tek paket halinde “drop-in Xtream player” için WebCodecs+AC-3 WASM birleşik ürün sınırlı; çoğu çok parçalı entegrasyon.
- Mediabunny ile canlı MPEG-TS AC-3 için uçtan uca açık referans IPTV demosu az.

---

## Gecikme, CPU, mobil Safari ve SharedArrayBuffer sınırları

### Takeaway

| Katman | Tipik profil |
|--------|----------------|
| mpegts.js (H.264+AAC, MSE) | Düşük CPU (~10 MiB heap/instance), &lt;1 s gecikme hedefi canlıda — [mpegts.js](https://xqq.im/mpegts.js/) |
| WASM ses decode (AC-3) | CPU hafif–orta; çok kanallı 5.1 sürekli decode uygun |
| WASM tam video decode (ferrite, ffmpeg.wasm) | CPU ağır; 4K canlı için threading + COI gerekir; M2’de ffmpeg.wasm H.264 transcode ~6 dk/ dakika video (blog) |
| Mobil Safari | iOS’ta eski sürümlerde MSE kısıtlı; mpegts.js **iOS 17.1+ ManagedMediaSource** — [README](https://github.com/xqq/mpegts.js/blob/master/README.md). SharedArrayBuffer: **iOS 15.2+** COOP/COEP ile — [WebKit 15.2](https://webkit.org/blog/12140/new-webkit-features-in-safari-15-2/), [caniuse](https://caniuse.com/sharedarraybuffer). |
| Safari AC-3 | Jellyfin: Safari’de AC-3 **native MSE** destekli — [codec-support.md](https://github.com/jellyfin/jellyfin-docs/blob/master/general/clients/codec-support.md); Chrome Android’da AC-3 tik ama DTS çoğunlukla hayır. |

### Cited Findings

- Konvrt: ffmpeg.wasm 1080p işlerde çok yüksek CPU ve ~2 GB bellek; WASM 32-bit adres uzayı pratikte ~2 GB — [Konvrt](https://konvrt.dev/blog/ffmpeg-wasm-vs-webcodecs-2026).
- ferrite: COI yoksa SharedArrayBuffer’sız degrade; Electron `file://` izole değil — [IPTVnator PR #1091](https://github.com/4gray/iptvnator/pull/1091).
- web.dev: Chrome 92+ SharedArrayBuffer için cross-origin isolation — [COOP/COEP](https://web.dev/articles/coop-coep).
- avbridge: mobilde WASM fallback decode, realtime’ın %60 altına düşerse diagnostik — [avbridge](https://github.com/keishi/avbridge/).

### Inferences

- **Mobil Chrome IPTV + AC-3:** mpegts.js yetmez; WASM ses player veya sunucu AAC transcode gerekir; threading için HTTPS + COEP hosting şartı IPTV panel CDN’lerinde operasyonel engel olabilir.
- **Mobil Safari:** AC-3 için native yol mümkün; DTS hâlâ problem (Jellyfin tablosu).

### Gaps

- ferrite.js / skyfire 4K AC-3 canlı için ölçülmüş CPU/batarya benchmark’ları kamuya açık az.
- iOS PWA’da COEP ile üçüncü parti segment URL’leri (Xtream CDN farklı origin) CORP/CORS uyumu proje bazlı test gerektirir.

---

## Lisans: AC-3 patentleri, ffmpeg.wasm (MIT vs LGPL/GPL)

### Takeaway

- **ffmpeg.wasm npm paketi MIT** olarak etiketlenir; **gömülü `@ffmpeg/core` çoğu zaman GPL bileşenleri (libx264, libx265) ile derlenir** — ticari kapalı kaynak dağıtımda risk; maintainer uyarısı: GPL core ile proprietary kullanmayın — [Issue #107](https://github.com/ffmpegwasm/ffmpeg.wasm/issues/107#issuecomment-719003163), [#902](https://github.com/ffmpegwasm/ffmpeg.wasm/issues/902).
- FFmpeg resmi uyum: GPL olmayan build, kaynak dağıtımı, LGPL metni — [ffmpeg.org/legal.html](https://ffmpeg.org/legal.html).
- **AC-3 patentleri:** ATSC temel patentlerin çoğu **2017** öncesi sona ermiş kampanya verisi — [ac3freedomday.org arşiv](https://web.archive.org/web/20170319195106/https:/ac3freedomday.org/). Leyla notices: AC-3 patent 2017; E-AC-3 son ABD patenti **2026-01-30** iddiası — [leyla.media/notices](https://leyla.media/notices).
- **@mediabunny/ac3:** LGPLv2.1+ FFmpeg build, GPL/nonfree kapalı — [packages/ac3 README](https://github.com/Vanilagy/mediabunny/blob/main/packages/ac3/README.md).
- Dolby **ticari marka** (“Dolby Digital”) UI’da kullanım ayrı konu; codec adı AC-3/E-AC-3 kullanılabilir — [Leyla notices](https://leyla.media/notices).

### Cited Findings

- videoadjust: E-AC-3 patent bölgesel doğrulama açık gap — [Issue #3](https://github.com/bradsec/videoadjust/issues/3).
- MakeAudio: AC-3 decode için FFmpeg WASM eklentisi, LGPL — [makeaudio.app](https://makeaudio.app/browser-codec-support).

### Inferences

- IPTV ürünü için **decode-only LGPL FFmpeg WASM** (Mediabunny/ac3, audiojs decode-eac3) legal checklist ile daha öngörülebilir olabilir; varsayılan **ffmpeg.wasm core (x264’lü)** GPL tuzaklarına dikkat.
- AC-3 **çözme** patent açısından 2026 itibarıyla ABD’de daha rahat; E-AC-3 için kaynaklar çelişkili olabilir — hukuki teyit gap.

### Gaps

- Türkiye/AB patent durumu için bu araştırmada birincil kaynak taranmadı.
- DTS patent/lisans (DTS, Inc.) browser WASM decode için ayrı inceleme gerekir; yalnızca `@mediabunny/dts` varlığı belgelendi.

---

## Üretim hazırlığı ve Xtream tarzı HTTP progressive URL’ler

### Takeaway

| Senaryo | Üretime en yakın istemci çözüm | Not |
|---------|----------------------------------|-----|
| Canlı `.ts` + H.264 + AAC | mpegts.js | Düşük gecikme, düşük CPU |
| Canlı `.ts` + H.264 + AC-3 (Chrome) | ferrite.js / skyfire-player / sunucu AAC transcode | WASM veya proxy; mpegts.js yetersiz |
| Canlı `.m3u8` HLS | hls.js / native Safari | Ses codec’i segment’te ne ise MSE/native’e bağlı |
| VOD `.mkv` + H.264 + AC-3 + Range | libav-wasm, avbridge, custom Mediabunny player | Tam dosya indirmeden; Jellyfin önerisi değil |
| VOD tam transcode tarayıcıda | ffmpeg.wasm | Deneysel; tam indirme; gerçek zamanlı değil |
| Plex/Jellyfin web | **Sunucu FFmpeg transcode** | İstemci WASM prod’da yok — [#132 discussion](https://github.com/jellyfin/jellyfin-meta/discussions/132), [Jellyfin AC-3 issue yorumu](https://github.com/jellyfin/jellyfin-web/issues/7546#issuecomment-2908214434) |

### Cited Findings

- Jellyfin: “Chrome and Firefox have never supported the Dolby AC3 decoder” — MKV/MP4 doğrudan oynatma için ses transcode — [Issue #7546](https://github.com/jellyfin/jellyfin-web/issues/7546#issuecomment-2908214434).
- xsukax IPTV Player: Xtream API; M3U8 + “MP4/MKV” VOD; HLS.js; sunucu tarafı işlem yok iddiası — ses codec garantisi belirtilmemiş — [GitHub](https://github.com/xsukax/xsukax-IPTV-Player/).
- Bevara universal-audio: liba52 WASM ile `.ac3` dosyası — [demo](https://bevara.github.io/Showcase/liba52/).

### Inferences

- **Progressive Xtream movie URL’leri** (`…/movie/user/pass/stream_id.mkv`): Range destekliyorsa **libav-wasm / web-demuxer tabanlı** mimari sunucu transcode’dan daha ucuz CPU profili sunar; Range yoksa istemci çözümleri pratikte çökmez veya tam indirme gerekir.
- **Üretim önerisi (Chrome odaklı IPTV):** (1) HLS proxy + AAC ses sunucuda, veya (2) ferrite/skyfire sınıfı WASM player + COI hosting, veya (3) hybrid: Safari’de direct AC-3 MSE, Chrome’da WASM ses katmanı.
- **Plex web** için bu taramada ayrıntılı istemci WASM notu bulunamadı; sektör normu sunucu transcode (Jellyfin ile paralel varsayım).

### Gaps

- Xtream sağlayıcıların çoğunun VOD URL’lerinde `Accept-Ranges` ve moov-at-start varyasyonu sistematik ölçülmedi.
- Broadway / libmpv-wasm IPTV üretim yolu olarak önerilmemeli (legacy / performans).

---

## Karar ağacı (rapor yazarı için)

```
URL tipi?
├─ Canlı MPEG-TS (.ts)
│  ├─ Ses AAC → mpegts.js (prod)
│  ├─ Ses AC-3 + Chrome → WASM player (ferrite/skyfire) VEYA sunucu transcode
│  └─ Ses DTS → Mediabunny/dts veya sunucu transcode (MSE yok)
├─ HLS (.m3u8)
│  └─ hls.js; AC-3 segment → Chrome'da genelde sunucu AAC
└─ VOD MKV/MP4 progressive
   ├─ Range var + H.264 video → remux (libav-wasm/avbridge) + WASM ses decode
   └─ Range yok / canlı benzeri → sunucu veya tam indirme + ffmpeg.wasm (batch)
```

**Son güncelleme bağlamı:** Bulgular 2024–2026 GitHub issue/PR’leri, Mediabunny/Leyla/ffmeg.wasm dokümantasyonu ve codec destek tablolarına dayanır; ffmpeg.wasm HTTP input hâlâ açık issue seviyesinde.