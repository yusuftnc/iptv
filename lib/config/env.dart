import 'package:envied/envied.dart';

part 'env.g.dart';

/// Derleme zamanında `assets/.envied` okunur; gizli değerler `env.g.dart` içinde obfuscate edilir.
/// `assets/.envied` repoda olmamalı — `assets/.envied.example` dosyasını kopyalayın.
@Envied(path: 'assets/.envied', obfuscate: true)
abstract class Env {
  @EnviedField(varName: 'CREDENTIALS_SECRET')
  static final String credentialsSecret = _Env.credentialsSecret;
}
