import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/widgets/responsive.dart';

/// The directory of every employee, the queue of everyone waiting to be
/// approved, every hotel in a set — these are the lists with no natural end,
/// and they went to a grid without giving up being built as they are reached.
/// Two things have to hold at once: the right number of columns, and nothing
/// below the fold laid out before it is scrolled to.
void main() {
  Widget inWindow(double width, Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  Widget tile(BuildContext context, int i) => SizedBox(
    height: 60,
    child: Card(child: Center(child: Text('Row $i'))),
  );

  int columnsAt(WidgetTester tester) {
    final first = tester.getTopLeft(find.byType(Card).first).dy;
    return find
        .byType(Card)
        .evaluate()
        .where((e) => tester.getTopLeft(find.byWidget(e.widget)).dy == first)
        .length;
  }

  testWidgets('a phone gets one column', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      inWindow(
        392,
        AdaptiveGridView(itemCount: 100, itemBuilder: tile, minTileWidth: 300),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(columnsAt(tester), 1);
  });

  testWidgets('a monitor gets four', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      inWindow(
        1300,
        AdaptiveGridView(itemCount: 100, itemBuilder: tile, minTileWidth: 300),
      ),
    );

    expect(columnsAt(tester), 4);
  });

  testWidgets('nothing below the fold is built before it is reached', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var built = 0;
    await tester.pumpWidget(
      inWindow(
        392,
        AdaptiveGridView(
          itemCount: 500,
          minTileWidth: 300,
          itemBuilder: (context, i) {
            built++;
            return tile(context, i);
          },
        ),
      ),
    );

    // A screenful and a little either side — not five hundred. The exact number
    // is Flutter's cache extent's business; that it is nowhere near the total
    // is the point.
    expect(built, lessThan(60));
    expect(built, greaterThan(0));
  });

  testWidgets('the header and footer span the whole width, above and below', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      inWindow(
        1300,
        AdaptiveGridView(
          itemCount: 4,
          minTileWidth: 300,
          itemBuilder: tile,
          header: const SizedBox(height: 40, child: Text('Search')),
          footer: const SizedBox(height: 40, child: Text('4 people')),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final header = tester.getTopLeft(find.text('Search')).dy;
    final firstTile = tester.getTopLeft(find.byType(Card).first).dy;
    final footer = tester.getTopLeft(find.text('4 people')).dy;

    expect(header, lessThan(firstTile));
    expect(footer, greaterThan(firstTile));
    // Four tiles across on one row, so the footer follows the only row there is.
    expect(columnsAt(tester), 4);
  });

  testWidgets('a section heading breaks the rows without breaking the grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      inWindow(
        1300,
        AdaptiveGridView.sectioned(
          minTileWidth: 300,
          sections: [
            GridSection(
              header: const Text('Today'),
              // Five, so the day ends on a short row: the next heading has to
              // start a row of its own rather than filling the gap left over.
              itemCount: 5,
              itemBuilder: (context, i) => tile(context, i),
            ),
            GridSection(
              header: const Text('Yesterday'),
              itemCount: 2,
              itemBuilder: (context, i) => tile(context, 100 + i),
            ),
            // Nothing under it, so it must not appear at all — an empty
            // heading is a promise the list then fails to keep.
            GridSection(
              header: const Text('Older'),
              itemCount: 0,
              itemBuilder: (context, i) => tile(context, i),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Older'), findsNothing);

    final today = tester.getTopLeft(find.text('Today')).dy;
    final yesterday = tester.getTopLeft(find.text('Yesterday')).dy;
    final firstOfYesterday = tester.getTopLeft(find.text('Row 100')).dy;

    // Every card of the first day sits between the two headings, and every
    // card of the second below the one that names it.
    for (var i = 0; i < 5; i++) {
      final row = tester.getTopLeft(find.text('Row $i')).dy;
      expect(row, greaterThan(today));
      expect(row, lessThan(yesterday));
    }
    expect(firstOfYesterday, greaterThan(yesterday));

    // Four across, counted once for the whole list: a card of the second day
    // stands in the same column as the card above it in the first.
    expect(columnsAt(tester), 4);
    Finder cardOf(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(Card));
    expect(
      tester.getTopLeft(cardOf('Row 100')).dx,
      tester.getTopLeft(cardOf('Row 0')).dx,
    );
  });

  testWidgets('sections stay lazy below the fold', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var built = 0;
    await tester.pumpWidget(
      inWindow(
        392,
        AdaptiveGridView.sectioned(
          minTileWidth: 300,
          sections: [
            for (var s = 0; s < 10; s++)
              GridSection(
                header: Text('Day $s'),
                itemCount: 50,
                itemBuilder: (context, i) {
                  built++;
                  return tile(context, i);
                },
              ),
          ],
        ),
      ),
    );

    expect(built, lessThan(60));
    expect(built, greaterThan(0));
  });

  testWidgets('the padding is taken off before the columns are counted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 700 wide less 200 of gutters leaves room for one 480 tile, not two —
    // counting columns against the un-padded width would overfill the row and
    // squeeze every tile below its stated minimum.
    await tester.pumpWidget(
      inWindow(
        700,
        AdaptiveGridView(
          padding: const EdgeInsets.symmetric(horizontal: 100),
          itemCount: 4,
          minTileWidth: 480,
          itemBuilder: tile,
        ),
      ),
    );

    expect(columnsAt(tester), 1);
  });
}
