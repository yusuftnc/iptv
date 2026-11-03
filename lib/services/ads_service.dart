import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../utils/logger.dart';
import 'purchase_service.dart';

/// Alt bant ayrı. Tam ekran reklam her film ve bölüm açılışında, oynatıcıdan önce.
/// Kanal zap'ı bunu çağırmaz. Süre, çubuk ve çarpı reklamın kendisinde.
class AdsService {
  static const androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  static InterstitialAd? _ad;
  static Completer<InterstitialAd?>? _loading;
  static bool _presenting = false;

  static bool get _mobile =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static Future<void> start() async {
    if (!_mobile) return;
    try {
      await MobileAds.instance.initialize();
      _load();
    } catch (e, st) {
      Log.e('Ads', e, st);
    }
  }

  static void _load() {
    if (!_mobile || _ad != null || _loading != null) return;
    final pending = Completer<InterstitialAd?>();
    _loading = pending;
    InterstitialAd.load(
      adUnitId: Platform.isIOS ? iosInterstitialId : androidInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = null;
          _ad = ad;
          if (!pending.isCompleted) pending.complete(ad);
        },
        onAdFailedToLoad: (error) {
          Log.e('Ads', error);
          _loading = null;
          if (!pending.isCompleted) pending.complete(null);
        },
      ),
    );
  }

  /// Oynatıcı kurulmadan önce. Kapanınca video başlar. Sonraki açılış için yenisi yüklenir.
  static Future<void> showPreRoll() async {
    if (!_mobile || _presenting) return;
    final purchases = PurchaseService.instance;
    if (purchases.noAds || purchases.proFeatures) return;
    _presenting = true;
    try {
      _load();
      final ad = _ad ??
          await _loading?.future.timeout(
            const Duration(seconds: 4),
            onTimeout: () => null,
          );
      if (ad == null) return;
      _ad = null;
      final closed = Completer<void>();
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (shown) {
          shown.dispose();
          if (!closed.isCompleted) closed.complete();
        },
        onAdFailedToShowFullScreenContent: (shown, error) {
          Log.e('Ads', error);
          shown.dispose();
          if (!closed.isCompleted) closed.complete();
        },
      );
      await ad.show();
      await closed.future;
    } finally {
      _presenting = false;
      _load();
    }
  }
}
