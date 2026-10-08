import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/widgets/glass.dart';
import 'package:sdhu_operations_project/core/widgets/states.dart';

/// A skeleton earns its place by being the SHAPE of what is coming — that is
/// the whole reason it beats a spinner. Which makes the wrong shape worse than
/// no shape: one column of full-width bars on a window about to fill with four
/// columns promises one thing, delivers another, and the swap at the end reads
/// as the page jumping rather than arriving. It also promised a list four times
/// longer than the one that came.
void main() {
  Widget inWindow(double width, double height, Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: width, height: height, child: child)),
    ),
  );

  /// The placeholders are [GlassSurface]s; the ones sharing the top row are the
  /// columns.
  int columnsAt(WidgetTester tester) {
    final tops = find
        .byType(GlassSurface)
        .evaluate()
        .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy)
        .toList();
    final first = tops.reduce((a, b) => a < b ? a : b);
    return tops.where((t) => t == first).length;
  }

  int placeholders(WidgetTester tester) =>
      find.byType(GlassSurface).evaluate().length;

  testWidgets('a phone gets the single column it is about to get', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      inWindow(392, 900, const SkeletonList(count: 5, minTileWidth: 300)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(columnsAt(tester), 1);
    // Five rows of one.
    expect(placeholders(tester), 5);
  });

  testWidgets('a monitor gets the same grid the content will fill', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      inWindow(1400, 900, const SkeletonList(count: 5, minTileWidth: 300)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    final columns = columnsAt(tester);
    expect(columns, greaterThan(1));
    // `count` is ROWS: the grid fills out sideways rather than staying a
    // five-item column with an empty screen beside it.
    expect(placeholders(tester), 5 * columns);
  });

  testWidgets('a screen that stands a panel gets a panel-shaped placeholder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      inWindow(
        1400,
        900,
        const SkeletonList(count: 3, minTileWidth: 300, panel: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    // The leading placeholder is the panel: 320 wide and much taller than a row.
    final widths = find
        .byType(GlassSurface)
        .evaluate()
        .map((e) => tester.getSize(find.byWidget(e.widget)))
        .toList();
    expect(widths.any((s) => s.width == 320 && s.height > 200), isTrue);
  });

  testWidgets('the panel is dropped on a window with no room for one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      inWindow(
        700,
        900,
        const SkeletonList(count: 3, minTileWidth: 300, panel: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // Exactly as the real layout ignores it below `large`: no tall panel-width
    // placeholder, and every bar is a row of the plain grid.
    final sizes = find
        .byType(GlassSurface)
        .evaluate()
        .map((e) => tester.getSize(find.byWidget(e.widget)))
        .toList();
    expect(sizes.any((s) => s.width == 320 && s.height > 200), isFalse);
    expect(sizes.every((s) => s.height == 76), isTrue);
    // Three rows, and the grid still uses whatever columns 700px affords.
    expect(placeholders(tester), 3 * columnsAt(tester));
  });
}
