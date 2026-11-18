# Web AAC Proxy

Chrome bazı MKV’lerde videoyu açıp AC-3/DTS sesi sessiz bırakır. Bu proxy kaynağı FFmpeg ile alır:

- video: kopyala (`-c:v copy`)
- ses: AAC stereo
- çıkış: fragmente MP4 (tarayıcı progressive oynatır)

## Çalıştır

```bash
python3 tools/web_aac_proxy/proxy.py
```

Sağlık: http://127.0.0.1:8787/health

## Flutter web

`kIsWeb` iken oynatıcı URL’yi otomatik sarar:

`http://127.0.0.1:8787/play?src=<orijinal>`

Proxy kapalıysa film açılmaz; önce bu süreci başlat.
