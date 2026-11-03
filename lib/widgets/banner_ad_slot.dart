import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/purchase_service.dart';

/// Google'ın örnek reklam birimleri. Gerçek birim kimlikleri AdMob hesabı
/// açılınca bunların yerine konur. Mağazaya bu kimliklerle çıkılmaz.
class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key});

  static const androidUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const iosUnitId = 'ca-app-pub-3940256099942544/2934735716';

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  final PurchaseService _purchases = PurchaseService.instance;
  BannerAd? _ad;
  bool _loaded = false;

  bool get _removed => _purchases.noAds || _purchases.proFeatures;

  @override
  void initState() {
    super.initState();
    _purchases.addListener(_onPurchase);
    if (!_removed) _load();
  }

  void _onPurchase() {
    if (_removed) _drop();
    if (mounted) setState(() {});
  }

  void _load() {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: Platform.isIOS
          ? BannerAdSlot.iosUnitId
          : BannerAdSlot.androidUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (!mounted || _removed) {
            loaded.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
          if (mounted) setState(() => _loaded = false);
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  void _drop() {
    _ad?.dispose();
    _ad = null;
    _loaded = false;
  }

  @override
  void dispose() {
    _purchases.removeListener(_onPurchase);
    _drop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (_removed || !_loaded || ad == null) return const SizedBox.shrink();
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
