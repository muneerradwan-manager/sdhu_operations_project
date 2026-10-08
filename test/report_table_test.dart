import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/theme/app_theme.dart';
import 'package:sdhu_operations_project/features/reports/presentation/widgets/report_table.dart';

/// A report's table on a real window.
///
/// Every case here is something the old table did on a real screen: sat at one
/// end of a full-width card with a third of the page empty, scrolled sideways
/// so that the day and the components could not be seen at once, cut the
/// ingredients off at a fixed row height with nothing to say they had been cut,
/// and — on a 1600 pixel monitor at 150% scaling — fell back to the phone
/// arrangement and drew the season's cluster distribution as seventeen stacked
/// cards.
///
/// The font is the real one, loaded from the app's own assets. The whole choice
/// between the two arrangements is made by MEASURING text, so a test run
/// against a substitute font would be measuring something the app never draws.
Future<void> _loadFont() async {
  final loader = FontLoader('itfQomra');
  for (final weight in ['Regular', 'Bold', 'Light']) {
    final file = File('assets/fonts/itfQomra/itfQomraArabic-$weight.otf');
    loader.addFont(
      file.readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
  }
  await loader.load();
}

// مكونات الوجبات, as the document has it.
const _mealColumns = ['اليوم', 'الوجبة', 'نوعها', 'التوقيت', 'المكونات'];
const _components =
    'خبز\nزبدة\nزيتون\nكوسا محشي أو ورق عنب\nمسبحة\nشوربة عدس\nمربى';
const _mealRows = [
  [
    '8 ذي الحجة - تروية',
    'غداء',
    'جافة',
    'من الساعة 13:00 إلى الساعة 17:00',
    _components,
  ],
  ['9 ذي الحجة - عرفات', 'فطور', 'جافة', 'من الساعة 6:00 إلى الساعة 9:00', 'أرز'],
];

// توزيع الوجبات على التكتلات — the thirteen real clusters of 1447, plus the
// four columns that name and total the row. Seventeen in all.
const _clusters = [
  'عطاء',
  'عباد الرحمن',
  'رؤيا',
  'الكعبة المشرفة',
  'الحمد',
  'النخبة',
  'وتعاونوا',
  'روافد',
  'بشروا',
  'الضياء',
  'ارتقاء',
  'المحراب',
  'البراق',
];
final _distColumns = ['اليوم', 'الوجبة', 'النسبة', 'المجموع', ..._clusters];
final _distRows = [
  for (final meal in ['فطور', 'غداء', 'عشاء'])
    [
      '8 ذي الحجة - تروية',
      meal,
      '25%',
      '2565',
      for (var i = 0; i < _clusters.length; i++) '${200 + i * 5}',
    ],
];

/// The room a page of this width actually gives a table: the window less the
/// two gutters [ResponsivePage] puts at its edges.
Future<Rect> _pump(
  WidgetTester tester, {
  required double logicalWidth,
  required double gutter,
  required List<String> columns,
  required List<List<String>> rows,
  Set<int> tagged = const {},
}) async {
  tester.view.physicalSize = Size(logicalWidth, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: ReportTable(
                key: const Key('table'),
                columns: columns,
                rows: rows,
                tagged: tagged,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.getRect(find.byKey(const Key('table')));
}

bool _scrolls(WidgetTester tester) => tester.any(find.descendant(
      of: find.byKey(const Key('table')),
      matching: find.byType(Scrollbar),
    ));

bool _isGrid(WidgetTester tester) =>
    tester.any(find.descendant(
      of: find.byKey(const Key('table')),
      matching: find.byType(Table),
    ));

void main() {
  setUpAll(_loadFont);

  group('the arrangement is chosen by measuring the room', () {
    testWidgets('the cluster distribution is a table on the monitor', (
      tester,
    ) async {
      // 1600 physical pixels at 150% scaling is 1067 logical, which is
      // `expanded` — and the old rule demanded `extraLarge` for more than ten
      // columns, so seventeen columns became seventeen phone cards on a
      // monitor. This is the case the whole rewrite is for.
      await _pump(
        tester,
        logicalWidth: 1067,
        gutter: 24,
        columns: _distColumns,
        rows: _distRows,
      );
      expect(_isGrid(tester), isTrue, reason: 'stacked on a 1600px monitor');
    });

    testWidgets('a table too wide to fit scrolls rather than squeezing', (
      tester,
    ) async {
      // Twenty-five clusters is what the season actually has. Narrowed to fit,
      // Arabic breaks inside its words; so it keeps its widths and moves.
      final wide = [
        'اليوم',
        'الوجبة',
        'النسبة',
        'المجموع',
        for (var i = 0; i < 25; i++) 'تكتل ${_clusters[i % _clusters.length]} $i',
      ];
      await _pump(
        tester,
        logicalWidth: 1067,
        gutter: 24,
        columns: wide,
        rows: [
          [
            '8 ذي الحجة - تروية',
            'غداء',
            '25%',
            '2565',
            for (var i = 0; i < 25; i++) '${200 + i}',
          ],
        ],
      );
      expect(_isGrid(tester), isTrue, reason: 'it stopped being a table');
      expect(_scrolls(tester), isTrue, reason: 'it was squeezed instead');
    });

    testWidgets('a table that fits does not scroll', (tester) async {
      await _pump(
        tester,
        logicalWidth: 1600,
        gutter: 32,
        columns: _mealColumns,
        rows: _mealRows,
      );
      expect(_scrolls(tester), isFalse);
    });

    testWidgets('a tablet keeps the table; only a phone gives it up', (
      tester,
    ) async {
      // Asked for in as many words: if it can scroll, let the medium windows
      // have it too.
      await _pump(
        tester,
        logicalWidth: 700,
        gutter: 24,
        columns: _distColumns,
        rows: _distRows,
      );
      expect(_isGrid(tester), isTrue);

      await _pump(
        tester,
        logicalWidth: 400,
        gutter: 16,
        columns: _distColumns,
        rows: _distRows,
      );
      expect(_isGrid(tester), isFalse, reason: 'a matrix on a phone');
    });

    testWidgets('the meal components are a table on the monitor', (
      tester,
    ) async {
      await _pump(
        tester,
        logicalWidth: 1067,
        gutter: 24,
        columns: _mealColumns,
        rows: _mealRows,
      );
      expect(_isGrid(tester), isTrue);
      expect(_scrolls(tester), isFalse, reason: 'it fits; it should not move');
    });
  });

  group('the grid', () {
    testWidgets('fills the width, leaving nothing empty beside it', (
      tester,
    ) async {
      final r = await _pump(
        tester,
        logicalWidth: 1600,
        gutter: 32,
        columns: _mealColumns,
        rows: _mealRows,
      );
      // The old table took its intrinsic width and left a third of the card
      // empty at one end.
      expect(r.width, closeTo(1536, 0.01));
      expect(r.left, closeTo(32, 0.01));
    });

    testWidgets('keeps every column inside it, none off the edge', (
      tester,
    ) async {
      final r = await _pump(
        tester,
        logicalWidth: 1067,
        gutter: 24,
        columns: _distColumns,
        rows: _distRows,
      );
      for (final c in _distColumns) {
        final cell = tester.getRect(find.text(c).first);
        expect(
          cell.left >= r.left - 0.5 && cell.right <= r.right + 0.5,
          isTrue,
          reason: '$c is drawn outside the table at ${cell.left}..${cell.right}',
        );
      }
    });

    testWidgets('draws a tall cell in full rather than cutting it', (
      tester,
    ) async {
      await _pump(
        tester,
        logicalWidth: 1600,
        gutter: 32,
        columns: _mealColumns,
        rows: _mealRows,
      );
      final painted =
          tester.renderObject(find.text(_components)) as RenderParagraph;
      // Seven lines. The old grid capped the row at 120 logical pixels and
      // sliced the last one off.
      expect(painted.didExceedMaxLines, isFalse);
      expect(painted.size.height, greaterThan(100));
    });

    testWidgets('gives a long column more room than a one-word column', (
      tester,
    ) async {
      await _pump(
        tester,
        logicalWidth: 1600,
        gutter: 32,
        columns: _mealColumns,
        rows: _mealRows,
      );
      // "من الساعة 13:00 إلى الساعة 17:00" against "جافة".
      final time = tester.getRect(find.text('التوقيت'));
      final kind = tester.getRect(find.text('نوعها'));
      expect(time.width, greaterThan(kind.width));
    });

    testWidgets('does not let a long heading widen a column of numbers', (
      tester,
    ) async {
      final r = await _pump(
        tester,
        logicalWidth: 1600,
        gutter: 32,
        columns: _distColumns,
        rows: _distRows,
      );
      // تكتل الكعبة المشرفة and تكتل عطاء hold the same three-digit numbers.
      // Letting the heading decide would give one of them three times the
      // other, and a ragged grid reads as a mistake.
      final wide = tester.getRect(find.text('الكعبة المشرفة'));
      final narrow = tester.getRect(find.text('عطاء'));
      expect(wide.width / narrow.width, lessThan(2.5));
      expect(r.width, closeTo(1536, 0.01));
    });

    testWidgets('the first column is on the right in Arabic', (tester) async {
      await _pump(
        tester,
        logicalWidth: 1600,
        gutter: 32,
        columns: _mealColumns,
        rows: _mealRows,
      );
      expect(
        tester.getRect(find.text('اليوم')).center.dx,
        greaterThan(tester.getRect(find.text('المكونات')).center.dx),
      );
    });
  });

  group('a list column', () {
    testWidgets('is drawn as tags, not as one item per line', (tester) async {
      await _pump(
        tester,
        logicalWidth: 1067,
        gutter: 24,
        columns: _mealColumns,
        rows: _mealRows,
        tagged: {4},
      );
      expect(find.byType(TagRun), findsWidgets);
      // Each component is its own pill with its own text.
      for (final item in ['خبز', 'زبدة', 'كوسا محشي أو ورق عنب', 'مربى']) {
        expect(find.text(item), findsOneWidget, reason: '$item is missing');
      }
      // And the raw stored value is nowhere on the page.
      expect(find.text(_components), findsNothing);
    });

    testWidgets('makes the row far shorter than stacking the items did', (
      tester,
    ) async {
      final asLines = await _pump(
        tester,
        logicalWidth: 1067,
        gutter: 24,
        columns: _mealColumns,
        rows: _mealRows,
      );
      final asTags = await _pump(
        tester,
        logicalWidth: 1067,
        gutter: 24,
        columns: _mealColumns,
        rows: _mealRows,
        tagged: {4},
      );
      // Seven components down a column is seven lines of table for one meal.
      // Flowing across, they are two.
      expect(asTags.height, lessThan(asLines.height * 0.75));
    });

    testWidgets('is still tags when the table stacks on a phone', (
      tester,
    ) async {
      await _pump(
        tester,
        logicalWidth: 400,
        gutter: 16,
        columns: _mealColumns,
        rows: _mealRows,
        tagged: {4},
      );
      expect(_isGrid(tester), isFalse);
      expect(find.byType(TagRun), findsWidgets);
      expect(find.text('زيتون'), findsOneWidget);
    });

    testWidgets('an empty list draws nothing rather than an empty pill', (
      tester,
    ) async {
      await _pump(
        tester,
        logicalWidth: 1067,
        gutter: 24,
        columns: _mealColumns,
        rows: const [
          ['8 ذي الحجة - تروية', 'غداء', 'جافة', 'من الساعة 13:00', '  \n \n'],
        ],
        tagged: {4},
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widgetList(find.byType(Wrap)).length,
        lessThan(2),
        reason: 'an empty cell was given a run of pills',
      );
    });
  });

  group('the edges', () {
    testWidgets('no columns or no rows draws nothing at all', (tester) async {
      final r = await _pump(
        tester,
        logicalWidth: 1600,
        gutter: 32,
        columns: const [],
        rows: const [],
      );
      expect(r.height, 0);
    });

    testWidgets('a row shorter than the columns does not throw', (
      tester,
    ) async {
      // Rows written before a column was added are short, and the report must
      // still open.
      await _pump(
        tester,
        logicalWidth: 1600,
        gutter: 32,
        columns: _mealColumns,
        rows: const [
          ['8 ذي الحجة', 'غداء'],
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('غداء'), findsOneWidget);
    });

    testWidgets('a stacked row names its values and skips the empty ones', (
      tester,
    ) async {
      await _pump(
        tester,
        logicalWidth: 400,
        gutter: 16,
        columns: _mealColumns,
        rows: const [
          [
            '8 ذي الحجة - تروية',
            'غداء',
            '',
            'من الساعة 13:00 إلى الساعة 17:00',
            _components,
          ],
        ],
      );
      expect(_isGrid(tester), isFalse);
      // The heading is the first two, unlabelled; the rest are labelled.
      expect(find.text('التوقيت'), findsOneWidget);
      expect(find.text('نوعها'), findsNothing, reason: 'an empty cell was drawn');
      expect(find.text('اليوم'), findsNothing, reason: 'the heading was labelled');
    });
  });
}
