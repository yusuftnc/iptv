import 'package:flutter/material.dart';

/// Uygulama ikonu kalp atışı. Spinner yerine bunu kullan.
class BrandPulseLogo extends StatefulWidget {
  const BrandPulseLogo({super.key, this.size = 84});

  final double size;

  @override
  State<BrandPulseLogo> createState() => _BrandPulseLogoState();
}

class _BrandPulseLogoState extends State<BrandPulseLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.94, end: 1.05).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.size * 0.26;
    return ScaleTransition(
      scale: _scale,
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        child: Image.asset(
          'assets/images/app_icon.png',
          width: widget.size,
          height: widget.size,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
