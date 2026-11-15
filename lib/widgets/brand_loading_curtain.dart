import 'package:flutter/material.dart';

import 'brand_pulse_logo.dart';

/// Hafif gri perde (arkası silinmez) + uygulama ikonu kalp atışı.
class BrandLoadingCurtain extends StatelessWidget {
  const BrandLoadingCurtain({
    super.key,
    this.opaque = false,
  });

  /// Splash gibi arkada içerik yoksa hafif dolgu; HTTP overlay'de false.
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final veil = dark
        ? Colors.black.withValues(alpha: 0.38)
        : const Color(0xFF8E8E93).withValues(alpha: 0.28);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (opaque)
          ColoredBox(
            color: dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
          ),
        ColoredBox(color: veil),
        const Center(child: BrandPulseLogo(size: 84)),
      ],
    );
  }
}
