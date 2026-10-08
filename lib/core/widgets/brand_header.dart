import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_logo.dart';
import '../theme/glass_tokens.dart';

/// The brand mark on the auth screens: a glass medallion holding the crescent,
/// wrapped in a slowly rotating conic halo and a breathing glow.
class BrandHeader extends StatefulWidget {
  const BrandHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  State<BrandHeader> createState() => _BrandHeaderState();
}

class _BrandHeaderState extends State<BrandHeader>
    with TickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _breathe.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft glow pooling behind the mark.
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.16),
                      scheme.primary.withValues(alpha: 0),
                    ],
                    stops: const [0.55, 1],
                  ),
                ),
              ),
              // Rotating hairline ring — a comet of light circling the mark.
              AnimatedBuilder(
                animation: _spin,
                builder: (context, _) => CustomPaint(
                  size: const Size.square(126),
                  painter: _OrbitRingPainter(
                    turns: _spin.value,
                    from: scheme.primary,
                    to: scheme.secondary,
                  ),
                ),
              ),
              // Breathing medallion.
              AnimatedBuilder(
                animation: _breathe,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_breathe.value);
                  return Transform.scale(scale: 0.97 + 0.05 * t, child: child);
                },
                // The logo carries its own medallion, border and background,
                // so it replaces the green sphere rather than sitting inside
                // it — a badge within a badge reads as a mistake. Only the glow
                // stays, and only as a glow.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 40,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: const AppLogo(size: 100),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          widget.title,
          style: text.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          widget.subtitle,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// A one-pixel ring whose brightness sweeps around the circle, giving the mark
/// a sense of slow orbit without adding visual weight.
class _OrbitRingPainter extends CustomPainter {
  const _OrbitRingPainter({
    required this.turns,
    required this.from,
    required this.to,
  });

  final double turns;
  final Color from;
  final Color to;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = SweepGradient(
      colors: [
        from.withValues(alpha: 0),
        from.withValues(alpha: 0.7),
        to.withValues(alpha: 0.7),
        to.withValues(alpha: 0),
      ],
      stops: const [0, 0.25, 0.45, 0.7],
      transform: GradientRotation(turns * math.pi * 2),
    ).createShader(rect);

    canvas.drawCircle(
      rect.center,
      size.width / 2 - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter old) =>
      old.turns != turns || old.from != from || old.to != to;
}
