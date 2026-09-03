import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import '../config/env.dart';

/// Kimlik bilgisi JSON'unu Env'deki obfuscate edilmiş sırla AES-GCM ile şifreler.
class CredentialCrypto {
  static final AesGcm _algorithm = AesGcm.with256bits();

  static Future<SecretKey> _secretKey() async {
    final keyBytes = sha256.convert(utf8.encode(Env.credentialsSecret)).bytes;
    return SecretKey(keyBytes);
  }

  /// Base64: nonce | ciphertext | mac (cryptography SecretBox varsayılan birleşimi).
  static Future<String> encryptJson(String jsonUtf8) async {
    final key = await _secretKey();
    final box = await _algorithm.encrypt(
      utf8.encode(jsonUtf8),
      secretKey: key,
    );
    return base64Encode(box.concatenation());
  }

  static Future<String> decryptToUtf8(String encoded) async {
    final key = await _secretKey();
    final all = base64Decode(encoded);
    final box = SecretBox.fromConcatenation(
      all,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    final clear = await _algorithm.decrypt(box, secretKey: key);
    return utf8.decode(clear);
  }
}
