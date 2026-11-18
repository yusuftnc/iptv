# Browser-native codec limits for IPTV/VOD (Matroska, AC-3, DTS, AAC, H.264) — 2025–2026

Research scope: HTML5 `<video>`, progressive file playback, and Media Source Extensions (MSE) in Chrome, Safari, and Firefox. Not native apps, not Chromecast receivers unless noted for contrast.

---

## Which containers and audio codecs does Chrome support for progressive download and MSE?

### Takeaway
Chrome distinguishes **native progressive playback** (single URL / file) from **MSE streaming**. Progressive playback can use **Matroska (MKV)** and a wider codec set via FFmpeg plus optional OS decoders; **MSE is essentially fMP4, WebM, and MPEG-2 TS (for HLS)** — not MKV. For IPTV-style stacks, assume **H.264 + AAC in fragmented MP4 or WebM (VP9/AV1 + Opus/AAC)** for MSE; MKV direct URLs are a separate path.

### Cited Findings
- Chromium documents supported playback containers as **MP4, Ogg, WebM, WAV, Matroska, and HLS**; open audio includes FLAC, MP3, Opus, PCM variants, Vorbis; open video includes AV1, VP8, VP9; **Chrome-branded builds** add proprietary **AAC, xHE-AAC (OS-dependent), H.264, and HEVC (hardware-dependent)** — [Chromium Audio/Video](https://www.chromium.org/audio-video/).
- MDN describes MSE as enabling plugin-free streaming with runtime container/codec checks; the **common MSE baseline** called out in documentation is **H.264 + AAC + MP4 (ISO-BMFF / fragmented MP4)** — [MDN: Media Source Extensions API](https://developer.mozilla.org/en-US/docs/Web/API/Media_Source_Extensions_API).
- **`MediaSource.isTypeSupported("video/x-matroska")` returns `false` in Chromium** (tested through Firefox’s cross-browser MSE Matroska bug, Chromium 142) even when the same codecs work in a plain `<video src="file.mkv">` — [Mozilla bug 1988447](https://bugzilla.mozilla.org/show_bug.cgi?id=1988447).
- Chromium landed **native Matroska MIME support** for inline `<video>` playback (not merely download), wiring MKV audio/video codec allowlists parallel to MP4 (including conditional AC-3/E-AC-3/DTS entries behind build flags) — [Chromium commit d081300](https://github.com/chromium/chromium/commit/d0813004e27eb2f679dd4a9e26a13baeac4be9f2).
- **`enable_platform_ac3_eac3_audio` in current Chromium `media_options.gni` defaults to on only for Cast media devices and tvOS**, not desktop Chrome (`proprietary_codecs && (is_cast_media_device || (is_ios && target_platform == "tvos"))`); **`enable_platform_dts_audio` defaults to `false`** — [Chromium `media/media_options.gni`](https://raw.githubusercontent.com/chromium/chromium/main/media/media_options.gni).
- Jellyfin’s maintained browser matrix (community-tested, useful as a practical summary) lists **Chrome/Edge/Firefox: AAC yes; AC-3/E-AC-3 no in Chrome and Firefox, yes in Edge and Safari; DTS no across Chrome/Firefox/Safari desktop** — [Jellyfin codec-support.md](https://github.com/jellyfin/jellyfin.org/blob/master/docs/general/clients/codec-support.md).
- For HLS in Chrome, **`enable_hls_demuxer`** is tied to proprietary codecs; MSE MPEG-2 TS parsing is enabled when HLS demuxer is on — same `media_options.gni` file above.

### Inferences
- **Progressive Chrome:** MKV + H.264 is a supported *container + video* combination when codec allowlists match; audio must be a decoder Chrome actually ships (AAC, Opus, MP3, FLAC, etc.), not DTS/AC-3 on typical desktop Chrome builds.
- **MSE Chrome:** IPTV web players (hls.js, mpegts.js, DASH) feed **MP4/WebM (and TS via HLS)** byte streams; remux/transcode is required for unsupported inner codecs even if the same bytes play via progressive MKV.
- **HEVC in Chrome** remains **platform/hardware gated** (Chromium proprietary list + MDN HEVC browser table) — [MDN Web video codec guide](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Video_codecs).

### Gaps
- Exact **shipping** Chrome version that enabled desktop progressive MKV for all platforms (commit is in main; release blog not fetched).
- Whether **any** Google Chrome release channel on Windows enables AC-3 independently of Edge (Chromium sources suggest desktop flag off; Edge may use Microsoft-specific build args — not verified from Edge source in this research pass).

---

## Does Safari support AC-3 while Chrome does not?

### Takeaway
**Yes on Apple platforms for typical Safari users:** Safari’s native media stack and HLS authoring path include **AC-3 and E-AC-3** in **fragmented MP4 and MPEG-2 TS**. **Desktop Chrome does not reliably decode AC-3/E-AC-3** in HTML5/MSE in official builds; **Microsoft Edge on Windows** is the main Chromium-class browser with documented Dolby Digital(+) support. Safari vs Chrome is therefore **both codec licensing/build flags and OS integration**, not merely container format.

### Cited Findings
- Apple’s HLS authoring spec lists packed audio MIME types **`audio/ac3`** and **`audio/eac3`** alongside AAC/MP3 — [Apple HLS Authoring Specification](https://developer.apple.com/streaming/hls-authoring-specification-for-apple-devices.html).
- Apple documents HLS deployment with **“fragmented MPEG-4 … HEVC or H.264 video and AAC or AC-3 audio”** — [Apple: Deploying a Basic HLS Stream](https://developer.apple.com/documentation/http-live-streaming/deploying-a-basic-http-live-streaming-hls-stream).
- Dolby’s HTML5 browser support page states **Safari 10+ on macOS reports `canPlayType` “probably/maybe” for Dolby** and **Chrome 54 does not** on the same comparison table (page is older but still cited by Dolby) — [Dolby: Browser support](https://developer.dolby.com/platforms/html5/browser-support).
- Dolby’s macOS OS/browser matrix marks **Safari 13.1 / macOS 10.15.4** with **Native Playback Path** for Dolby Digital (.ac3); **Chrome 80 on same OS** is listed only under **Media Source `isTypeSupported`** columns, not native path — [Dolby: OS and Device Support](https://developer.dolby.com/platforms/apple/macos/os-support).
- **mpegts.js maintainer (2024):** “ac-3 / ec-3 audio are supported by **Safari (MacOS) / Edge (Windows)**, **not supported by Chrome**” for MSE — [mpegts.js issue #209](https://github.com/xqq/mpegts.js/issues/209).
- Chromium integrates AC-3/E-AC-3 decoding code paths for **Windows/macOS via platform decoders**, but **`enable_platform_ac3_eac3_audio` is not enabled for desktop Chrome builds** in current GN defaults — [`media_options.gni`](https://raw.githubusercontent.com/chromium/chromium/main/media/media_options.gni); optional custom builds require `enable_platform_ac3_eac3_audio = true` — [enable-chromium-ac3-ec3-system-decoding](https://github.com/cjw1115/enable-chromium-ac3-ec3-system-decoding).
- Radiant Media Player (industry doc, Nov 2022) lists **AC-3/EC-3 HTML5/MSE support: Edge 79+ Windows, macOS Safari 11+, iOS Safari 12+** — not Chrome desktop — [Radiant: AC-3/EC-3 support](https://www.radiantmediaplayer.com/docs/v9/hevc-support.html).

### Inferences
- **Safari + HLS/MPEG-TS** is the natural path for IPTV AC-3 on Apple TV/macOS/iOS without transcoding, when manifests expose AAC fallbacks or the client picks an AC-3 variant.
- **Chrome users on macOS** do not get AC-3 in the browser even though **macOS has long shipped AC-3 system decoders** — browser support is a product/build choice, not OS capability alone.

### Gaps
- Up-to-date **Dolby matrix for Safari 17/18 + Chrome 130+** (Dolby pages mix “coming soon” and dated browser versions).
- **Chrome on Android** AC-3 passthrough/decode (GN mentions Android in passthrough flags) vs desktop — not fully traced here.

---

## Can MKV demux work in Chrome while AC-3 audio fails?

### Takeaway
**Yes.** That pattern matches how Chromium’s pipeline works: the **demuxer can expose H.264 video** from Matroska while the **audio track fails decoder setup** for AC-3, DTS, or TrueHD. The element often **continues video with silent output** rather than failing entirely—exact UX depends on track selection and error handling.

### Cited Findings
- Chromium lists **Matroska** as a supported playback container and adds **MKV-specific codec sets** (H.264, HEVC, VP8/9, AV1; AAC in proprietary builds; AC-3/E-AC-3/DTS behind `ENABLE_PLATFORM_*` build flags in mime util) — [Chromium Audio/Video](https://www.chromium.org/audio-video/); [commit d081300](https://github.com/chromium/chromium/commit/d0813004e27eb2f679dd4a9e26a13baeac4be9f2).
- With **`enable_platform_ac3_eac3_audio` off** on desktop Chrome, MKV files containing **H.264 + AC-3** are plausible **video-only in `<video>`** — consistent with Jellyfin marking **AC-3 unsupported in Chrome** — [Jellyfin codec-support.md](https://github.com/jellyfin/jellyfin.org/blob/master/docs/general/clients/codec-support.md).
- Firefox 160 release notes (third-party summary of Mozilla support list): **MKV video (H.264/HEVC/VP9/AV1) plays**; **AC-3, E-AC-3, DTS, TrueHD in MKV: not supported** → **blank player, no sound, or download prompt** — [free-codecs.com: Firefox 160 MKV](https://www.free-codecs.com/news/firefox-160-now-plays-mkv-files-with-flac-and-mp3-audio-what-still-won-t-play-and-the-fix.htm).
- Codec probing tooling documents that **the same HEVC string may work in MP4 but not MKV in API checks**, and **`canPlayType('video/x-matroska')` returns `"maybe"` in Chrome** (container recognized, codec combo not guaranteed) — [codecprobe README](https://github.com/NoFear0411/codecprobe/blob/main/README.md).
- **MSE cannot use MKV byte streams** in Chromium (`isTypeSupported` false); MKV demux for streaming in JS players requires **client-side remux to fMP4/WebM** or server transcode — [Mozilla bug 1988447](https://bugzilla.mozilla.org/show_bug.cgi?id=1988447); ffprobe/MIME note that **`video/x-matroska; codecs=…` may fail MSE while `video/mp4; codecs=…` passes after remux** — [ffmime README](https://github.com/junka/ffmime/).

### Inferences
- **MKV + AAC (or Opus) + H.264** → likely full A/V in Chrome progressive playback.
- **MKV + AC-3/DTS + H.264** → likely **video-only on Chrome/Firefox**; **Safari may play both** if AC-3 decode is available; **Edge on Windows** may play AC-3 in MP4/MSE contexts.
- IPTV “some files have sound, some don’t” in the **same container** is almost always **inner audio codec**, not MKV demux failure.

### Gaps
- Official Chromium documentation of **per-track fallback behavior** (mute vs `MEDIA_ERR_DECODE`) when only one track is unsupported — behavior inferred from community reports, not a primary spec.

---

## What do YouTube and Netflix actually serve to browsers?

### Takeaway
Major SVOD/UGC sites **do not rely on MKV or raw AC-3/DTS in the browser**. They use **adaptive streaming (MPEG-DASH or HLS) with codec ladders**: **H.264 + AAC** as universal fallback; **VP9 or AV1 + Opus/AAC** for efficiency; **Dolby variants only where the browser/OS advertises support** (often via HLS/MP4, not MKV). Players select renditions with MSE or native HLS.

### Cited Findings
- YouTube moved default playback to **HTML5 + MSE + MPEG-DASH**, offering **H.264 and VP9** (Google case study, 2015-era but foundational) — [YouTube HTML5/VP9 case study PDF](https://developers.google.com/media/pdf/Youtube-HTML5-VP9-Case-Study.pdf).
- YouTube’s `streamingData` API surface exposes **`adaptiveFormats`**: separate **video (H.264, VP9, AV1)** and **audio (AAC, Opus)** streams with signed URLs — [Medium analysis of Innertube API](https://kuangbyte.medium.com/peeking-behind-the-curtain-decoding-youtubes-api-design-through-network-traffic-e3a68463df05).
- Wikipedia (citing Streaming Media / industry coverage) summarizes YouTube as using **VP9 and H.264/AVC via DASH**, rolling **AV1** for popular content; **stereo: Opus or AAC**; **5.1: Dolby Digital/Dolby Digital Plus, rarely DTS Express** — [List of YouTube features](https://en.wikipedia.org/wiki/List_of_YouTube_features).
- Netflix Tech Blog (2025): **~30% of Netflix streaming is AV1**; **H.264/AVC remains foundational fallback**; **dav1d software decode powers ~40% of Netflix browser AV1 playback** — [Netflix: AV1 now powering 30% of streaming](https://netflixtechblog.com/av1-now-powering-30-of-netflix-streaming-02f592242d80).
- Streaming Media interview summary: Netflix selects codec **per device decoder support**, **AVC fallback when nothing else works** — [Streaming Media: Is AVC finally fading?](https://www.streamingmedia.com/Articles/ReadArticle.aspx?ArticleID=163322).
- MDN practical web recommendation for broad compatibility: **AV1+Opus in WebM with H.264+AAC MP4 fallback** — [MDN Web video codec guide](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Video_codecs).

### Inferences
- Browser IPTV products that mirror **YouTube/Netflix architecture** should plan on **fMP4/WebM + MSE/HLS**, not MKV progressive URLs, unless targeting **Safari-native HLS with multi-codec manifests**.
- **AC-3 in browser SVOD** appears as **packaged streaming renditions** (HLS/fMP4), not as MKV downloads—aligned with Dolby’s guidance to **include AAC fallback renditions** — [Radiant: AC-3/EC-3 support](https://www.radiantmediaplayer.com/docs/v9/hevc-support.html).

### Gaps
- **Netflix exact browser manifest codec strings** (proprietary player; public blog does not list per-browser AC-3 adoption rates in 2025).
- **YouTube Dolby/JOC usage rate** in browser vs TV apps (Wikipedia is secondary).

---

## Why do some MKV files play with audio and others play video-only? (Firefox & Safari included)

### Takeaway
**Container support ≠ audio codec support.** MKV is only a shell; browsers gate **each track’s codec**. Mixed libraries (IPTV/VOD rips) therefore split into “plays fine” (**H.264 + AAC/Opus**) vs “silent video” (**H.264 + AC-3/DTS/TrueHD**). **APIs disagree:** `canPlayType` may say `"maybe"` for `video/x-matroska` while a specific AC-3 track still cannot decode.

### Cited Findings
- Firefox **enabled MKV by default from Firefox 145** for **regular playback only** (not MSE/MediaRecorder) — [Mozilla dev-platform intent to ship](https://www.mail-archive.com/dev-platform@mozilla.org/msg01623.html); tracks **H.264/AAC/Opus/Vorbis/FLAC/MP3** expansions in Firefox 160 summary — [free-codecs.com Firefox 160](https://www.free-codecs.com/news/firefox-160-now-plays-mkv-files-with-flac-and-mp3-audio-what-still-won-t-play-and-the-fix.htm).
- Mozilla meta bug: MKV in `<video>` **does not imply MSE**; Matroska is **not** in the MSE byte-stream registry plan (RESOLVED WONTFIX for MSE Matroska) — [Mozilla bug 1988447](https://bugzilla.mozilla.org/show_bug.cgi?id=1988447).
- **Safari: H.264 MP4 and HLS** are first-class; Apple does not document MKV for web — [Delivering Video Content for Safari](https://developer.apple.com/documentation/webkit/delivering-video-content-for-safari.md). Mozilla notes **Chromium supports Matroska; Safari does not** — [Mozilla intent to ship MKV](https://www.mail-archive.com/dev-platform@mozilla.org/msg01623.html).
- Lumastra reference (self-hosted streaming): **direct file** when codecs match; **native HLS on Safari** enables **AC-3/E-AC-3**; **Chrome/Firefox web path transcodes AC-3 to AAC for MSE HLS** — [Lumastra codec support](https://lumastra.org/reference/codec-support/).
- Synology forum pattern (representative user report): **HTML5 player silent/fails on DTS in browser; VLC works** — DTS not in browser decode lists — [Synology forum thread](https://www.synology-forum.de/threads/das-videoformat-wird-von-mein-computer-nicht-unterstuetzt.83257/).

### Inferences
| Scenario | Chrome / Firefox | Safari | Edge (Windows) |
| --- | --- | --- | --- |
| MKV, H.264, AAC | Generally plays (progressive) | MKV often **no**; same codecs in **MP4/HLS** yes | MKV similar to Chrome; AAC OK |
| MKV, H.264, AC-3 | **Video common, no AC-3 decode** | MKV unlikely; **AC-3 in HLS/fMP4 yes** | **AC-3 often yes** (platform); see Edge regressions |
| MKV, H.264, DTS | **Video only** | **No DTS decode** | **No DTS** (typical Jellyfin matrix) |
| MSE IPTV (TS/fMP4) | H.264+AAC; transcode AC-3 | Native HLS multi-audio | AC-3 in MSE with detection |

### Gaps
- Quantitative **% of IPTV MKV files by audio codec** (project-specific; not in public web specs).
- **Safari on visionOS / latest TV Safari** MKV exceptions (none found in Apple docs).

---

## Cross-browser quick reference (HTML5, 2025–2026)

| Capability | Chrome (desktop) | Firefox | Safari |
| --- | --- | --- | --- |
| MKV progressive `<video>` | Supported (Chromium container list; recent Matroska landing) | Supported default ≥145 (limited codecs) | Not documented / treat as unsupported |
| MKV via MSE | No (`video/x-matroska` unsupported) | No | No |
| H.264 | Yes (proprietary build) | Yes (where OS/ffmpeg enables) | Yes |
| AAC | Yes | Yes | Yes |
| AC-3 / E-AC-3 | **No** (typical desktop build) | **No** | **Yes** (native/HLS/fMP4) |
| DTS | **No** (`enable_platform_dts_audio=false`) | **No** | **No** |
| HEVC | Hardware/OS gated | Similar gating (see MDN) | Yes (Apple devices) |
| Primary streaming stack | MSE DASH/HLS (fMP4/WebM/TS) | MSE; HLS via JS | **Native HLS** + fMP4 |

Sources: table synthesized from [Chromium Audio/Video](https://www.chromium.org/audio-video/), [`media_options.gni`](https://raw.githubusercontent.com/chromium/chromium/main/media/media_options.gni), [Jellyfin codec-support.md](https://github.com/jellyfin/jellyfin.org/blob/master/docs/general/clients/codec-support.md), [Mozilla MKV intent](https://www.mail-archive.com/dev-platform@mozilla.org/msg01623.html), [Apple HLS spec](https://developer.apple.com/streaming/hls-authoring-specification-for-apple-devices.html).