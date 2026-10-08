import 'package:flutter/material.dart';

import '../theme/glass_tokens.dart';

/// The standing panel's width wherever a page has one.
///
/// Wide enough for a face, a name and a job title on two lines; narrow enough
/// that the content beside it still gets three columns on a 1600 monitor. It is
/// one number for the whole app on purpose — a user who drags a window learns
/// where this app keeps that column, and learns it once.
const kSidePanelWidth = 320.0;

/// Where a snack bar stops growing.
///
/// A floating snack bar is as wide as the window less its margins, which is the
/// right answer on a phone and a poor one on a monitor: four words of
/// confirmation smeared across 1600 pixels, with the action button parked at
/// the far end of that journey. Past this the bar keeps a readable shape and
/// takes the middle instead.
const kSnackBarMaxWidth = 560.0;

/// How much room a layout has, in five steps.
///
/// Named for the room and not for the device, because the device stopped being
/// the question the moment this app ran on Windows and the web. A phone is
/// always [compact] and a monitor rarely is, but that is a coincidence: the
/// width there is something the user drags around all afternoon, not a property
/// of the hardware. A screen that only knows "phone or desktop" spends that
/// afternoon snapping between two wrong answers.
///
/// The cuts are Material 3's window size classes, and they are not arbitrary
/// round numbers — each one is the width at which one more column of readable
/// content fits beside the last.
enum WindowSize {
  compact(0),
  medium(600),
  expanded(840),
  large(1200),
  extraLarge(1600);

  const WindowSize(this.minWidth);

  /// The narrowest width that still belongs to this class.
  final double minWidth;

  static WindowSize fromWidth(double width) {
    for (final size in values.reversed) {
      if (width >= size.minWidth) return size;
    }
    return compact;
  }

  /// The window's own class.
  ///
  /// For the chrome that spans the whole window — an app bar, a rail. Anything
  /// laying out *inside* the page should measure its own box instead; see
  /// [WindowSizeBuilder].
  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool isAtLeast(WindowSize other) => index >= other.index;

  /// Where the content stops growing.
  ///
  /// A column of text does not get more readable past roughly seventy
  /// characters — on the way back the eye loses which line comes next, and it
  /// loses it more often the further it has to travel. So the answer to a wider
  /// window is never a wider column. It is a second column, then a third, and
  /// then it is nothing at all: this cap is what stops a 34" monitor from
  /// printing one paragraph across a metre of glass.
  double get contentMaxWidth => switch (this) {
    WindowSize.compact => double.infinity,
    WindowSize.medium => 720,
    WindowSize.expanded => 1100,
    WindowSize.large => 1400,
    WindowSize.extraLarge => 1680,
  };

  /// Breathing room at the page edges, which has to grow with the window: the
  /// 16px margin that reads as generous beside a phone's screen edge reads as a
  /// cropping accident at 1600.
  double get gutter => switch (this) {
    WindowSize.compact => AppSpacing.lg,
    WindowSize.medium => AppSpacing.xl,
    WindowSize.expanded => AppSpacing.xl,
    WindowSize.large => AppSpacing.xxl,
    WindowSize.extraLarge => AppSpacing.xxl,
  };

  /// Whether there is room to stand a panel beside the content instead of
  /// stacking it on top.
  ///
  /// Below this the split costs more than it pays: two columns of 400 are worse
  /// than one column of 800, because neither is wide enough to hold anything
  /// and the page has twice as many edges.
  bool get hasSidePanel => isAtLeast(WindowSize.large);
}

extension WindowSizeX on BuildContext {
  /// The window's size class. See [WindowSize.of] for when *not* to use it.
  WindowSize get windowSize => WindowSize.of(this);
}

/// How wide a page is allowed to get, chosen by what the page HOLDS.
///
/// There used to be no answer to this question, and the result was twelve of
/// them. Screens capped themselves at 520, 560, 640, 700, 720, 820, 860, 900,
/// 1100 and 1200, or at nothing at all — numbers picked one screen at a time by
/// whoever was looking at that screen that afternoon, each defensible alone and
/// none of them agreeing with the next. A reader moving from القرارات (1200) to
/// الموظفون (1680) to مهامي (900) watched the page jump width three times
/// without changing what it was doing, which reads as three different
/// applications rather than three sections of one.
///
/// So a page no longer picks a number. It says what kind of thing it is, and
/// the kind carries the number — which means the number can be re-tuned once,
/// here, for the whole app.
///
/// Four kinds, and the boundaries between them are about READING rather than
/// about taste:
enum PageWidth {
  /// One column of fields and a button under them.
  ///
  /// A form is typed into, and a text box a metre wide is harder to write in,
  /// not easier: the eye loses the start of the line on the way back. 640 is
  /// about as wide as a field can be before that starts.
  ///
  /// Raising an urgent report, showing a place's code, choosing what to export,
  /// assigning an evaluation.
  form(640),

  /// A document read from top to bottom: a decision, a complaint and its
  /// replies, a filled evaluation sheet, a person's own attendance.
  ///
  /// The classic measure — a column of prose stops being readable past roughly
  /// seventy characters, and past that the answer is never a wider column.
  reading(900),

  /// A form big enough to be laid out in columns of its own: the profile
  /// questionnaire, the file editor, the employee record.
  ///
  /// Wider than [form] because the fields inside are already gridded — the
  /// width is spent on a second and third column of fields rather than on
  /// making any one of them longer.
  editor(1100),

  /// Everything that is a list, a grid or a board.
  ///
  /// The only kind with no fixed number: it grows with the window by
  /// [WindowSize.contentMaxWidth], because the answer to a wider window here is
  /// one more column and eventually nothing at all.
  browse(null);

  const PageWidth(this._fixed);

  final double? _fixed;

  /// The cap for this kind at [size].
  double of(WindowSize size) => _fixed ?? size.contentMaxWidth;
}

/// How wide one card wants to be before the grid drops a column.
///
/// The companion to [PageWidth], and the half that decides how many things a
/// reader sees at once. These were ten different numbers — 150, 200, 220, 300,
/// 320, 340, 360, 380, 420 and infinity — so الشكاوى showed two cards on the
/// monitor where الموظفون showed four, and neither could say why.
///
/// [list] is the one that matters, because nearly everything in this app is a
/// list of cards. Against the four page caps it gives:
///
/// ```
///   medium      720 →  2 columns of 354
///   expanded   1100 →  3 columns of 358
///   large      1400 →  4 columns of 341
///   extraLarge 1680 →  4 columns of 411
/// ```
///
/// — which is the whole point: الشكاوى and الموظفون and القرارات and البلاغات
/// now break at the same widths and show the same number of cards, because they
/// are the same size of thing.
class CardWidth {
  const CardWidth._();

  /// A card: a title, a line or two under it, and some badges. The default, and
  /// what every list in the app should be using.
  static const list = 340.0;

  /// A card standing INSIDE another card — a member of a team, drawn on the
  /// pane that holds the team.
  ///
  /// [list] less the pane's own padding, and derived rather than typed so it
  /// cannot drift: a nested grid that used its own number broke a column
  /// earlier than the page it was sitting on, which reads as the inner grid
  /// being wrong rather than as the pane being narrow.
  static const nested = list - AppSpacing.lg;

  /// A stat: a number and the word for it. Four or more to a row, because a
  /// dashboard is read at a glance and a row of two numbers is not a dashboard.
  static const stat = 200.0;

  /// A tile: a mark and a word, nothing else. The home page's الإدارة grid,
  /// where a reader holding every permission is handed a dozen.
  static const tile = 150.0;

  /// One per row, whatever the window. A report's own table, a message in a
  /// thread, a section of a file — things that are already as wide as the page
  /// and would be cut in half by a column.
  static const full = double.infinity;
}

/// A [LayoutBuilder] that reports a [WindowSize] measured from the space this
/// widget was actually handed.
///
/// Prefer it over reading [MediaQuery]: the two disagree the moment the widget
/// sits inside anything narrower than the window — a pane, a sheet, a side
/// panel — and it is the pane's width that decides what fits inside the pane.
class WindowSizeBuilder extends StatelessWidget {
  const WindowSizeBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, WindowSize size) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          builder(context, WindowSize.fromWidth(constraints.maxWidth)),
    );
  }
}

/// Holds every snack bar below it to [kSnackBarMaxWidth], centred, once the
/// window is wide enough for that to mean anything.
///
/// This cannot live in the app theme, even though it is a theme value:
/// [SnackBarThemeData.width] is a fixed width rather than a maximum, and
/// setting it also tells the snack bar to drop its side margins. On a phone
/// that lands the bar flat against both screen edges — worse than the problem
/// it fixes. So the cap is applied here, where the window's width is known and
/// can be left alone when there is nothing to cap.
class SnackBarWidthCap extends StatelessWidget {
  const SnackBarWidthCap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // What the bar would take on its own: the window, less the margins the
    // theme's insetPadding leaves it.
    final natural = MediaQuery.sizeOf(context).width - AppSpacing.lg * 2;
    if (natural <= kSnackBarMaxWidth) return child;

    return Theme(
      data: theme.copyWith(
        snackBarTheme: theme.snackBarTheme.copyWith(width: kSnackBarMaxWidth),
      ),
      child: child,
    );
  }
}

/// Centres content under a cap that grows with the window, with page gutters to
/// match.
///
/// The one-size version of this idea — cap everything at 600 forever — is what
/// makes a desktop build look like a phone screenshot pasted into the middle of
/// a monitor. The cap is still there, because the reason for it is real, but it
/// is a different number at every size and the space it leaves over goes to the
/// content rather than to the wallpaper.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.builder,
    this.width = PageWidth.browse,
  });

  final Widget Function(BuildContext context, WindowSize size) builder;

  /// What kind of page this is, which is what decides how wide it may get.
  ///
  /// A KIND rather than a number, and deliberately: the number is a decision
  /// about the whole app and belongs in one place. See [PageWidth] for the four
  /// of them and for the twelve that came before.
  final PageWidth width;

  @override
  Widget build(BuildContext context) {
    return WindowSizeBuilder(
      builder: (context, size) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width.of(size)),
          child: builder(context, size),
        ),
      ),
    );
  }
}

/// The narrow arrangement, and the one every phone gets: a single scrolling
/// column carrying the page's gutters.
class SinglePaneLayout extends StatelessWidget {
  const SinglePaneLayout({
    super.key,
    required this.gutter,
    required this.children,
    this.onRefresh,
    this.bottom = AppSpacing.xl,
    this.keyboardDismiss = ScrollViewKeyboardDismissBehavior.manual,
  });

  final double gutter;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double bottom;
  final ScrollViewKeyboardDismissBehavior keyboardDismiss;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: context.scrollPadding(horizontal: gutter, bottom: bottom),
      keyboardDismissBehavior: keyboardDismiss,
      children: children,
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// The wide arrangement: a panel that stands still on the leading side while
/// the content scrolls past it.
///
/// The panel is first in the [Row] and therefore on the *start* side — the
/// right in Arabic, the left in English — without anyone naming a side.
///
/// It is deliberately outside the scrollable. What goes in it is the handful of
/// facts that frame everything else on the page — who this is, which season is
/// being worked through — and on a monitor there is room to leave them on the
/// glass instead of making the user scroll back up to check.
class TwoPaneLayout extends StatelessWidget {
  const TwoPaneLayout({
    super.key,
    required this.gutter,
    required this.panel,
    required this.children,
    this.onRefresh,
    this.panelWidth = kSidePanelWidth,
    this.bottom = AppSpacing.xl,
    this.keyboardDismiss = ScrollViewKeyboardDismissBehavior.manual,
  });

  final double gutter;
  final Widget panel;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double panelWidth;
  final double bottom;
  final ScrollViewKeyboardDismissBehavior keyboardDismiss;

  @override
  Widget build(BuildContext context) {
    // The page's own gutter is applied once, around both panes; each pane then
    // carries only the vertical inset, so the two start on the same line.
    final page = context.scrollPadding(horizontal: gutter, bottom: bottom);
    final vertical = EdgeInsets.only(top: page.top, bottom: page.bottom);

    Widget content = ListView(
      padding: vertical,
      keyboardDismissBehavior: keyboardDismiss,
      children: children,
    );
    if (onRefresh != null) {
      content = RefreshIndicator(onRefresh: onRefresh!, child: content);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Row(
        // The panel hugs its content and stays at the top rather than
        // stretching to the full height of a monitor.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: panelWidth,
            // Its own scrollable, for the short window: a laptop in a video
            // call is 1440 wide and 500 tall, and the panel has to give way
            // there rather than overflow.
            child: SingleChildScrollView(padding: vertical, child: panel),
          ),
          SizedBox(width: gutter),
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// Lays [children] out in as many equal columns as fit, and never fewer than
/// one.
///
/// The column count comes from [minTileWidth] rather than from a [WindowSize]
/// step, because this is the widget under the user's hand while they drag the
/// window edge. Re-columning on the page's five thresholds would move the grid
/// in visible jumps at moments that have nothing to do with the grid; measuring
/// the tiles means they widen smoothly until there is room for one more, and
/// only then do they all snap back together. That is what every desktop grid
/// does, and it is why it feels like the window is being resized rather than
/// the app being switched.
///
/// Rows are [IntrinsicHeight] so neighbours end at the same line — see
/// [equalHeights] for when they should not be.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = CardWidth.list,
    this.maxColumns = 4,
    this.spacing = AppSpacing.md,
    this.equalHeights = true,
  });

  final List<Widget> children;

  /// The narrowest a card may get before the grid drops a column.
  ///
  /// One of [CardWidth], never a number written here: it is what decides how
  /// many things a reader sees at once, and every list in this app has to
  /// answer that the same way or the app reads as several.
  final double minTileWidth;

  /// A ceiling on the count regardless of room. Past four across, a dashboard
  /// stops being a set of places you can point at and becomes a wall to read.
  final int maxColumns;

  final double spacing;

  /// Whether tiles sharing a row are forced to the same height.
  ///
  /// True for panes — a row of glass cards with three different bottom edges
  /// reads as broken rather than as varied. False for form fields, where a
  /// validation message appearing under one field would otherwise stretch its
  /// neighbour's box to match and make the untouched field look wrong too.
  final bool equalHeights;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          constraints.maxWidth,
          minTileWidth: minTileWidth,
          maxColumns: maxColumns,
          spacing: spacing,
        );

        final cellWidth = cellWidthFor(constraints.maxWidth, columns, spacing);

        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          rows.add(
            columns == 1
                ? children[start]
                : gridRow(
                    start: start,
                    columns: columns,
                    itemCount: children.length,
                    spacing: spacing,
                    equalHeights: equalHeights,
                    cellWidth: cellWidth,
                    itemBuilder: (_, i) => children[i],
                  ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

/// Lays [children] into independent columns that each flow top to bottom on
/// their own, rather than into rows that share a height.
///
/// [AdaptiveGrid] puts children into a grid by POSITION: item *n* always
/// falls in row *n ~/ columns*, so two neighbours on the same row are held to
/// the same height even when [equalHeights] is false — the row itself still
/// does not end until its tallest member does. That is invisible when every
/// card is roughly the same size, and it is a wall of empty glass under the
/// short one the moment they are not: a permission group of two sitting next
/// to a permission group of fifteen loses thirteen rows of nothing under it,
/// which is exactly the gap this widget was written to close. Bin-packing by
/// column instead of by row means a short card is simply followed by the next
/// card in ITS column — there is no row for the tall neighbour to hold open.
///
/// This is the price a masonry grid always charges: reading order becomes
/// column-then-row rather than the row-then-column [AdaptiveGrid] keeps, so a
/// reader scanning top to bottom in the first column meets item 4 before item
/// 2 if item 2 landed in the second column. Fine for a catalog of independent
/// groups — nobody reads "الملفات" only after finishing "المواسم" — wrong for
/// anything where the sequence itself is the content.
///
/// Columns are balanced by [weightOf], an estimate of each child's height
/// (its row count is a good proxy — see the permission screens for how they
/// build one), not by counting children: two five-row sections belong on
/// different columns from one thirty-row section even though "two" is more
/// than "one".
class MasonryGrid extends StatelessWidget {
  const MasonryGrid({
    super.key,
    required this.children,
    required this.weightOf,
    this.minTileWidth = CardWidth.list,
    this.maxColumns = 4,
    this.spacing = AppSpacing.md,
  });

  final List<Widget> children;

  /// The estimated height of `children[index]`, in the same unit for every
  /// index — only the relative sizes matter, since this is what balances the
  /// columns against each other.
  final double Function(int index) weightOf;

  /// See [AdaptiveGrid.minTileWidth].
  final double minTileWidth;

  /// See [AdaptiveGrid.maxColumns].
  final int maxColumns;

  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          constraints.maxWidth,
          minTileWidth: minTileWidth,
          maxColumns: maxColumns,
          spacing: spacing,
        );

        if (columns == 1) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }

        // Greedy bin-packing: each child, in order, goes to whichever column
        // is currently shortest. Simple rather than optimal — an optimal
        // packing is not worth chasing for a handful of sections that change
        // rarely, and greedy keeps the columns visibly balanced regardless.
        final buckets = List.generate(columns, (_) => <Widget>[]);
        final totals = List.filled(columns, 0.0);
        for (var i = 0; i < children.length; i++) {
          var shortest = 0;
          for (var c = 1; c < columns; c++) {
            if (totals[c] < totals[shortest]) shortest = c;
          }
          if (buckets[shortest].isNotEmpty) {
            buckets[shortest].add(SizedBox(height: spacing));
          }
          buckets[shortest].add(children[i]);
          totals[shortest] += weightOf(i) + spacing;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) SizedBox(width: spacing),
              Expanded(child: Column(children: buckets[c])),
            ],
          ],
        );
      },
    );
  }
}

/// One run of cards under a heading, for [AdaptiveGridView.sectioned].
///
/// The cards are given as a count and a builder rather than as a list, for the
/// same reason the flat grid takes them that way: a section of an inbox is
/// still part of a lazily-built list, and a heading in the middle of it must
/// not cost the rows below the fold their laziness.
class GridSection {
  const GridSection({
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
  });

  /// The full-width line above this section's cards. A section with no cards
  /// draws nothing at all, header included — an empty heading is a promise the
  /// list then fails to keep.
  final Widget header;

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
}

/// The lazy form of [AdaptiveGrid]: a scrollable whose rows are built as they
/// are reached.
///
/// [AdaptiveGrid] builds every child at once, which is right for a dashboard of
/// seven tiles and wrong for a directory of four hundred employees — there, it
/// is the difference between a screen that opens and one that thinks about it
/// first. This is the same arithmetic with a [ListView.builder] under it: the
/// grid is a list of ROWS, so a row of three cards is one lazily-built item and
/// nothing below the fold is laid out until it is scrolled to.
///
/// [GridView] would also be lazy, but it insists on being told a tile's aspect
/// ratio in advance. Nothing in this app has one — a card is as tall as its
/// name, its dates and however many badges it turned out to carry.
class AdaptiveGridView extends StatelessWidget {
  const AdaptiveGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minTileWidth = CardWidth.list,
    this.maxColumns = 4,
    this.spacing = AppSpacing.md,
    this.equalHeights = true,
    this.padding,
    this.header,
    this.footer,
    this.controller,
    this.onRefresh,
  }) : sections = null;

  /// The same grid, cut into headed groups: a day of an inbox, a status, a
  /// season. The columns are counted once for the whole list, so a heading
  /// never re-flows the cards under it — every section breaks at the same
  /// widths, which is what makes the groups read as one list rather than as
  /// several stacked grids.
  const AdaptiveGridView.sectioned({
    super.key,
    required List<GridSection> this.sections,
    this.minTileWidth = CardWidth.list,
    this.maxColumns = 4,
    this.spacing = AppSpacing.md,
    this.equalHeights = true,
    this.padding,
    this.header,
    this.footer,
    this.controller,
    this.onRefresh,
  }) : itemCount = 0,
       itemBuilder = _noItem;

  static Widget _noItem(BuildContext context, int index) =>
      const SizedBox.shrink();

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// The groups, when this grid draws groups; null for the flat form.
  final List<GridSection>? sections;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;
  final bool equalHeights;
  final EdgeInsets? padding;

  /// Anything that belongs above the grid and spans its full width — a search
  /// field, a count, a heading. It scrolls away with the rows rather than
  /// sitting on top of them, because on a long list the first thing wanted is
  /// the list.
  final Widget? header;

  /// The full-width row under the last one — a "loading more" spinner, a total.
  final Widget? footer;

  /// For a list that pages in more as it is scrolled: the same controller the
  /// caller watches.
  final ScrollController? controller;

  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inner = constraints.maxWidth - (padding?.horizontal ?? 0);
        final columns = columnsFor(
          inner,
          minTileWidth: minTileWidth,
          maxColumns: maxColumns,
          spacing: spacing,
        );
        final cellWidth = cellWidthFor(inner, columns, spacing);

        Widget list = sections == null
            ? _flat(columns, cellWidth)
            : _sectioned(columns, cellWidth);

        if (onRefresh != null) {
          list = RefreshIndicator(onRefresh: onRefresh!, child: list);
        }
        return list;
      },
    );
  }

  /// One run of cards: the line number IS the row number, so nothing about the
  /// list has to be worked out in advance.
  Widget _flat(int columns, double cellWidth) {
    final rows = (itemCount + columns - 1) ~/ columns;
    final lead = header == null ? 0 : 1;
    final tail = footer == null ? 0 : 1;

    return ListView.separated(
      controller: controller,
      padding: padding,
      itemCount: rows + lead + tail,
      separatorBuilder: (_, _) => SizedBox(height: spacing),
      itemBuilder: (context, i) {
        if (i < lead) return header!;
        if (i >= rows + lead) return footer!;
        final start = (i - lead) * columns;
        return columns == 1
            ? itemBuilder(context, start)
            : gridRow(
                start: start,
                columns: columns,
                itemCount: itemCount,
                spacing: spacing,
                equalHeights: equalHeights,
                cellWidth: cellWidth,
                itemBuilder: itemBuilder,
              );
      },
    );
  }

  /// Headings interleaved with rows, so the line number no longer says which
  /// row of which section it is. Which line is what is worked out up front —
  /// but only as a list of CLOSURES: laying the plan out costs one entry per
  /// heading and per row, and nothing inside an entry runs until the list is
  /// scrolled that far, so the cards stay as lazy as they are in [_flat].
  Widget _sectioned(int columns, double cellWidth) {
    final lines = <Widget Function(BuildContext context)>[];
    if (header != null) lines.add((_) => header!);
    for (final section in sections!) {
      if (section.itemCount == 0) continue;
      lines.add((_) => section.header);
      for (var start = 0; start < section.itemCount; start += columns) {
        lines.add(
          (context) => columns == 1
              ? section.itemBuilder(context, start)
              : gridRow(
                  start: start,
                  columns: columns,
                  itemCount: section.itemCount,
                  spacing: spacing,
                  equalHeights: equalHeights,
                  cellWidth: cellWidth,
                  itemBuilder: section.itemBuilder,
                ),
        );
      }
    }
    if (footer != null) lines.add((_) => footer!);

    return ListView.separated(
      controller: controller,
      padding: padding,
      itemCount: lines.length,
      separatorBuilder: (_, _) => SizedBox(height: spacing),
      itemBuilder: (context, i) => lines[i](context),
    );
  }
}

/// The width [AdaptiveGrid] gave the cell this widget is sitting in.
///
/// A cell that needs to know its own width would reach for a [LayoutBuilder] —
/// and that is exactly what it must not do here. A LayoutBuilder refuses to
/// report intrinsic dimensions (it would have to run its callback
/// speculatively, mid-layout, against a live tree), and an equal-height row is
/// built by asking every cell for precisely that. One [InfoSection] in a row of
/// three took the settings page down with it.
///
/// The grid already worked this number out. Handing it down is what lets a cell
/// re-flow to its own width AND be measured by the row around it.
class GridCellWidth extends InheritedWidget {
  const GridCellWidth({super.key, required this.width, required super.child});

  final double width;

  /// Null outside a grid — where a [LayoutBuilder] is safe, and correct.
  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GridCellWidth>()?.width;

  @override
  bool updateShouldNotify(GridCellWidth oldWidget) => oldWidget.width != width;
}

/// How many columns of at least [minTileWidth] fit in [width], counting the
/// [spacing] between them. Never fewer than one, never more than [maxColumns].
int columnsFor(
  double width, {
  required double minTileWidth,
  required int maxColumns,
  double spacing = AppSpacing.md,
}) {
  if (!width.isFinite || width <= 0) return 1;
  return ((width + spacing) ~/ (minTileWidth + spacing)).clamp(1, maxColumns);
}

/// One row of a grid: [columns] equal cells, of which the ones past [itemCount]
/// are empty.
///
/// The empty cells of a short final row still claim a column's width, so the
/// tiles above them stay in their columns instead of spreading out to fill the
/// gap and leaving the grid ragged.
Widget gridRow({
  required int start,
  required int columns,
  required int itemCount,
  required double spacing,
  required bool equalHeights,
  required double cellWidth,
  required Widget Function(BuildContext context, int index) itemBuilder,
}) {
  final row = Builder(
    builder: (context) => Row(
      crossAxisAlignment: equalHeights
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(
            child: GridCellWidth(
              width: cellWidth,
              child: start + i < itemCount
                  ? itemBuilder(context, start + i)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    ),
  );
  return equalHeights ? IntrinsicHeight(child: row) : row;
}

/// The width one cell gets when [columns] of them share [width] with [spacing]
/// between.
double cellWidthFor(double width, int columns, double spacing) =>
    (width - spacing * (columns - 1)) / columns;
