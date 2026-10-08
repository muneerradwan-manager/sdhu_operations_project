import 'package:flutter/material.dart';

/// The mission's mark.
///
/// Three things about the asset decide how this widget is written, and all
/// three are easy to get wrong:
///
/// 1. It is 2000×2000. Decoded at full size that is roughly 16 MB of memory for
///    something drawn at 120 logical pixels, held for as long as the image is
///    on screen and again for every place it appears. So it is decoded at the
///    size it will actually be drawn — [cacheWidth]/[cacheHeight] scaled by the
///    device pixel ratio, which is the whole reason this is a widget and not an
///    `Image.asset` written out at each call site.
///
/// 2. It is a complete lockup, not a glyph: a medallion with its own border and
///    background, the Kaaba mark, and the words HAJJ & UMRAH / Operations. It
///    must never be put inside another badge — a badge inside a badge — and it
///    must never be tinted.
///
/// 3. It carries type. Below roughly 96 logical pixels the wordmark stops being
///    readable and becomes texture, so [size] is asserted against that. Where
///    something small is wanted — an app bar, a list row — use an icon.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 120, this.semanticLabel})
    : assert(
        size >= 96,
        'The wordmark inside the logo is illegible below 96px — use an icon '
        'instead of shrinking the lockup.',
      );

  final double size;
  final String? semanticLabel;

  static const _asset = 'assets/images/app_icon.png';

  @override
  Widget build(BuildContext context) {
    // Rounded up so a fractional ratio never decodes half a pixel short and
    // leaves the mark soft.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();

    return Image.asset(
      _asset,
      width: size,
      height: size,
      cacheWidth: pixels,
      cacheHeight: pixels,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
    );
  }
}
