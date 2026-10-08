import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/widgets/responsive.dart';

/// [AdaptiveGrid]'s whole answer to a monitor is "more columns, not a wider
/// column", so the count has to be right at every width the user can drag to —
/// and the tiles in a row have to end on the same line once they are side by
/// side, which they never had to do while a page was a single column.
///
/// The tile is a stand-in declared below rather than a real card from a screen.
/// It used to be `DashboardCard`, which went with the home grid; what is under
/// test here was never that card but the GRID, and half a dozen screens still
/// hand this widget their own cards — approvals, the audit log, complaints, the
/// dashboard. A local tile keeps the test about the thing it is named after,
/// and keeps it from being deleted again the next time a card is.
class _Tile extends StatelessWidget {
  const _Tile({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(width: 40, height: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                if (subtitle != null) Text(subtitle!),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  Widget inWindow(double width, Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );

  List<Widget> cards(int n, {List<String>? subtitles}) => [
    for (var i = 0; i < n; i++)
      _Tile(
        title: 'Tile $i',
        subtitle: subtitles == null ? 'One line' : subtitles[i],
      ),
  ];

  /// Every tile is an [Expanded] in its row, so counting the ones on the top
  /// row counts the columns.
  int columnsAt(WidgetTester tester) {
    final first = tester.getTopLeft(find.byType(_Tile).first).dy;
    return find
        .byType(_Tile)
        .evaluate()
        .where((e) => tester.getTopLeft(find.byWidget(e.widget)).dy == first)
        .length;
  }

  testWidgets('a phone gets one column', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(inWindow(392, AdaptiveGrid(children: cards(6))));

    expect(tester.takeException(), isNull);
    expect(columnsAt(tester), 1);
  });

  testWidgets('a half-screen window on a monitor gets two', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(inWindow(792, AdaptiveGrid(children: cards(6))));

    expect(columnsAt(tester), 2);
  });

  testWidgets('the grid beside a side panel on a 1600 monitor gets three', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(inWindow(1164, AdaptiveGrid(children: cards(6))));

    expect(columnsAt(tester), 3);
  });

  testWidgets('it stops at four however wide the monitor gets', (tester) async {
    tester.view.physicalSize = const Size(4000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(inWindow(3600, AdaptiveGrid(children: cards(8))));

    expect(columnsAt(tester), 4);
  });

  testWidgets('tiles in a row end on the same line whatever their subtitles do', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      inWindow(
        792,
        AdaptiveGrid(
          children: cards(
            2,
            subtitles: [
              'One line',
              'A subtitle long enough to wrap onto a second line in the room a '
                  'tile of this width has for it',
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final heights = find
        .byType(_Tile)
        .evaluate()
        .map((e) => tester.getSize(find.byWidget(e.widget)).height)
        .toSet();
    expect(heights, hasLength(1));
  });

  testWidgets('a short last row leaves its tiles in their columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Three tiles into two columns: the third sits alone on the second row and
    // must keep a column's width rather than spreading across both.
    await tester.pumpWidget(inWindow(792, AdaptiveGrid(children: cards(3))));

    final widths = find
        .byType(_Tile)
        .evaluate()
        .map((e) => tester.getSize(find.byWidget(e.widget)).width)
        .toSet();
    expect(widths, hasLength(1));
  });

  testWidgets('form fields keep their own heights and are never stretched', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // What a validation message under one field does to the field beside it:
    // with equalHeights the neighbour's box would grow to match and look wrong
    // when nothing is wrong with it.
    await tester.pumpWidget(
      inWindow(
        700,
        const AdaptiveGrid(
          minTileWidth: 300,
          maxColumns: 2,
          equalHeights: false,
          children: [
            TextField(),
            TextField(
              decoration: InputDecoration(errorText: 'This field is required'),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final heights = find
        .byType(TextField)
        .evaluate()
        .map((e) => tester.getSize(find.byWidget(e.widget)).height)
        .toList();
    expect(heights, hasLength(2));
    // The one carrying the error is taller; the untouched one did not grow.
    expect(heights[0], lessThan(heights[1]));
  });

  testWidgets('the size classes cut where they are meant to', (tester) async {
    expect(WindowSize.fromWidth(599), WindowSize.compact);
    expect(WindowSize.fromWidth(600), WindowSize.medium);
    expect(WindowSize.fromWidth(839), WindowSize.medium);
    expect(WindowSize.fromWidth(840), WindowSize.expanded);
    expect(WindowSize.fromWidth(1199), WindowSize.expanded);
    expect(WindowSize.fromWidth(1200), WindowSize.large);
    expect(WindowSize.fromWidth(1600), WindowSize.extraLarge);

    // The side panel appears exactly once there is room for it beside a grid.
    expect(WindowSize.expanded.hasSidePanel, isFalse);
    expect(WindowSize.large.hasSidePanel, isTrue);
  });
}
