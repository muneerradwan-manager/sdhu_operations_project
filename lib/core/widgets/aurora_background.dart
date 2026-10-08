import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';

/// The backdrop the whole app sits on: a mesh of colour orbs over a deep
/// gradient, finished with a fine grain so the glass panes above it have
/// something with texture to refract.
///
/// Mounted once in [MaterialApp.builder], so every route inherits it and route
/// transitions never flash a flat background.
///
/// The orbs used to drift on a 32-second loop. They no longer move: a backdrop
/// that is never the thing being looked at was repainting the entire viewport
/// at refresh rate for the app's whole life, which is a frame budget that
/// belongs to whatever the user is actually scrolling. The field is held on
/// [_stillFrame] — the same still frame the OS "reduce motion" switch used to
/// pin it to — so the colour and depth are unchanged and only the motion is
/// gone. That also makes the widget stateless: no ticker, and nothing to stop
/// and restart across app lifecycle changes.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  /// Where in the old drift loop the field is frozen. Nothing is special about
  /// the value beyond it being a pleasant arrangement of the orbs — it is the
  /// one the reduce-motion path already chose.
  static const _stillFrame = 0.18;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Flat under the glass-free tokens, and it costs nothing to ask: the token
    // set IS the mode, so nothing had to be threaded down here.
    //
    // Two orbs and a grain field are a picture to resolve, and this mode exists
    // to give the eye fewer of those — under a sun the panes are opaque anyway,
    // so what the orbs light is the gaps between cards and nothing else. The
    // two CustomPaints also go, which is the point on a slow handset: they are
    // repainted whenever the page behind them changes size.
    if (context.glass.reduced) {
      return Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: isDark ? AppColors.nightMid : AppColors.paperMid,
            ),
          ),
          child,
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _baseGradient(isDark)),
              child: CustomPaint(
                painter: _AuroraPainter(t: _stillFrame, isDark: isDark),
                isComplex: true,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _GrainPainter(isDark: isDark)),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  /// The field the orbs drift over.
  ///
  /// Slightly diagonal, and that is the whole of what a wide window needed. A
  /// strictly vertical gradient gives every pixel on a row the same colour —
  /// unnoticeable down a phone, where a row is 390 wide, and on a monitor a
  /// flat band two and a half thousand pixels across, repeated all the way
  /// down. Tilting it costs nothing at portrait aspect and gives the width
  /// somewhere to fall away to.
  LinearGradient _baseGradient(bool isDark) {
    const begin = Alignment(-0.5, -1);
    const end = Alignment(0.5, 1);
    return isDark
        ? const LinearGradient(
            begin: begin,
            end: end,
            colors: [
              AppColors.nightTop,
              AppColors.nightMid,
              AppColors.nightEnd,
            ],
            stops: [0, 0.55, 1],
          )
        : const LinearGradient(
            begin: begin,
            end: end,
            colors: [
              AppColors.paperTop,
              AppColors.paperMid,
              AppColors.paperEnd,
            ],
            stops: [0, 0.6, 1],
          );
  }
}

/// One drifting light source in the mesh.
class _Orb {
  const _Orb({
    required this.color,
    required this.center,
    required this.radius,
    required this.drift,
    required this.speed,
    required this.phase,
  });

  final Color color;

  /// Rest position in Alignment space (-1..1).
  final Alignment center;

  /// Radius as a fraction of the viewport's longest side.
  final double radius;

  /// Travel distance in Alignment space.
  final Offset drift;

  final double speed;
  final double phase;
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.t, required this.isDark});

  final double t;
  final bool isDark;

  static const _darkOrbs = <_Orb>[
    _Orb(
      color: AppColors.lightGreen,
      center: Alignment(-0.8, -0.85),
      radius: 0.62,
      drift: Offset(0.35, 0.22),
      speed: 1,
      phase: 0,
    ),
    _Orb(
      color: AppColors.mediumGreen,
      center: Alignment(0.95, -0.45),
      radius: 0.55,
      drift: Offset(-0.3, 0.3),
      speed: 0.75,
      phase: 1.7,
    ),
    _Orb(
      color: AppColors.darkGold,
      center: Alignment(0.6, 0.9),
      radius: 0.5,
      drift: Offset(-0.35, -0.2),
      speed: 0.6,
      phase: 3.1,
    ),
    _Orb(
      color: AppColors.mediumRed, // depth in the shadows
      center: Alignment(-0.85, 0.75),
      radius: 0.46,
      drift: Offset(0.28, -0.26),
      speed: 0.9,
      phase: 4.6,
    ),
  ];

  // Tighter than the dark set: over a bright base, a wide orb flattens into a
  // uniform wash instead of reading as a pool of colour.
  static const _lightOrbs = <_Orb>[
    _Orb(
      color: AppColors.lightGreen,
      center: Alignment(-0.75, -0.75),
      radius: 0.55,
      drift: Offset(0.32, 0.2),
      speed: 1,
      phase: 0,
    ),
    _Orb(
      color: AppColors.mediumGreen,
      center: Alignment(0.95, -0.5),
      radius: 0.48,
      drift: Offset(-0.28, 0.28),
      speed: 0.75,
      phase: 1.7,
    ),
    _Orb(
      color: AppColors.mediumGold,
      center: Alignment(0.6, 0.85),
      radius: 0.5,
      drift: Offset(-0.32, -0.18),
      speed: 0.6,
      phase: 3.1,
    ),
    _Orb(
      color: AppColors.mediumRed,
      center: Alignment(-0.85, 0.7),
      radius: 0.44,
      drift: Offset(0.26, -0.24),
      speed: 0.9,
      phase: 4.6,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = isDark ? _darkOrbs : _lightOrbs;
    final longest = math.max(size.width, size.height);
    final tau = math.pi * 2;
    // Peak alpha at the orb core. Night ADDS light into black and can take a
    // quarter of it; paper lays colour OVER a tone and cannot.
    //
    // Halved when the paper field was deepened, because the two compound: at
    // 0.14 over a near-white page the orbs were a tint, and over the deeper
    // field the same number turned the corners to mud — grey-green under the
    // first orb, a dull pink under the red one. The field carries the warmth
    // itself now, so all the orbs owe it is enough drift to keep a monitor's
    // worth of it from reading as one flat sheet.
    final peak = isDark ? 0.26 : 0.07;

    for (final orb in orbs) {
      final angle = tau * t * orb.speed + orb.phase;
      final dx = orb.center.x + math.sin(angle) * orb.drift.dx;
      final dy = orb.center.y + math.cos(angle * 0.8) * orb.drift.dy;
      final center = Alignment(dx, dy).withinRect(Offset.zero & size);
      final radius = longest * orb.radius * (0.92 + 0.08 * math.sin(angle));

      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..blendMode = isDark ? BlendMode.plus : BlendMode.srcOver
        ..shader = RadialGradient(
          colors: [
            orb.color.withValues(alpha: peak),
            orb.color.withValues(alpha: peak * 0.45),
            orb.color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.t != t || old.isDark != isDark;
}

/// Fixed-seed film grain. Static, so it paints once and is cached by the
/// enclosing [RepaintBoundary].
class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(2026);
    final paint = Paint();
    final color = isDark ? AppColors.white : AppColors.black;
    // One speck per 900 square pixels, and the ceiling has to leave room for a
    // monitor: at 2600 a 2560×1440 window got two thirds of the density a phone
    // gets, so the texture thinned out on exactly the screen where a flat field
    // is most obvious. It is painted once and cached by the [RepaintBoundary]
    // above, so the extra specks cost a frame at startup and nothing after.
    final count = (size.width * size.height / 900).clamp(200, 6000).toInt();

    for (var i = 0; i < count; i++) {
      // The same weight on both backdrops now that the paper one is a tone
      // rather than a white: at 0.014 the light grain was a black speck on an
      // all-but-white page, which is to say invisible.
      paint.color = color.withValues(alpha: 0.020 * random.nextDouble());
      canvas.drawRect(
        Rect.fromLTWH(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
          1.4,
          1.4,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.isDark != isDark;
}
