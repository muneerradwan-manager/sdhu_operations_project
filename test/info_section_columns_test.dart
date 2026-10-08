import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/widgets/info_section.dart';
import 'package:sdhu_operations_project/core/widgets/responsive.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

/// A profile is a dozen short values — a first name, a city, a date. One per
/// line spends a monitor's width on the emptiness after each one, so the pane
/// puts as many across as its own width allows. Two things must hold while it
/// does: a pane that was never widened must not change shape, and fields that
/// end up side by side must end on the same line.
void main() {
  Widget inPane(double width, Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );

  InfoSection section(int fields, {List<String?>? values}) => InfoSection(
    title: 'Personal',
    icon: Icons.person,
    children: [
      for (var i = 0; i < fields; i++)
        InfoRow(
          icon: Icons.person,
          label: 'Field $i',
          value: values == null ? 'Value' : values[i],
        ),
    ],
  );

  /// Every field is an [Expanded] in its row, so counting the ones sharing the
  /// top row's y counts the columns — but only ever within ONE pane. Three
  /// panes standing side by side each have a top row of their own, and counting
  /// across all of them counts panes, not columns.
  int columnsIn(WidgetTester tester, [int pane = 0]) {
    final rows = find.descendant(
      of: find.byType(InfoSection).at(pane),
      matching: find.byType(InfoRow),
    );
    final tops = rows
        .evaluate()
        .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy)
        .toList();
    final first = tops.reduce((a, b) => a < b ? a : b);
    return tops.where((t) => t == first).length;
  }

  int columnsAt(WidgetTester tester) => columnsIn(tester);

  testWidgets('a phone keeps one field per line', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(inPane(360, section(7)));

    expect(tester.takeException(), isNull);
    expect(columnsAt(tester), 1);
  });

  testWidgets('a pane still inside the old 600 cap does not change shape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 600 less the page gutters — what every screen not yet revisited hands it.
    await tester.pumpWidget(inPane(568, section(7)));

    expect(columnsAt(tester), 1);
  });

  testWidgets('the width beside a side panel on a 1200 window gets two', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(inPane(784, section(7)));

    expect(columnsAt(tester), 2);
  });

  testWidgets('a 1400 window gets three, and stops there', (tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(inPane(984, section(7)));
    expect(columnsAt(tester), 3);

    // Room for four and then some, still three.
    await tester.pumpWidget(inPane(1600, section(7)));
    expect(columnsAt(tester), 3);
  });

  testWidgets('fields on one line end on one line, however long the value', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      inPane(
        984,
        section(
          3,
          values: [
            'Short',
            'An address long enough to wrap onto a second line in the room a '
                'field of this width leaves for it',
            null, // "not provided"
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final heights = find
        .byType(InfoRow)
        .evaluate()
        .map((e) => tester.getSize(find.byWidget(e.widget)).height)
        .toSet();
    expect(heights, hasLength(1));
  });

  testWidgets('three panes side by side in one equal-height row survive it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The settings page, and the crash it caused: an equal-height row measures
    // its cells by asking each for an intrinsic height, and a LayoutBuilder
    // will not answer that question. The pane has to take its width from the
    // grid instead of measuring it again — see GridCellWidth.
    await tester.pumpWidget(
      inPane(
        1336,
        AdaptiveGrid(
          minTileWidth: 320,
          maxColumns: 3,
          children: [section(3), section(3), section(1)],
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    // All three stand in one row, at one height.
    final panes = find
        .byType(InfoSection)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
    expect(panes, hasLength(3));
    expect(panes.map((r) => r.top).toSet(), hasLength(1));
    expect(panes.map((r) => r.height).toSet(), hasLength(1));

    // And each pane, now about 430 wide, still keeps its fields in one column.
    for (var pane = 0; pane < 3; pane++) {
      expect(columnsIn(tester, pane), 1);
    }
  });

  testWidgets('a pane in a grid columnises off the width it was handed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // One cell of a two-column grid across 1900 is ~940 — wide enough for three
    // fields, exactly as it would be if the pane had measured itself.
    await tester.pumpWidget(
      inPane(
        1900,
        AdaptiveGrid(
          minTileWidth: 800,
          maxColumns: 2,
          children: [section(7), section(7)],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(columnsIn(tester, 0), 3);
    expect(columnsIn(tester, 1), 3);
  });

  testWidgets('a short last row leaves its fields in their columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Seven fields into three columns: the seventh sits alone and must keep a
    // column's width rather than spreading across the pane.
    await tester.pumpWidget(inPane(984, section(7)));

    final widths = find
        .byType(InfoRow)
        .evaluate()
        .map((e) => tester.getSize(find.byWidget(e.widget)).width)
        .toSet();
    expect(widths, hasLength(1));
  });
}
