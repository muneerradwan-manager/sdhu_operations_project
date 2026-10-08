import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_icons.dart';
import '../theme/glass_tokens.dart';
import 'app_shell_scope.dart';

/// The primitive every frosted pane in the app is built from.
///
/// Blurs whatever the [AuroraBackground] is painting behind it, lays a
/// translucent gradient fill on top, and finishes the edge with a gradient
/// hairline so the pane reads as a physical sheet of glass.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppRadius.lg,
    this.blur = true,
    this.strong = false,
    this.subtle = false,
    this.bordered = true,
    this.emphasised = false,
    this.shadow = true,
    this.tint,
    this.width,
    this.height,
    this.alignment,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  /// Real backdrop blur. Defaults on HERE because what uses [GlassSurface]
  /// directly is chrome — an app bar, a bottom bar, a sheet — of which one is
  /// on screen at a time, and which must stay legible over whatever scrolls
  /// beneath it.
  ///
  /// Content panes are the other case entirely, and [GlassCard] defaults this
  /// off for them: see the note there.
  final bool blur;

  /// Denser fill, for surfaces that must stay legible over anything (app bars,
  /// sheets, dialogs).
  final bool strong;

  /// Lighter fill, for panes nested inside another pane.
  final bool subtle;

  final bool bordered;

  /// Brighter hairline — used for selected / focused states.
  final bool emphasised;

  final bool shadow;

  /// Optional colour wash mixed into the fill, e.g. a status accent.
  final Color? tint;

  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final borderRadius = BorderRadius.circular(radius);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: glass.fillGradient(strong: strong, subtle: subtle),
        borderRadius: borderRadius,
      ),
      child: tint == null
          ? _body(context)
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tint!.withValues(alpha: 0.20),
                    tint!.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: borderRadius,
              ),
              child: _body(context),
            ),
    );

    // `glass.blur > 0` and not merely `blur`: with the glass-free tokens the
    // sigma is zero, and a zero-sigma BackdropFilter is not free — it is still
    // a save-layer, so the compositor still re-reads everything behind the pane
    // every frame to blur it by nothing. Skipping the widget is the whole
    // performance half of that mode.
    if (blur && glass.blur > 0) {
      content = BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: strong ? glass.blurStrong : glass.blur,
          sigmaY: strong ? glass.blurStrong : glass.blur,
        ),
        child: content,
      );
    }

    content = ClipRRect(borderRadius: borderRadius, child: content);

    if (bordered) {
      content = CustomPaint(
        foregroundPainter: _HairlinePainter(
          gradient: glass.strokeGradient(strong: emphasised),
          radius: radius,
        ),
        child: content,
      );
    }

    if (shadow) {
      content = CustomPaint(
        painter: _AmbientShadowPainter(color: glass.shadow, radius: radius),
        child: content,
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      child: content,
    );
  }

  /// The seat under a pane.
  ///
  /// Small numbers, and they have to be: the reach below the pane —
  /// [shadowOffset] plus [shadowBlur] less [shadowSpread] — must stay inside the
  /// gap between two panes ([AppSpacing.md]). Every pane in this app is
  /// see-through, so a shadow that carries past the gap is not a shadow on the
  /// background, it is a grey band printed across the glass below it. That is
  /// the whole reason these are not the usual generous elevation numbers.
  static const shadowBlur = 12.0;
  static const shadowSpread = -4.0;
  static const shadowOffset = Offset(0, 4);

  Widget _body(BuildContext context) {
    // Transparent Material so InkWell ripples from callers still render and
    // clip to the pane.
    return Material(
      type: MaterialType.transparency,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

/// Drop-in replacement for [Card] in the glass language.
///
/// Adds an optional press interaction with a subtle scale — tapping a pane of
/// glass should feel like pressing something physical.
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.radius = AppRadius.lg,
    this.blur = false,
    this.subtle = false,
    this.emphasised = false,
    this.shadow = true,
    this.tint,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  /// Real backdrop blur, OFF by default — this is a content pane, and content
  /// panes come several to a screen.
  ///
  /// Each blur is a save-layer that re-reads and re-blurs everything behind it
  /// on every frame the pane moves — which, inside a scrolling list, is every
  /// frame of the scroll. One is affordable; the home dashboard had seven and
  /// the employee page six, stacked inside a scrolling list, which is what made
  /// those two screens crawl while the files list — the one screen that had
  /// already turned this off — stayed smooth.
  ///
  /// Nothing is really lost: the aurora is low-frequency, so the translucent
  /// fill, the hairline and the shadow carry the glass on their own. Pass true
  /// only for a pane that sits over something busy AND is alone on the screen.
  final bool blur;
  final bool subtle;
  final bool emphasised;
  final bool shadow;
  final Color? tint;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _pressed = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final padded = widget.padding == null
        ? widget.child
        : Padding(padding: widget.padding!, child: widget.child);

    final surface = GlassSurface(
      // The pane's padding is handed to the [InkWell] instead when the card is
      // tappable, so that the whole pane answers a tap. Left on the outside it
      // is the InkWell that shrinks to the content, and a card's padding is
      // 16–24 logical pixels on every side: a frame of dead glass around a row
      // that looks tappable everywhere and is not. The ripple has the same
      // problem — it stops short of the edge instead of filling the pane.
      padding: _interactive ? null : widget.padding,
      margin: widget.margin,
      radius: widget.radius,
      blur: widget.blur,
      subtle: widget.subtle,
      emphasised: widget.emphasised || _pressed,
      shadow: widget.shadow,
      tint: widget.tint,
      child: _interactive
          ? InkWell(
              onTap: widget.onTap == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      widget.onTap!();
                    },
              onLongPress: widget.onLongPress,
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              borderRadius: BorderRadius.circular(widget.radius),
              child: padded,
            )
          : padded,
    );

    if (!_interactive) return surface;

    return AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: surface,
    );
  }
}

/// App bar that lets content scroll beneath it through a blurred pane instead
/// of hiding behind an opaque bar.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.centerTitle,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      title: title,
      leading:
          leading ??
          (automaticallyImplyLeading ? _shellMenuButton(context) : null),
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      bottom: bottom,
      centerTitle: centerTitle,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      flexibleSpace: ClipRect(
        child: _maybeBlur(
          glass.blurStrong,
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: glass.fillGradient(strong: true),
              border: Border(bottom: BorderSide(color: glass.stroke)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The way back to the rail on a window too narrow to stand one open.
///
/// Drawn only when all of these are true, and each one is doing work:
///
///   * the bar was not told to keep its leading slot empty. A screen that says
///     `automaticallyImplyLeading: false` means it, and the two that say it —
///     the home grid and the pre-approval screens — each have a reason;
///   * there is a shell above this bar at all — so the grid arrangement, the
///     login screen and the splash are untouched;
///   * that shell is holding the rail in a drawer rather than standing it —
///     beside a standing rail a menu button would open nothing;
///   * and this page has nothing to go back to. A page reached from the rail is
///     the root of its stack and needs the menu; a page pushed from inside
///     another one has a back arrow, and two leading affordances cannot share
///     the slot. Back wins, because it is the one the reader came in through.
///
/// It replaces nothing a screen asked for: a bar given an explicit `leading`
/// keeps it, which is how the home page's own settings button survives.
Widget? _shellMenuButton(BuildContext context) {
  final open = AppShellScope.maybeOf(context)?.openDrawer;
  if (open == null) return null;
  if (Navigator.of(context).canPop()) return null;

  return IconButton(
    tooltip: context.l10n.sidebarMenu,
    onPressed: open,
    icon: const Icon(AppIcons.menu),
  );
}

/// [child] behind a backdrop blur, or [child] itself when the sigma is zero.
///
/// The zero case is not an optimisation of a no-op. A `BackdropFilter` with no
/// blur is still a save-layer: the compositor reads back everything painted
/// beneath the pane, every frame, and applies nothing to it. Under the
/// glass-free tokens every bar and card would keep paying that for a picture
/// identical to not having asked — which is exactly the cost the mode exists to
/// remove on the handsets field staff carry.
Widget _maybeBlur(double sigma, Widget child) {
  if (sigma <= 0) return child;
  return BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: child,
  );
}

/// Small translucent label — status chips, role badges, counters.
///
/// It gives way rather than overflowing. A badge carries whatever name the
/// database holds, and some of those are sentences: "تشكيل فرق المشاعر (منى يوم
/// التروية، عرفات، منى أيام التشريق)" is the name of a file, and it appeared in
/// a badge beside a season year. A pill is the smallest thing on the screen and
/// must never be what breaks the layout around it.
class GlassBadge extends StatelessWidget {
  const GlassBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 11,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tone.withValues(alpha: 0.26), tone.withValues(alpha: 0.12)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tone.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: tone),
            const SizedBox(width: 5),
          ],
          // Loose, so the pill still hugs a short label and only gives way when
          // there is not room for a long one.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone,
                fontWeight: FontWeight.w700,
                fontSize: dense ? 10.5 : 12,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular glass icon button, for app-bar and floating actions.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.size = 20,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = GlassSurface(
      radius: AppRadius.pill,
      blur: false,
      shadow: false,
      width: 42,
      height: 42,
      child: InkWell(
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Icon(
          icon,
          size: size,
          color: color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Paints a pane's shadow everywhere EXCEPT under the pane itself.
///
/// `BoxDecoration.boxShadow` cannot do this: it draws a filled blurred
/// rectangle, the pane's own footprint included, and then the pane is painted
/// over it. That is invisible under an opaque card and ruinous under this one —
/// the dark fill is a white at eight per cent opacity, so what sat underneath
/// was a black blob showing through the body of every pane on the screen. It
/// read as dirt, and it moved as you scrolled.
class _AmbientShadowPainter extends CustomPainter {
  const _AmbientShadowPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pane = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    const shadow = BoxShadow(
      blurRadius: GlassSurface.shadowBlur,
      spreadRadius: GlassSurface.shadowSpread,
      offset: GlassSurface.shadowOffset,
    );

    canvas.save();
    // Everything around the pane, and nothing beneath it.
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(GlassSurface.shadowBlur * 3)),
        Path()..addRRect(pane),
      ),
    );
    canvas.drawRRect(
      pane.shift(shadow.offset).inflate(shadow.spreadRadius),
      (shadow.copyWith(color: color)).toPaint(),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AmbientShadowPainter old) =>
      old.color != color || old.radius != radius;
}

/// Paints the gradient hairline that defines a pane's edge.
class _HairlinePainter extends CustomPainter {
  const _HairlinePainter({required this.gradient, required this.radius});

  final Gradient gradient;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _HairlinePainter old) =>
      old.gradient != gradient || old.radius != radius;
}
