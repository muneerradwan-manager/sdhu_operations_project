import 'package:flutter/material.dart';

import '../theme/glass_tokens.dart';
import 'glass.dart';
import 'responsive.dart';

/// Illustrated empty state: an orbiting glass medallion, a headline that says
/// what happened, and an optional next step. Replaces bare centred text so a
/// "nothing here" screen never looks like a failure.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        // No app-bar inset here: an EmptyState is often nested inside a list
        // that has already applied one, and the extra padding strands it far
        // down the page.
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HaloIcon(icon: icon, color: scheme.primary),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.xl),
                // The app's buttons claim their parent's whole width by theme
                // — right at the foot of a form, wrong here, where a lone
                // "retry" would run the full column and read as a bar. Hug
                // the label instead, with a floor so a short one still reads
                // as a button.
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 200),
                  child: IntrinsicWidth(child: action!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A glass medallion with a slowly breathing halo behind it.
class _HaloIcon extends StatefulWidget {
  const _HaloIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_HaloIcon> createState() => _HaloIconState();
}

class _HaloIconState extends State<_HaloIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.color.withValues(alpha: 0.22 + 0.10 * t),
                widget.color.withValues(alpha: 0),
              ],
            ),
          ),
          child: child,
        );
      },
      child: Center(
        child: GlassSurface(
          radius: AppRadius.pill,
          width: 76,
          height: 76,
          child: Icon(widget.icon, size: 32, color: widget.color),
        ),
      ),
    );
  }
}

/// Shimmering placeholders shown while a screen loads, in the shape the screen
/// is about to take.
///
/// The shape is the whole point — it is what reads faster than a spinner. Which
/// means it has to be the RIGHT shape: a single column of full-width bars,
/// shown on a window that is about to fill with a four-column grid, promises
/// one thing and delivers another, and the swap at the end reads as the page
/// jumping rather than arriving. On a monitor it also promised a list four
/// times longer than the one that came.
///
/// So it measures the same width the content will, counts columns by the same
/// arithmetic ([columnsFor]), and takes the same [WindowSize.gutter] and cap. A
/// caller whose real list is a grid of narrower cards passes the same
/// [minTileWidth] it gives [AdaptiveGrid]; a caller whose page stands a panel
/// beside the content passes [panel], and gets a panel-shaped placeholder on
/// the same side, at the same width, on windows wide enough to have one.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 5,
    this.height = 76,
    this.padding,
    this.minTileWidth = CardWidth.list,
    this.maxColumns = 4,
    this.panel = false,
    this.panelHeight = 280,
    this.width = PageWidth.browse,
  });

  /// The page kind this skeleton is standing in.
  ///
  /// It has to be the same one the loaded screen passes to its own
  /// [ResponsivePage], and it is the half that was missing. The shape was
  /// already measured by the same arithmetic and cut into the same columns —
  /// but always at [PageWidth.browse], so a form capped at 640 flashed a
  /// placeholder 1680 wide and then snapped in to a third of it. The promise
  /// has to include the WIDTH, or the arrival still reads as the page jumping.

  /// How many ROWS to draw, not how many cards: on a window three columns wide
  /// this draws three times as many, because that is what will be there.
  final int count;

  final double height;

  /// Defaults to [GlassThemeX.scrollPadding] so the skeleton clears a glass
  /// app bar exactly the way the real list will.
  final EdgeInsets? padding;

  /// Match whatever the real [AdaptiveGrid] on this screen is given, so the
  /// columns break at the same widths.
  final double minTileWidth;
  final int maxColumns;

  /// Whether the loaded screen stands a panel beside its content — see
  /// [TwoPaneLayout]. Ignored on windows too narrow for one, exactly as the
  /// real layout ignores it.
  final bool panel;

  final double panelHeight;

  final PageWidth width;

  Widget _bar({required double height, int step = 0}) => Shimmer(
    delay: Duration(milliseconds: 90 * step),
    child: GlassSurface(
      height: height,
      blur: false,
      shadow: false,
      subtle: true,
      child: const SizedBox.shrink(),
    ),
  );

  /// The rows themselves, in as many columns as the width allows.
  ///
  /// The cascade runs down the ROWS rather than through the cards: staggering
  /// card by card across a four-wide grid puts a second and a half between the
  /// first placeholder and the last, which stops reading as a sweep and starts
  /// reading as the screen struggling.
  Widget _grid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          constraints.maxWidth,
          minTileWidth: minTileWidth,
          maxColumns: maxColumns,
        );
        return AdaptiveGrid(
          minTileWidth: minTileWidth,
          maxColumns: maxColumns,
          children: [
            for (var i = 0; i < count * columns; i++)
              _bar(height: height, step: (i ~/ columns).clamp(0, 5)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      width: width,
      builder: (context, size) {
        final page = padding ?? context.scrollPadding(horizontal: size.gutter);

        if (!panel || !size.hasSidePanel) {
          return ListView(
            padding: page,
            physics: const NeverScrollableScrollPhysics(),
            children: [_grid()],
          );
        }

        final vertical = EdgeInsets.only(top: page.top, bottom: page.bottom);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: size.gutter),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: kSidePanelWidth,
                child: Padding(
                  padding: vertical,
                  child: _bar(height: panelHeight),
                ),
              ),
              SizedBox(width: size.gutter),
              Expanded(
                child: ListView(
                  padding: vertical,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_grid()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Sweeps a soft highlight across its child, on a loop.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlight = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.55);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) {
          final dx = rect.width * (_c.value * 2 - 0.5);
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.transparent, highlight, Colors.transparent],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlideGradient(dx),
          ).createShader(rect);
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);

  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// Centred branded spinner for full-screen loads that have no list shape.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: GlassSurface(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                strokeCap: StrokeCap.round,
                color: scheme.primary,
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                label!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section heading used to chunk long screens into scannable groups.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.icon});

  final String title;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
