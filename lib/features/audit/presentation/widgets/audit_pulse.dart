import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/charts.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/responsive.dart';
import '../../domain/audit_summary.dart';
import 'audit_style.dart';

/// The shape of the log, above the log.
///
/// Two questions a list of lines cannot answer however carefully it is read:
/// WHEN the work happened, and WHAT KIND of work it was. Both are about the
/// whole filtered set, so both are counted server-side — see [AuditSummary],
/// which explains at length why they are not derived from the pages this screen
/// is holding.
///
/// It rides in the list's header rather than above it, so it scrolls away: the
/// first thing wanted on a long register is the register, and a panel pinned
/// over it would cost the reader two rows on every screen forever.
class AuditPulse extends StatelessWidget {
  const AuditPulse({super.key, required this.summary});

  final AuditSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    // The window, said in words. It is the reader's own date filter when they
    // set one and the last thirty days when they did not — and the chart means
    // something different in each case, so it is never left to be guessed.
    final range = DateFormat('d MMM', locale);
    final window =
        '${range.format(summary.from)} – ${range.format(summary.to)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AdaptiveGrid(
        equalHeights: false,
        children: [
          ChartCard(
            title: l.auditPulseTitle,
            subtitle: window,
            trailing: GlassBadge(
              label: l.auditPulseEvents(summary.total),
              icon: AppIcons.auditLog,
              dense: true,
            ),
            child: TrendChart(
              emptyLabel: l.auditPulseEmpty,
              points: [
                for (final p in summary.series)
                  TrendPoint(day: p.at, value: p.count),
              ],
              axisLabelForDay: (d) => _axisLabel(d, locale),
              labelForDay: (d) => _tooltipLabel(d, locale),
            ),
          ),
          ChartCard(
            title: l.auditPulseByAction,
            subtitle: window,
            trailing: GlassBadge(
              label: l.auditPulseActors(summary.actors),
              icon: AppIcons.participants,
              dense: true,
            ),
            // Five kinds of act, which is two more than colour can carry — so a
            // ranked list in one hue, with the name at the start of each row.
            // See [RankedBars].
            child: RankedBars(
              slices: [
                for (final row in summary.byAction)
                  ChartSlice(
                    label: auditActionLabel(context, row.action),
                    value: row.count,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Under the axis, where there is room for about five words in total.
  String _axisLabel(DateTime d, String locale) => switch (summary.bucket) {
    AuditBucket.day || AuditBucket.week => DateFormat('d/M', locale).format(d),
    AuditBucket.month => DateFormat('MMM', locale).format(d),
  };

  /// In the tooltip, where a point has to name the whole period it stands for —
  /// a week's bar labelled with one date reads as that one day's traffic.
  String _tooltipLabel(DateTime d, String locale) => switch (summary.bucket) {
    AuditBucket.day => DateFormat('EEEE d MMMM', locale).format(d),
    AuditBucket.week => DateFormat('d MMMM', locale).format(d),
    AuditBucket.month => DateFormat('MMMM y', locale).format(d),
  };
}
