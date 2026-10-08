import 'package:flutter/material.dart';

import '../../../../core/theme/glass_tokens.dart';
import '../../../prayer_times/presentation/widgets/prayer_times_card.dart';

/// What is on the home page about the MOMENT rather than about a place to go:
/// what time the next prayer is.
///
/// Bundled rather than added to each arrangement in turn, so that the grid's
/// version and the rail's cannot drift apart. Both put it under the greeting
/// and above everything else, because it is a fact a man wants before he has
/// decided what he is doing next.
///
/// It used to carry two other things. The animated sky went because a
/// decoration that costs a running particle system on a field handset is not
/// worth what it costs. The urgent report went somewhere else entirely: عام ←
/// بلاغاتي carries its own "raise one" button now, and the register no longer
/// needs a chip riding along on every app bar to be reachable.
class MomentPanel extends StatelessWidget {
  const MomentPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: PrayerTimesCard(),
    );
  }
}

/// The name of one shelf, in that shelf's colour.
///
/// Deliberately NOT a [SectionHeader]: that one names عام and الإدارة, the two
/// halves of the page, and a heading that looks the same as those would say
/// these shelves are its equals rather than its contents. Smaller, in the
/// group's own accent rather than the page's grey, with a rule running off to
/// the edge to tie whatever is under it into one band.
///
/// The colour is the point of the rule. It is the same colour as the medallions
/// below it, so the band reads as one thing at arm's length, before a single
/// word of it has been read.
class ShelfHeader extends StatelessWidget {
  const ShelfHeader({
    super.key,
    required this.title,
    required this.color,
    this.compact = false,
  });

  final String title;
  final Color color;

  /// The form for a 288-pixel column instead of a page.
  ///
  /// The rule goes and the name is allowed to wrap, and both are forced by the
  /// same measurement: "الملفات والقرارات والتعميمات" is 361 pixels of text,
  /// and a rail leaves it 247. Across a page there is room for the name, a gap
  /// and a rule running off to the edge; in a column there is room for the name
  /// and only if it may take two lines.
  ///
  /// It is a flag rather than a second widget because the two have to stay the
  /// same THING — the bar, the colour and the weight are what tie a heading to
  /// the tiles or the entries under it, and those do not change.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final label = Text(
      title,
      style: text.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      maxLines: compact ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Across a page the name takes its natural width and the rule takes
          // everything after it; in a column there is no "after it", so the
          // name takes the column. Two different flex arrangements rather than
          // one that tries to serve both — a `Flexible` name beside an
          // `Expanded` rule splits the row in half and ellipsises a title that
          // had room to spare.
          if (compact)
            Expanded(child: label)
          else ...[
            label,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Container(height: 1, color: color.withValues(alpha: 0.22)),
            ),
          ],
        ],
      ),
    );
  }
}

/// A rounded-square icon holder with an outward glow in an accent.
///
/// Lifted out of the dashboard card so the guide can wear the same medallion:
/// the guide's entry for الصلاحيات and the tile for الصلاحيات have to be
/// recognisably the same door, and a different icon treatment on each would
/// make them two.
class IconMedallion extends StatelessWidget {
  const IconMedallion({
    super.key,
    required this.icon,
    required this.color,
    this.size = 50,
    this.iconSize = 22,
  });

  final IconData icon;
  final Color color;

  /// Smaller wherever the medallion is stacked above a name rather than set
  /// beside it, and every pixel of it is height.
  final double size;

  /// The glyph inside, which does NOT scale with the holder by default.
  ///
  /// A 22-pixel icon is what an Iconsax glyph is drawn to be read at; shrinking
  /// it with the box turns the two-stroke ones — the folder with a fold, the
  /// clipboard with a tick — into a smudge. The box gets smaller, the mark
  /// stays legible, and the padding around it absorbs the difference.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.16),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
