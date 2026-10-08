import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_accents.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/charts.dart';
import '../../domain/journey.dart';

/// «أين قضيت الموسم» — the season's days, one bar per city.
///
/// The question this answers is the one a man asks about his own season before
/// any other, and the timeline underneath answers it badly: reading «٢٥ يوليو
/// — ١٤ أغسطس» off one card and «١٤ أغسطس — ٢٧ أغسطس» off the next and
/// subtracting in your head is arithmetic, and a bar twice as long as its
/// neighbour is not. Thirty days in مكة against thirteen in المدينة is a fact
/// about the shape of a season, and a shape is what a chart is for.
///
/// [RankedBars] rather than a bespoke drawing: it is the app's own mark for
/// exactly this — a named row, its number at the end, and the bar's LENGTH
/// doing the encoding — so this chart is the same object the dashboard uses
/// and inherits its palette, its empty track and its contrast checks.
///
/// **Only stays that HOUSE him are counted.** دمشق at either end is where he
/// lives, not somewhere the season put him, and including it would answer a
/// question nobody asked with a bar longer than the mission itself. A stay
/// with no nights yet — a leg of the journey still ahead — is not drawn
/// either: an empty bar for a city he has not reached reads as a city he
/// spent no time in.
class JourneySeasonChart extends StatelessWidget {
  const JourneySeasonChart({super.key, required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    // Cities rather than stays: منى and عرفات and مكة are three rows on the
    // spine and one answer to "how long in مكة" only if the days that share a
    // city are added together. A man posted back to the same hotel after the
    // rites has one stay in the register per posting and one line here.
    final byCity = <String, int>{};
    for (final stay in journey.stays) {
      if (!stay.kind.isHoused) continue;
      final nights = stay.nights ?? 0;
      if (nights <= 0) continue;
      final city = stay.city?.of(context);
      if (city == null || city.isEmpty) continue;
      byCity[city] = (byCity[city] ?? 0) + nights;
    }

    // One city is not a comparison, and a single full-width bar says nothing
    // the header has not already said in words.
    if (byCity.length < 2) return const SizedBox.shrink();

    final total = byCity.values.fold<int>(0, (sum, n) => sum + n);

    // The gap under the card belongs to the card, not to the page: this
    // widget draws nothing at all for a single-city season, and a page that
    // spaced it from outside would leave that nothing a hole to sit in.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: ChartCard(
        title: l.travelSeasonBreakdown,
        subtitle: l.travelSeasonBreakdownHint,
        trailing: Text(
          l.travelDays(total),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Accent.green.of(context),
          ),
        ),
        child: RankedBars(
          color: Accent.green.of(context),
          slices: [
            for (final entry in byCity.entries)
              ChartSlice(label: entry.key, value: entry.value),
          ],
        ),
      ),
    );
  }
}
