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
    apiKey: 'AIzaSyDVb9usHmWSZReUG5nLTkUxwMymJwrN2uc',
    appId: '1:615073740306:android:d8966f41e03cc563ed8acb',
    messagingSenderId: '615073740306',
    projectId: 'iptvapp-1b319',
    storageBucket: 'iptvapp-1b319.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAcGZnWWKDhEAyFIl98306WXEdTL49m2Hw',
    appId: '1:615073740306:ios:84f8c65ea8184925ed8acb',
    messagingSenderId: '615073740306',
    projectId: 'iptvapp-1b319',
    storageBucket: 'iptvapp-1b319.firebasestorage.app',
    iosBundleId: 'com.yusuf.player',
  );
}
