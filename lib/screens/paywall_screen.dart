import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/app_settings.dart';
import '../services/purchase_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final PurchaseService _purchases = PurchaseService.instance;
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final message = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: context.accent,
        title: const Text('Pro'),
      ),
      body: ListenableBuilder(
        listenable: _purchases,
        builder: (context, _) {
          if (!_purchases.ready) {
            return const Center(child: CircularProgressIndicator());
          }
          final packages = _purchases.visiblePackages;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              if (_purchases.proFeatures || _purchases.noAds)
                const _StatusCard(
                  title: 'Pro açık',
                  body:
                      'Aboneliğin süresince reklamlar kapalı, Pro özellikler açık.',
                ),
              if (_purchases.loadError != null) ...[
                Text(
                  _purchases.loadError!,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              for (final item in packages) ...[
                _PackageCard(
                  item: item,
                  busy: _busy,
                  onBuy: () => _run(() => _purchases.buy(item)),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              if (_purchases.configured)
                TextButton(
                  onPressed: _busy ? null : () => _run(_purchases.restore),
                  child: const Text('Satın almaları geri yükle'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(body, style: TextStyle(color: palette.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.item,
    required this.busy,
    required this.onBuy,
  });

  final Package item;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final copy = _copy(item);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              copy.title,
              style: TextStyle(
                color: palette.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(copy.body, style: TextStyle(color: palette.muted)),
            const SizedBox(height: 14),
            FilledButton(
              style: context.primaryButtonStyle,
              onPressed: busy ? null : onBuy,
              child: Text(item.storeProduct.priceString),
            ),
          ],
        ),
      ),
    );
  }

  static ({String title, String body}) _copy(Package item) {
    if (_is(item, PurchaseService.proYearlyPackage)) {
      return (
        title: 'Yıllık Pro',
        body: 'Bir yıl reklamsız. Tüm Pro özellikler açık.',
      );
    }
    return (
      title: 'Aylık Pro',
      body: 'Her ay yenilenir. Reklamsız ve tüm Pro özellikler.',
    );
  }

  static bool _is(Package item, String id) {
    return item.identifier == id || item.storeProduct.identifier == id;
  }
}
