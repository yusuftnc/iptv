# IPTV Uygulaması

Flutter ile geliştirilen mobil IPTV uygulaması.

## Özellikler

- **HTTP İstekleri**: Kanallar, diziler ve filmlerin listesini çeker
- **Durum Yönetimi**: Çekilen verileri saklar
- **Video Oynatıcı**: Modern ve işlevsel video oynatıcı
- **Basit ve Çekici Arayüz**: Kullanıcı dostu ve estetik tasarım
- **İçerik Depolama**: İçeriği cihaza kaydeder
- **İzleme Süresi Takibi**: Videoların izlenme süresini kaydeder ve devam etme seçeneği sunar
- **Çapraz Platform Desteği**: Android ve iOS'ta tutarlı görünüm
- **Yatay Mod**: Yalnızca yatay modu destekler
- **Splash Ekranı**: Uygulama başlangıcında gösterilen ekran
- **Giriş Ekranı**: Host, port, kullanıcı adı ve şifre girişi

## Kurulum

1. Flutter SDK'yı yükleyin: [Flutter Kurulum Rehberi](https://flutter.dev/docs/get-started/install)
2. Projeyi klonlayın:
   ```bash
   git clone https://github.com/kullaniciadi/iptv_app.git
   ```
3. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```
4. Uygulamayı çalıştırın:
   ```bash
   flutter run
   ```

## Kullanılan Paketler

- `http`: HTTP istekleri için
- `provider`: Durum yönetimi için
- `video_player`: Video oynatma için
- `shared_preferences`: Yerel depolama için

## Katkıda Bulunma

Katkıda bulunmak için lütfen [CONTRIBUTING.md](CONTRIBUTING.md) dosyasını inceleyin.

## Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakın.
