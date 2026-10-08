import 'package:flutter/material.dart';

/// Outlined "Continue with Google" button with a drawn G mark (no asset needed).
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _GoogleGlyph(),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    // A compact multi-color "G" rendered as text to avoid bundling an image.
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GPainter()),
    );
  }
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final arcRect = rect.deflate(stroke / 2);
    // Four coloured arcs approximating the Google G.
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(arcRect, -0.6, 1.4, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(arcRect, 0.8, 1.4, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(arcRect, 2.2, 1.4, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(arcRect, 3.6, 1.4, false, paint);

    // Cross-bar of the G.
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.52,
        size.height * 0.42,
        size.width * 0.46,
        stroke,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
