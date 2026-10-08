import 'package:flutter/material.dart';

import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/responsive.dart';

/// A report's table, drawn the way the space it was given can actually hold it.
///
/// Every column is asked, with the real font at the real text scale, how wide
/// its longest line needs to be. What happens then is the whole of it:
///
///   * more room than that — the columns spread to fill it. A table that takes
///     its own intrinsic width sits at one end of a full-width card with a
///     third of the page empty beside it, which is what this used to do.
///   * less — the columns keep those widths and the table scrolls sideways.
///     Arabic does not survive being squeezed: past a certain narrowness the
///     wrapping stops respecting the spaces and breaks inside a word, leaving
///     the ة of المشرفة stranded on a line of its own. Scrolling is the better
///     of the two, and is what the mission asked for having seen both.
///   * a phone — one card per row. It is the one width where a table stops
///     being readable as a table at all; from a tablet upwards it stays one.
///
/// Which of the three was previously decided from the WINDOW SIZE and the
/// column count — "seventeen columns need extraLarge" — and a window is not
/// what a table has to fit inside. On a 1600 pixel monitor at 150% scaling the
/// app has 1067 logical pixels, so توزيع الوجبات على التكتلات fell to the phone
/// arrangement on a monitor: a stack of cards, each repeating every heading,
/// for a table whose whole point is reading one cluster against another.
///
/// The grid is a [Table] rather than a [DataTable] for the same reason it is
/// measured rather than assumed. A DataTable cannot be told to fill, and caps
/// its row height: the components of a meal are nine items and the last of them
/// was sliced off, with nothing to tell the reader it had gone.
class ReportTable extends StatelessWidget {
  const ReportTable({
    super.key,
    required this.columns,
    required this.rows,
    this.tagged = const {},
    this.spans = const {},
  });

  final List<String> columns;
  final List<List<String>> rows;

  /// Which columns hold a LIST rather than a sentence, by index.
  ///
  /// A meal's components are nine items, stored one per line because that is
  /// how the published document prints them. Drawn as nine lines they made the
  /// row nine lines tall and left the rest of the table sitting in a column of
  /// white; drawn as tags they flow across the width they are given and the row
  /// is two or three lines. Told rather than guessed from the text, because a
  /// paragraph in a written report's table has newlines in it too and is not a
  /// list.
  final Set<int> tagged;

  /// Which columns print a repeated value ONCE, against the rows it covers.
  ///
  /// مواعيد الوجبات prints the date once beside its three meals rather than
  /// three times, and a table that cannot do that is a table somebody rebuilds
  /// in Word. 0068 called it `spans_rows` and only a report TYPE could declare
  /// it; since 0102 any table block can.
  ///
  /// Flutter's [Table] has no row spanning, so this is not a merged cell — it
  /// is the same thing a merged cell LOOKS like: the value drawn on the first
  /// row of its run and the cells below it left blank, with the striping
  /// following the run rather than the row so the group reads as one block. The
  /// distinction matters only to whoever maintains this; on the page they are
  /// indistinguishable.
  final Set<int> spans;


  /// A header may claim more room than its own cells need, but only so much.
  ///
  /// Thirteen cluster columns all hold three-digit numbers, and letting the
  /// heading decide would give تكتل الكعبة المشرفة twice the width of تكتل عطاء
  /// for identical contents — a ragged grid that reads as a mistake. Past this
  /// the heading wraps instead, which costs one row of height once.
  static const _headerClaim = 2.0;

  /// How many of its own widest tags a list column may ask room for.
  ///
  /// One would be enough to never break a tag, and would stack nine components
  /// nine deep again. The whole width of the longest list would take the table.
  /// A few across is what makes them read as a list and still leave room for
  /// the columns they are being read against.
  static const _tagRun = 3.0;

  /// What a tag costs beyond its own text: the pill's padding and border.
  static const _tagExtra = 18.0;

  @override
  Widget build(BuildContext context) {
    if (columns.isEmpty || rows.isEmpty) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final scaler = MediaQuery.textScalerOf(context);

    final headerStyle = text.labelLarge?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    final cellStyle = text.bodySmall;

    // A dense table spends its width on its numbers, not on its gutters: at
    // twenty-odd columns the default padding is more of the column than the
    // three digits standing in it.
    final pad = columns.length > 14
        ? AppSpacing.xs
        : columns.length > 8
        ? AppSpacing.sm
        : AppSpacing.md;

    final natural = [
      for (var i = 0; i < columns.length; i++)
        _naturalWidth(i, headerStyle, cellStyle, scaler) + pad * 2,
    ];

    final wanted = natural.fold(0.0, (a, b) => a + b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth;
        // A phone is the one place a table stops being one. Everywhere from a
        // tablet upwards it stays a table, scrolling if it must — asked for in
        // as many words, and right: a row of a matrix means nothing read as a
        // list of labels.
        if (WindowSize.of(context) == WindowSize.compact) {
          return _Stacked(columns: columns, rows: rows, tagged: tagged);
        }

        final grid = _Grid(
          columns: columns,
          rows: rows,
          widths: natural,
          padding: pad,
          headerStyle: headerStyle,
          cellStyle: cellStyle,
          tagged: tagged,
          spans: spans,
          // Given more room than it wants, the table spreads to fill it rather
          // than huddling at one edge of the card. Given less, it keeps every
          // column at the width its longest line needs and lets the reader
          // scroll — which is the whole point of what follows.
          fill: room.isFinite && room >= wanted,
        );

        if (room.isFinite && room >= wanted) return grid;

        // Arabic does not survive being squeezed. Narrow the columns and the
        // wrapping does not stop at the spaces — a single word breaks across
        // two lines and the ة is left stranded on its own — so past the point
        // where the columns fit, the table scrolls sideways instead of getting
        // any narrower.
        return _SideScroller(width: wanted, child: grid);
      },
    );
  }

  /// What one column's contents want, measured rather than counted.
  ///
  /// Counting characters would have اليوم and المجموع the same width — "8 ذي
  /// الحجة - تروية" and "2565" are not the same width in any font. Only the
  /// longest LINE is measured, never the whole cell: seven ingredients on seven
  /// lines want the width of the longest of them, not the sum.
  double _naturalWidth(
    int index,
    TextStyle? headerStyle,
    TextStyle? cellStyle,
    TextScaler scaler,
  ) {
    final widest = tagged.contains(index)
        ? _tagRunWidth(index, cellStyle, scaler)
        : _widestLine(index, cellStyle, scaler);

    final header = _measure(columns[index], headerStyle, scaler);
    if (widest == 0) return header;
    if (widest >= header) return widest;

    // The heading is wider than anything under it, so it will have to wrap —
    // and it must be allowed to wrap BETWEEN ITS WORDS. Squeezed below its
    // longest word, تكتل الكعبة المشرفة broke inside the word and left the ة
    // alone on a line of its own, which is not a heading any more.
    var longestWord = 0.0;
    for (final word in columns[index].split(RegExp(r'\s+'))) {
      final w = _measure(word, headerStyle, scaler);
      if (w > longestWord) longestWord = w;
    }
    final allowance = widest * _headerClaim > longestWord
        ? widest * _headerClaim
        : longestWord;
    return header < allowance ? header : allowance;
  }

  double _widestLine(int index, TextStyle? style, TextScaler scaler) {
    var widest = 0.0;
    for (final row in rows) {
      if (index >= row.length) continue;
      for (final line in row[index].split('\n')) {
        final w = _measure(line, style, scaler);
        if (w > widest) widest = w;
      }
    }
    return widest;
  }

  /// A list column wants a few tags across, but never more than its longest
  /// list would fill: three short items should not be given the room nine long
  /// ones would need.
  double _tagRunWidth(int index, TextStyle? style, TextScaler scaler) {
    var widestTag = 0.0;
    var longestList = 0.0;
    for (final row in rows) {
      if (index >= row.length) continue;
      var line = 0.0;
      for (final tag in splitTags(row[index])) {
        final w = _measure(tag, style, scaler) + _tagExtra;
        if (w > widestTag) widestTag = w;
        line += w + AppSpacing.xs;
      }
      if (line > longestList) longestList = line;
    }
    final run = widestTag * _tagRun;
    return longestList < run ? longestList : run;
  }

  double _measure(String s, TextStyle? style, TextScaler scaler) {
    if (s.trim().isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: s.trim(), style: style),
      textDirection: TextDirection.rtl,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }
}

/// The items of a list cell, which the report stores one per line.
List<String> splitTags(String value) => [
  for (final t in value.split('\n'))
    if (t.trim().isNotEmpty) t.trim(),
];

/// The wide arrangement: an actual grid, striped so the eye keeps its row.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.columns,
    required this.rows,
    required this.widths,
    required this.padding,
    required this.headerStyle,
    required this.cellStyle,
    required this.tagged,
    required this.spans,
    required this.fill,
  });

  final List<String> columns;
  final List<List<String>> rows;
  final List<double> widths;

  /// Whether the columns spread to fill the room, or keep the width their
  /// longest line needs and let the page scroll to them.
  final bool fill;
  final double padding;
  final TextStyle? headerStyle;
  final TextStyle? cellStyle;
  final Set<int> tagged;
  final Set<int> spans;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String cell(List<String> row, int i) => i < row.length ? row[i] : '';

    // Which row each run of repeated values STARTS on, for every spanning
    // column. A cell whose run started above it draws nothing, which is what a
    // merged cell looks like; the one that started the run draws the value.
    bool startsRun(int row, int column) {
      if (row == 0) return true;
      return cell(rows[row], column) != cell(rows[row - 1], column);
    }

    // The stripe follows the FIRST spanning column's runs rather than the row
    // number, so a date and its three meals shade as one block. Without this
    // the merged value floats over an alternating background, which reads
    // worse than not merging at all.
    final leader = spans.isEmpty ? null : (spans.toList()..sort()).first;
    final groupOf = List<int>.filled(rows.length, 0);
    for (var i = 0; i < rows.length; i++) {
      if (leader == null) {
        groupOf[i] = i;
      } else if (i == 0) {
        groupOf[i] = 0;
      } else {
        groupOf[i] = startsRun(i, leader)
            ? groupOf[i - 1] + 1
            : groupOf[i - 1];
      }
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Table(
        columnWidths: {
          for (var i = 0; i < columns.length; i++)
            i: fill ? FlexColumnWidth(widths[i]) : FixedColumnWidth(widths[i]),
        },
        // A cell of one word beside a cell of nine tags reads as a mistake
        // unless they share a line to sit on.
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  width: 0.6,
                ),
              ),
            ),
            children: [
              for (final c in columns)
                _Cell(text: c, style: headerStyle, padding: padding),
            ],
          ),
          for (var i = 0; i < rows.length; i++)
            TableRow(
              // Striping rather than a line under every cell: a seventeen
              // column grid ruled both ways reads as graph paper.
              decoration: BoxDecoration(
                color: groupOf[i].isOdd
                    ? scheme.onSurface.withValues(alpha: 0.03)
                    : Colors.transparent,
              ),
              children: [
                for (var j = 0; j < columns.length; j++)
                  _Cell(
                    // A spanning column prints its value on the row its run
                    // starts and nothing on the rows it covers.
                    text: spans.contains(j) && !startsRun(i, j)
                        ? ''
                        : cell(rows[i], j),
                    style: cellStyle,
                    padding: padding,
                    isTags: tagged.contains(j),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.text,
    required this.style,
    required this.padding,
    this.isTags = false,
  });

  final String text;
  final TextStyle? style;
  final double padding;
  final bool isTags;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: AppSpacing.sm,
      ),
      // No maxLines and no ellipsis anywhere in here on purpose. A cut cell in
      // a report is worse than a tall one: the reader cannot tell that anything
      // was taken away.
      child: isTags
          ? TagRun(value: text, style: style)
          : Text(text, style: style),
    );
  }
}

/// A table too wide for its page, with somewhere to go.
///
/// The scrollbar is kept visible rather than fading in on touch: a table that
/// continues past the edge of the card with nothing to say so reads as a table
/// that has been cut off.
class _SideScroller extends StatefulWidget {
  const _SideScroller({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  State<_SideScroller> createState() => _SideScrollerState();
}

class _SideScrollerState extends State<_SideScroller> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        // Room for the bar itself, so it does not sit on the last row.
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: SizedBox(width: widget.width, child: widget.child),
      ),
    );
  }
}

/// A list cell's items, flowing rather than stacked.
class TagRun extends StatelessWidget {
  const TagRun({super.key, required this.value, this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tags = splitTags(value);
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.22),
                width: 0.6,
              ),
            ),
            child: Text(tag, style: style),
          ),
      ],
    );
  }
}

/// The narrow arrangement: one card per row, read downwards.
///
/// The first two columns become the card's heading — for all three meal
/// documents those are اليوم and الوجبة, which is exactly how somebody names
/// the row out loud. Everything else is a labelled line, and an empty cell is
/// left out rather than printed as a blank.
class _Stacked extends StatelessWidget {
  const _Stacked({
    required this.columns,
    required this.rows,
    required this.tagged,
  });

  final List<String> columns;
  final List<List<String>> rows;
  final Set<int> tagged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    String cell(List<String> row, int i) => i < row.length ? row[i] : '';

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var j = 0; j < 2 && j < columns.length; j++)
                      if (cell(rows[i], j).isNotEmpty)
                        Text(
                          cell(rows[i], j),
                          style: text.titleSmall?.copyWith(
                            color: j == 0 ? scheme.onSurface : scheme.primary,
                          ),
                        ),
                  ],
                ),
                for (var j = 2; j < columns.length; j++)
                  if (cell(rows[i], j).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 104,
                            child: Text(
                              columns[j],
                              style: text.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: tagged.contains(j)
                                ? TagRun(
                                    value: cell(rows[i], j),
                                    style: text.bodyMedium,
                                  )
                                : Text(
                                    cell(rows[i], j),
                                    style: text.bodyMedium,
                                  ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
