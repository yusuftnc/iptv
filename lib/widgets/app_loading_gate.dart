import 'dart:async';

import 'package:flutter/material.dart';

import 'brand_loading_curtain.dart';

/// IPTV HTTP beklerken hafif perde. Ref-count.
///
/// Tek yol: [whileBusy] — istek başında +1, bitince (finally) -1.
/// Görünüm [MaterialApp.builder] içindeki [AppLoadingOverlay] ile.
class AppLoadingGate {
  AppLoadingGate._();

  static int _depth = 0;
  static Timer? _hideTimer;
  static final ValueNotifier<int> listenable = ValueNotifier<int>(0);

  static bool get isBlocking => listenable.value > 0;

  static void push() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _depth++;
    if (listenable.value == 0) listenable.value = _depth;
  }

  static void pop() {
    if (_depth <= 0) return;
    _depth--;
    if (_depth == 0) {
      // Ardışık katalog isteklerinde logo yanıp sönmesin.
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(milliseconds: 160), () {
        if (_depth == 0) listenable.value = 0;
      });
    }
  }

  static Future<T> whileBusy<T>(Future<T> Function() action) async {
    push();
    try {
      return await action();
    } finally {
      pop();
    }
  }
}

/// Kök [MaterialApp.builder] içine konur; depth>0 iken perde çizer.
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppLoadingGate.listenable,
      builder: (context, depth, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (depth > 0) ...[
              const ModalBarrier(
                dismissible: false,
                color: Colors.transparent,
              ),
              const BrandLoadingCurtain(opaque: false),
            ],
          ],
        );
      },
    );
  }
}
