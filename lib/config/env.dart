import 'package:envied/envied.dart';

part 'env.g.dart';

/// Derleme zamanında `assets/.envied` okunur; gizli değerler `env.g.dart` içinde obfuscate edilir.
/// `assets/.envied` repoda olmamalı — `assets/.envied.example` dosyasını kopyalayın.
@Envied(path: 'assets/.envied', obfuscate: true)
abstract class Env {
  @EnviedField(varName: 'CREDENTIALS_SECRET')
  static final String credentialsSecret = _Env.credentialsSecret;

  /// Yedek: yalnız `goog_` / `appl_` yokken debug'da. `test_` ile başlar.
  /// Release bu anahtarla açılırsa RevenueCat uygulamayı kapatır.
  @EnviedField(varName: 'REVENUECAT_TEST_API_KEY')
  static final String revenueCatTestApiKey = _Env.revenueCatTestApiKey;

  /// App Store public SDK anahtarı. `appl_` ile başlar. Secret (`sk_`) değildir.
  @EnviedField(varName: 'REVENUECAT_APPLE_API_KEY', defaultValue: '')
  static final String revenueCatAppleApiKey = _Env.revenueCatAppleApiKey;

  /// Play Store public SDK anahtarı. `goog_` ile başlar. Secret (`sk_`) değildir.
  /// Doluysa debug dahil Play hesabı / geri yükleme bu anahtarla çalışır.
  @EnviedField(varName: 'REVENUECAT_GOOGLE_API_KEY', defaultValue: '')
  static final String revenueCatGoogleApiKey = _Env.revenueCatGoogleApiKey;
}
