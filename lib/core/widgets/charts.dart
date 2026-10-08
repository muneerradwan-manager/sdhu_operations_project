/// The chart marks this dashboard is built from.
///
/// Six shapes, and each is here because a different question needed answering:
/// a headline number with its recent shape ([StatTile] and [Sparkline]), a
/// whole divided into named parts ([DonutChart]), a ranked list too long for
/// colour ([RankedBars]), a quantity over time ([TrendChart]), a distribution
/// across a fixed scale ([StarBars]), and one share of one whole ([GaugeRing]).
/// Anything the season can be asked is one of those six.
///
/// Drawn with `fl_chart` (MIT). What it is used for and what it is not: the
/// package supplies the plotting — axes, gridlines, curves, hit-testing,
/// tooltips, the entry animation — and nothing else. Colour comes from
/// [ChartPalette], which is contrast-and-CVD measured; type comes from the
/// theme; the legends are ours. A chart library's defaults are designed to look
/// like the library, and this page has to look like the app.
///
/// Shared rules, applied in every one of them:
///
///   * **Text wears text colours.** A number is never painted in its series
///     colour — the mark beside it carries the identity, and a coloured numeral
///     is a numeral somebody has to squint at.
///   * **Never colour alone.** Every segment that carries a colour also carries
///     its name and its number, within reach of the mark. The chart has to
///     survive a photocopier and a reader who cannot separate the hues at all.
///   * **Colour follows the entity, never its rank.** Slot 0 is the first
///     category NAMED, not the biggest or the first one drawn, so a category
///     falling to zero cannot repaint the ones that remain.
///   * **Time runs left to right**, in both languages. Every plot is pinned to
///     [TextDirection.ltr]: a series is read against an axis, and mirroring the
///     axis on an Arabic page would put ذو القعدة to the right of ذو الحجة. The
///     labels around it are still the reader's language.
///   * **Every plot sits in a tightly-sized box.** A pane in an equal-heights
///     row is asked for its intrinsic height, and a chart cannot answer — it
///     measures itself against the space it is given. A fixed height short-
///     circuits the question. (See [AdaptiveGrid.equalHeights].)
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/chart_palette.dart';
import '../theme/glass_tokens.dart';
import 'glass.dart';

/// A titled pane around one chart.
///
/// The title names the series, which is what lets a single-series chart go
/// without a legend; [subtitle] is for what the title cannot say and the chart
/// must not be read without — the window a summary was counted over, above all.
/// [trailing] is for one number that belongs beside the name rather than in the
/// plot: an average, a total.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

/// A headline number: the answer, before any chart.
///
/// Most of what a dashboard is asked has a single number for an answer, and
/// drawing that number as a one-bar chart is worse than printing it. The mark
/// here is the medallion — identity — and the number is text.
///
/// [spark] is the exception, and a narrow one: where the number has a RECENT
/// SHAPE the tile can carry it as a sparkline under the figure. "412 reports"
/// and "412 reports, all of them in the first week" are different facts, and
/// the second is the one worth acting on.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    this.spark,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// The second line, for what the number does not say on its own — "of 240",
  /// "since Sunday".
  final String? caption;

  /// The recent series behind the number, if it has one. Two points or fewer
  /// is not a shape and is not drawn.
  final List<num>? spark;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final series = spark;

    return GlassCard(
      onTap: onTap,
      tint: color,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              // Ink, not the accent: the medallion above already said which
              // thing this is.
              color: scheme.onSurface,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (series != null && series.length > 2) ...[
            const SizedBox(height: AppSpacing.md),
            Sparkline(values: series, color: color),
          ],
        ],
      ),
    );
  }
}

/// The shape of a series, with no axis and no readout — the smallest honest
/// picture of "how it has been going".
///
/// Deliberately unlabelled and untouchable: a sparkline says RISING or SPIKY or
/// FLAT, and anyone who wants the numbers has the [TrendChart] further down the
/// page. Giving it ticks would make it a bad small chart instead of a good
/// glyph. The floor is drawn at zero so a flat run of ones does not fill the
/// box and read as a mountain.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 30,
  });

  final List<num> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    final peak = values.map((v) => v.toDouble()).reduce(math.max);

    return SizedBox(
      height: height,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: peak <= 0 ? 1 : peak * 1.15,
            minX: 0,
            maxX: (values.length - 1).toDouble(),
            lineTouchData: const LineTouchData(enabled: false),
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < values.length; i++)
                    FlSpot(i.toDouble(), values[i].toDouble()),
                ],
                isCurved: true,
                curveSmoothness: 0.25,
                preventCurveOverShooting: true,
                color: color,
                barWidth: 1.8,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.26),
                      color.withValues(alpha: 0.01),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One slice of a whole, for [DonutChart] and [RankedBars].
class ChartSlice {
  const ChartSlice({required this.label, required this.value});

  final String label;
  final num value;
}

/// A whole, divided into named parts.
///
/// A ring rather than a full pie: the hole is where the TOTAL goes, and the
/// total is the number a reader wants first — "how many people" before "how
/// many of them are external". Touching a wedge swaps the middle for that
/// wedge's own name and number, which is what makes the ring answerable rather
/// than decorative.
///
/// Three named parts is the ceiling, because [ChartPalette] has exactly three
/// slots that were measured to be distinguishable and is never cycled. Anything
/// past the third is folded into one wedge named [otherLabel] — the fold runs
/// by DECLARED order, not by size, so that a category shrinking cannot change
/// what a colour means. A list that is genuinely long is not a job for colour
/// at all: that is what [RankedBars] is for.
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.otherLabel,
    this.centerLabel,
    this.size = 148,
  });

  final List<ChartSlice> slices;

  /// What the tail is called once it has been folded into one wedge.
  final String otherLabel;

  /// The word under the total, in the hole. Null leaves the number alone.
  final String? centerLabel;

  final double size;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int? _touched;

  /// The declared slices, capped at three: the first two as given, and
  /// everything from the third on summed into one.
  List<ChartSlice> get _folded {
    final all = widget.slices;
    if (all.length <= 3) return all;
    final tail = all.skip(2).fold<num>(0, (sum, s) => sum + s.value);
    return [all[0], all[1], ChartSlice(label: widget.otherLabel, value: tail)];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final folded = _folded;
    // Zeroes are dropped from the ring AND the legend: a wedge of no width
    // claiming a colour is a colour spent on nothing.
    final drawn = <(int slot, ChartSlice slice)>[
      for (var i = 0; i < folded.length; i++)
        if (folded[i].value > 0) (i, folded[i]),
    ];
    final total = drawn.fold<num>(0, (sum, e) => sum + e.$2.value);

    if (total == 0) {
      return SizedBox(
        height: widget.size,
        child: Center(
          child: _EmptyRing(size: widget.size * 0.72),
        ),
      );
    }

    final touched = _touched != null && _touched! < drawn.length
        ? drawn[_touched!]
        : null;

    final ring = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: widget.size * 0.30,
              // Twelve o'clock, so the first category named is also the first
              // one met going clockwise.
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  final index = response?.touchedSection?.touchedSectionIndex;
                  final next =
                      !event.isInterestedForInteractions ||
                          index == null ||
                          index < 0
                      ? null
                      : index;
                  if (next != _touched) setState(() => _touched = next);
                },
              ),
              sections: [
                for (var i = 0; i < drawn.length; i++)
                  PieChartSectionData(
                    value: drawn[i].$2.value.toDouble(),
                    color: _colorFor(context, drawn[i].$1),
                    // The touched wedge grows rather than brightening: a
                    // lightness change is the one signal that reads as
                    // "disabled" as readily as "selected".
                    radius: (widget.size * 0.20) + (_touched == i ? 7 : 0),
                    showTitle: false,
                  ),
              ],
            ),
          ),
          // The hole, which is a readout and not a decoration.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.size * 0.12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${touched?.$2.value ?? total}',
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                if (touched != null || widget.centerLabel != null)
                  Text(
                    touched?.$2.label ?? widget.centerLabel!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < drawn.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _LegendRow(
            color: _colorFor(context, drawn[i].$1),
            label: drawn[i].$2.label,
            value: drawn[i].$2.value,
            share: drawn[i].$2.value / total,
            emphasised: _touched == i,
          ),
        ],
      ],
    );

    // Side by side where there is room for both, stacked where there is not.
    // The ring keeps its size either way: a donut that shrinks to fit a phone
    // stops being readable long before it stops fitting.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 330
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ring,
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: legend),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: ring),
                const SizedBox(height: AppSpacing.lg),
                legend,
              ],
            ),
    );
  }

  /// Fixed order: slot 0 is the first slice NAMED, not the first one drawn.
  Color _colorFor(BuildContext context, int slot) =>
      ChartPalette.series[slot % ChartPalette.series.length].of(context);
}

/// One line of a donut's legend: the mark, the name, the number, the share.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.share,
    this.emphasised = false,
  });

  final Color color;
  final String label;
  final num value;
  final double share;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              color: emphasised ? scheme.onSurface : scheme.onSurfaceVariant,
              fontWeight: emphasised ? FontWeight.w700 : null,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$value',
          style: text.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        // The share, in the recessive colour: it is derived from the two
        // numbers already on the row and must not compete with them.
        Text(
          '${(share * 100).round()}%',
          style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// One share of one whole, drawn as a ring with the percentage in it.
///
/// For the questions whose answer IS a proportion — how much of what was sent
/// has been opened. A donut would be the wrong mark: the two parts are not two
/// categories, they are a thing and its absence, and only one of them is worth
/// a colour.
class GaugeRing extends StatelessWidget {
  const GaugeRing({
    super.key,
    required this.value,
    required this.label,
    this.caption,
    this.size = 148,
  });

  /// 0…1. Clamped rather than trusted: a share over one is a bug upstream and
  /// should not become a ring drawn twice round.
  final double value;

  final String label;
  final String? caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fill = ChartPalette.sequential.of(context);
    final share = value.clamp(0.0, 1.0);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: size * 0.34,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(enabled: false),
                    sections: [
                      PieChartSectionData(
                        value: share == 0 ? 0.0001 : share,
                        color: fill,
                        radius: size * 0.16,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 1 - share,
                        color: ChartPalette.track(context),
                        radius: size * 0.16,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(share * 100).round()}%',
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// A list ranked by magnitude — the eight biggest trades, the file types of a
/// season.
///
/// Rows with the name ABOVE the bar rather than in a gutter beside it, and one
/// hue for every row. Both are about the labels: «مشرف الحملة الرئيسي» in a
/// left-hand gutter is either truncated to nothing or eats half the pane, and
/// colouring nine rows nine ways would need a palette whose ninth colour nobody
/// could tell from its third. The identity is written at the start of the row,
/// the number at the end, and the bar's LENGTH does the encoding.
///
/// The one mark on this page that is not plotted by the chart library, and for
/// that reason: a horizontal bar chart is trivial to draw and hard to label,
/// and the labelling is the whole job here.
class RankedBars extends StatelessWidget {
  const RankedBars({
    super.key,
    required this.slices,
    this.color,
    this.maxRows = 8,
  });

  final List<ChartSlice> slices;
  final Color? color;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? ChartPalette.sequential.of(context);

    final rows = [...slices]..sort((a, b) => b.value.compareTo(a.value));
    final shown = rows.take(maxRows).toList();
    // The scale is the biggest bar, not the total: this compares rows with each
    // other, and a share-of-whole reading is what [DonutChart] is for.
    final peak = shown.isEmpty ? 0 : shown.map((s) => s.value).reduce(math.max);

    if (shown.isEmpty || peak == 0) return const _EmptyTrack(height: 14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  shown[i].label,
                  style: text.bodySmall?.copyWith(color: scheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${shown[i].value}',
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _Bar(fraction: shown[i].value / peak, color: fill),
        ],
      ],
    );
  }
}

/// One horizontal measure: a recessive track with the value drawn over it.
class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  static const height = 8.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: ChartPalette.track(context)),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              // Never nothing: a row that exists but rounds to zero width reads
              // as a row that is missing.
              widthFactor: fraction.clamp(0.02, 1).toDouble(),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTrack extends StatelessWidget {
  const _EmptyTrack({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height / 2),
    child: SizedBox(
      height: height,
      child: ColoredBox(color: ChartPalette.track(context)),
    ),
  );
}

/// The ring a donut leaves behind when everything in it is zero — a shape in
/// the place the shape belongs, rather than a blank pane.
class _EmptyRing extends StatelessWidget {
  const _EmptyRing({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: ChartPalette.track(context), width: 14),
    ),
  );
}

/// One point of a [TrendChart].
class TrendPoint {
  const TrendPoint({required this.day, required this.value});

  final DateTime day;
  final num value;
}

/// A quantity over time — the reports a season files, day by day.
///
/// One series, so no legend: the card's own title names it. A curved 2px line
/// over a soft fill, which is what makes a run of days read as a shape rather
/// than as a row of numbers, and the fill closing to the baseline is what turns
/// the line into a QUANTITY: the area under it is the reports filed.
///
/// It has axes now, and that is the difference between a chart and a sparkline.
/// A shape with no scale beside it can only say "up"; a reader deciding whether
/// to act needs to know whether the peak is nine reports or ninety. Four
/// gridlines, no more — a dense grid on a pane this size competes with the line
/// it is meant to serve.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.emptyLabel,
    this.height = 190,
    this.labelForDay,
    this.axisLabelForDay,
  });

  final List<TrendPoint> points;
  final String emptyLabel;
  final double height;

  /// How to write a day in the tooltip. Left to the caller, which is the only
  /// place that knows the locale and the calendar the reader is on.
  final String Function(DateTime day)? labelForDay;

  /// The short form, for the axis, where there is room for about five words in
  /// total. Defaults to day/month.
  final String Function(DateTime day)? axisLabelForDay;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final line = ChartPalette.sequential.of(context);

    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            emptyLabel,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final peak = points.map((p) => p.value.toDouble()).reduce(math.max);
    final maxY = _niceCeiling(peak);
    final step = maxY / 4;
    // Roughly five dates across, whatever the window: thirty labels on a phone
    // is a grey smear where an axis should be.
    final labelEvery = math.max(1, (points.length / 5).ceil());

    final axisStyle = text.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return SizedBox(
      height: height,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (points.length - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            clipData: const FlClipData.vertical(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (_) => FlLine(
                color: ChartPalette.track(context),
                strokeWidth: 1,
                dashArray: const [4, 4],
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: ChartPalette.track(context)),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: step,
                  reservedSize: 34,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      // Whole units only. A count of reports has no halves, and
                      // an axis that says 2.5 is an axis nobody trusts.
                      value == value.roundToDouble()
                          ? '${value.round()}'
                          : '',
                      style: axisStyle,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 26,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    // The last day is always labelled: it is the one a reader
                    // looks for, and letting the interval decide would drop it
                    // whenever the count does not divide.
                    final show = i % labelEvery == 0 || i == points.length - 1;
                    if (!show) return const SizedBox.shrink();
                    final day = points[i].day;
                    return SideTitleWidget(
                      meta: meta,
                      space: 6,
                      child: Text(
                        axisLabelForDay?.call(day) ??
                            '${day.day}/${day.month}',
                        style: axisStyle,
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBorderRadius: BorderRadius.circular(AppRadius.sm),
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      '${points[spot.x.round()].value}\n',
                      TextStyle(
                        color: scheme.onInverseSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text:
                              labelForDay?.call(points[spot.x.round()].day) ??
                              '',
                          style: TextStyle(
                            color: scheme.onInverseSurface.withValues(
                              alpha: 0.75,
                            ),
                            fontWeight: FontWeight.w400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              getTouchedSpotIndicator: (bar, indices) => [
                for (final _ in indices)
                  TouchedSpotIndicatorData(
                    FlLine(color: line.withValues(alpha: 0.4), strokeWidth: 1),
                    FlDotData(
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: line,
                            // A ring of the pane's own colour, so the dot reads
                            // ON the fill rather than in it.
                            strokeColor: scheme.surface,
                            strokeWidth: 2,
                          ),
                    ),
                  ),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < points.length; i++)
                    FlSpot(i.toDouble(), points[i].value.toDouble()),
                ],
                isCurved: true,
                curveSmoothness: 0.2,
                preventCurveOverShooting: true,
                color: line,
                barWidth: 2,
                isStrokeCapRound: true,
                isStrokeJoinRound: true,
                // Dots only when the window is short enough for each to be a
                // day a reader can aim at. Thirty of them is a dotted line.
                dotData: FlDotData(
                  show: points.length <= 12,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 3,
                        color: line,
                        strokeColor: scheme.surface,
                        strokeWidth: 1.5,
                      ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      line.withValues(alpha: 0.28),
                      line.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A ceiling the axis can be divided into four whole steps by. Left at the
  /// raw peak, a maximum of 7 gives gridlines at 1.75 and an axis of decimals.
  static double _niceCeiling(double peak) {
    if (peak <= 0) return 4;
    final stepped = (peak / 4).ceil() * 4;
    return stepped.toDouble();
  }
}

/// A distribution across a fixed scale: how many ones, how many fives.
///
/// Vertical, because the scale is ordered and reads the way it is spoken. One
/// hue — the position on the axis IS the category, and colouring five bars five
/// ways would say the fives and the ones are unrelated things. A zero keeps its
/// place on the axis and is drawn as an empty track: a missing bar would say
/// the rating does not exist, and it does — nobody gave it.
class StarBars extends StatelessWidget {
  const StarBars({super.key, required this.counts, this.height = 168});

  /// Five entries, ones first.
  final List<int> counts;

  final double height;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fill = ChartPalette.sequential.of(context);
    final peak = counts.isEmpty ? 0 : counts.reduce(math.max);
    final maxY = peak <= 0 ? 4.0 : (peak / 4).ceil() * 4.0;

    return SizedBox(
      height: height,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) => FlLine(
                color: ChartPalette.track(context),
                strokeWidth: 1,
                dashArray: const [4, 4],
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: ChartPalette.track(context)),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: maxY / 4,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      value == value.roundToDouble() ? '${value.round()}' : '',
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${value.round() + 1}',
                          style: text.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.star_rounded,
                          size: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBorderRadius: BorderRadius.circular(AppRadius.sm),
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                fitInsideHorizontally: true,
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                      '${counts[group.x]}',
                      TextStyle(
                        color: scheme.onInverseSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < counts.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: counts[i].toDouble(),
                      color: counts[i] == 0
                          ? ChartPalette.track(context)
                          : fill,
                      width: 22,
                      // Rounded at the top, square at the baseline: the bar
                      // grows from the axis and should still look measured
                      // from it.
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: ChartPalette.track(context).withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
