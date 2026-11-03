import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/env.dart';
import '../utils/logger.dart';

/// Reklam ve Pro hakları. Favori ve izleme geçmişi burada durmaz.
class PurchaseService extends ChangeNotifier {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  static const noAdsId = 'no_ads';
  static const proFeaturesId = 'pro_features';
  static const removeAdsPackage = 'remove_ads';
  static const proLifetimePackage = 'pro_lifetime';
  static const upgradePackage = 'pro_upgrade_from_no_ads';

  bool ready = false;
  bool noAds = false;
  bool proFeatures = false;
  List<Package> packages = const [];
  String? loadError;

  Future<void> start() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) {
      loadError = 'Satın alma telefonda açılır. Mac uygulamasında ürün çıkmaz.';
      ready = true;
      notifyListeners();
      return;
    }
    final apiKey = _apiKey();
    if (apiKey == null) {
      Log.i(
        'Purchase',
        kDebugMode
            ? 'RevenueCat test anahtarı yok'
            : 'Yayın anahtarı yok (${Platform.isIOS ? 'appl_' : 'goog_'})',
      );
      loadError = 'Satın alma şu an açılamıyor.';
      ready = true;
      notifyListeners();
      return;
    }
    try {
      await Purchases.configure(PurchasesConfiguration(apiKey));
      Purchases.addCustomerInfoUpdateListener(_apply);
      _apply(await Purchases.getCustomerInfo());
      final offerings = await Purchases.getOfferings();
      final offering =
          offerings.current ?? offerings.getOffering('default');
      packages = offering?.availablePackages ?? const [];
      Log.i(
        'Purchase',
        'offering=${offering?.identifier} packages=${packages.map((item) => item.identifier).join(',')}',
      );
      loadError = packages.isEmpty ? 'Ürünler yüklenemedi.' : null;
    } catch (e, st) {
      Log.e('Purchase', e, st);
      loadError = 'Satın alma şu an açılamıyor.';
    }
    ready = true;
    notifyListeners();
  }

  void _apply(CustomerInfo info) {
    noAds = info.entitlements.active.containsKey(noAdsId);
    proFeatures = info.entitlements.active.containsKey(proFeaturesId);
    notifyListeners();
  }

  /// Debug: Test Store (`test_`). Release ve profile: mağaza public anahtarı.
  /// Release'e `test_` verilirse SDK diyaloğu gösterip uygulamayı kapatır.
  String? _apiKey() {
    if (kDebugMode) {
      final test = Env.revenueCatTestApiKey.trim();
      if (test.startsWith('test_')) return test;
    }
    final live = (Platform.isIOS
            ? Env.revenueCatAppleApiKey
            : Env.revenueCatGoogleApiKey)
        .trim();
    final prefix = Platform.isIOS ? 'appl_' : 'goog_';
    if (live.startsWith(prefix)) return live;
    return null;
  }

  Package? package(String id) {
    for (final item in packages) {
      if (item.identifier == id || item.storeProduct.identifier == id) {
        return item;
      }
    }
    return null;
  }

  /// Başta reklam kaldırma ve Pro. Yükseltme yalnız reklamı kaldırmış kişiye.
  List<Package> get visiblePackages {
    if (proFeatures) return const [];
    if (noAds) {
      final upgrade = package(upgradePackage);
      return upgrade == null ? const [] : [upgrade];
    }
    return [
      for (final id in [removeAdsPackage, proLifetimePackage])
        if (package(id) case final item?) item,
    ];
  }

  Future<String?> buy(Package item) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(item));
      _apply(result.customerInfo);
      return null;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return null;
      }
      return e.message ?? 'Satın alma tamamlanamadı.';
    }
  }

  Future<String?> restore() async {
    try {
      _apply(await Purchases.restorePurchases());
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Geri yükleme tamamlanamadı.';
    }
  }
}
