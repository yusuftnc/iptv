import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web için Firebase yapılandırılmadı.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Bu platformda Firebase yok.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAa1_OQXrpQX8xma0yJrkFZeDW-Jjewh6I',
    appId: '1:652529542347:android:8ae7bbc1c02b785ef7274e',
    messagingSenderId: '652529542347',
    projectId: 'player-b2e72',
    storageBucket: 'player-b2e72.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA5QJq7eTIlvCIzuu__tSNOLVvBTcn_Fcc',
    appId: '1:652529542347:ios:50974292d03bc6a7f7274e',
    messagingSenderId: '652529542347',
    projectId: 'player-b2e72',
    storageBucket: 'player-b2e72.firebasestorage.app',
    iosBundleId: 'com.yusuf.player',
  );
}
