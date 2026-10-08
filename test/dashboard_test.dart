import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/theme/chart_palette.dart';
import 'package:sdhu_operations_project/core/widgets/charts.dart';
import 'package:sdhu_operations_project/core/widgets/responsive.dart';
import 'package:sdhu_operations_project/features/dashboard/domain/dashboard_stats.dart';

void main() {
  group('what the reader is allowed to ask', () {
    // The function drops a section the reader holds no permission for rather
    // than zeroing it, and the difference is the whole point: a zero is a claim
    // about the mission ("no employees"), and a missing section is "you may not
    // ask". Drawing a zero for the second would be the page telling a lie.
    test('a section that was withheld is absent, not zero', () {
      final stats = DashboardStats.fromMap({
        'season': {'id': 's1', 'hijri_year': 1447, 'is_current': true},
        'approvals': {
          'pending': 0,
          'approved': 0,
          'rejected': 0,
          'incomplete': 0,
        },
      });

      expect(stats.people, isNull);
      expect(stats.modules, isNull);
      expect(stats.reports, isNull);
      expect(stats.ratings, isNull);

      // Present and genuinely all-zero — an empty queue, which IS a fact.
      expect(stats.approvals, isNotNull);
      expect(stats.approvals!.pending, 0);
      expect(stats.isEmpty, isFalse);
    });

    test(
      'a reader with no permission at all gets a season and nothing else',
      () {
        final stats = DashboardStats.fromMap({
          'season': {'id': 's1', 'hijri_year': 1447, 'is_current': false},
        });

        expect(stats.season, isNotNull);
        expect(stats.isEmpty, isTrue);
      },
    );
  });

  group('reading what the database sent', () {
    test('a star distribution fills in the stars nobody gave', () {
      final r = RatingStats.fromMap({
        'count': 7,
        'rated_people': 3,
        'average': 4.33,
        // Nobody gave one or two stars, so those rows are simply absent.
        'distribution': [
          {'stars': 3, 'count': 1},
          {'stars': 4, 'count': 2},
          {'stars': 5, 'count': 4},
        ],
      });

      // Five entries, ones first — a missing star is a zero-height bar, not a
      // missing bar, or the axis stops being a scale.
      expect(r.distribution, [0, 0, 1, 2, 4]);
      expect(r.average, 4.33);
    });

    test('a file type carries its total and its active count', () {
      final m = ModuleStats.fromMap({
        'total': 5,
        'active': 3,
        'draft': 2,
        'by_type': [
          {
            'label_ar': 'قطاعات وأبراج',
            'label_en': 'Sectors',
            'total': 3,
            'active': 2,
            'draft': 1,
          },
        ],
      });

      expect(m.byType.single.count, 3);
      expect(m.byType.single.secondary, 2);
      expect(m.byType.single.labelEn, 'Sectors');
    });

    test('a report day is read as the period it accounts for', () {
      final r = ReportStats.fromMap({
        'total': 4,
        'authors': 2,
        'series': [
          {'day': '2026-07-20', 'n': 3},
          {'day': '2026-07-21', 'n': 1},
        ],
      });

      expect(r.series.first.day, DateTime(2026, 7, 20));
      expect(r.series.last.count, 1);
    });

    test('the four newer sections parse, and their absence stays absence', () {
      final stats = DashboardStats.fromMap({
        'season': {'id': 's1', 'hijri_year': 1447, 'is_current': true},
        'central_reports': {
          'total': 6,
          'published': 4,
          'drafts': 2,
          'general': 1,
          'by_type': [
            {'label_ar': 'تقرير الوجبات', 'n': 3},
          ],
        },
        'notifications': {
          'messages': 5,
          'recipients': 40,
          'read': 30,
          'total_messages': 12,
          'series': [
            {'day': '2026-07-30', 'n': 2},
          ],
        },
        'reference': {
          'sets': 3,
          'items': 20,
          'active': 18,
          'season_items': 15,
          'general_items': 5,
          'by_set': [
            {'label_ar': 'فنادق مكة', 'n': 9},
          ],
        },
        'permissions': {
          'admins': 2,
          'grantees': 7,
          'grants': 21,
          'by_section': [
            {'key': 'modules', 'count': 9},
          ],
        },
      });

      expect(stats.centralReports!.published, 4);
      expect(stats.centralReports!.byType.single.count, 3);
      // 30 of 40 rows opened.
      expect(stats.notifications!.readShare, closeTo(0.75, 0.0001));
      expect(stats.notifications!.series.single.day, DateTime(2026, 7, 30));
      expect(stats.reference!.bySet.single.labelAr, 'فنادق مكة');
      expect(stats.permissions!.bySection.single.key, 'modules');
      expect(stats.isEmpty, isFalse);

      // And a payload without them still reads as "you may not ask".
      final none = DashboardStats.fromMap({
        'season': {'id': 's1', 'hijri_year': 1447, 'is_current': true},
      });
      expect(none.centralReports, isNull);
      expect(none.notifications, isNull);
      expect(none.reference, isNull);
      expect(none.permissions, isNull);
      expect(none.isEmpty, isTrue);
    });

    test('a read share over zero recipients is no claim at all', () {
      final n = NotificationDashStats.fromMap({
        'messages': 0,
        'recipients': 0,
        'read': 0,
        'total_messages': 0,
        'series': [],
      });
      expect(n.readShare, isNull);
    });
  });

  group('the palette', () {
    // These exact values were run through the six checks against both
    // backdrops — lightness band, chroma floor, CVD separation, the
    // normal-vision floor and contrast — and pass all five in each mode. The
    // app's own brand green and gold do NOT: measured, they sit ΔE 10 apart in
    // normal vision and 5.4 under protanopia, against thresholds of 15 and 8.
    //
    // So this is not decoration being pinned down. Changing a value here means
    // re-running scripts/validate_palette.js and changing this test with the
    // result — not adjusting it until it looks nicer.
    test('is the validated one, and has exactly three slots', () {
      expect(ChartPalette.series, hasLength(3));
      expect(ChartPalette.series.map((c) => c.onLight.toARGB32()).toList(), [
        0xFF00897B,
        0xFFA8801A,
        0xFF8C2A55,
      ]);
      expect(ChartPalette.series.map((c) => c.onDark.toARGB32()).toList(), [
        0xFF009485,
        0xFFB08B37,
        0xFFB85C86,
      ]);
    });
  });

  group('DonutChart', () {
    Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, child: child)),
    );

    testWidgets('a category falling to zero does not repaint the survivors', (
      tester,
    ) async {
      // Colour follows the entity, never its rank. If "external" drops to zero
      // and "internal" takes its colour, every chart on the page has silently
      // changed what teal means.
      Color colourOfFirstLegendDot(WidgetTester t) {
        final dot = t
            .widgetList<Container>(find.byType(Container))
            .firstWhere((c) => (c.constraints?.maxWidth ?? 0) == 10);
        return (dot.decoration! as BoxDecoration).color!;
      }

      await tester.pumpWidget(
        wrap(
          const DonutChart(
            otherLabel: 'Other',
            slices: [
              ChartSlice(label: 'Internal', value: 30),
              ChartSlice(label: 'External', value: 12),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final withBoth = colourOfFirstLegendDot(tester);

      await tester.pumpWidget(
        wrap(
          const DonutChart(
            otherLabel: 'Other',
            slices: [
              ChartSlice(label: 'Internal', value: 30),
              ChartSlice(label: 'External', value: 0),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(colourOfFirstLegendDot(tester), withBoth);
      // And the empty one is gone from the legend rather than sitting there
      // claiming a colour for nothing.
      expect(find.text('External'), findsNothing);
    });

    testWidgets('every wedge carries its name and its number', (tester) async {
      await tester.pumpWidget(
        wrap(
          const DonutChart(
            otherLabel: 'Other',
            centerLabel: 'Total',
            slices: [
              ChartSlice(label: 'Administrative', value: 8),
              ChartSlice(label: 'Religious', value: 5),
              ChartSlice(label: 'Medical', value: 2),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // Never colour alone: the chart survives a photocopier.
      for (final label in ['Administrative', 'Religious', 'Medical']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final n in ['8', '5', '2']) {
        expect(find.text(n), findsOneWidget);
      }
      // And the hole carries the whole.
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('a fourth category folds into one wedge, by declared order', (
      tester,
    ) async {
      // The palette has three measured slots and is never cycled. The fold runs
      // by the order the categories were NAMED rather than by size, so a
      // category shrinking cannot change what a colour means — which is the
      // same rule as the zero case above, applied at the other end.
      await tester.pumpWidget(
        wrap(
          const DonutChart(
            otherLabel: 'Other',
            slices: [
              ChartSlice(label: 'First', value: 10),
              ChartSlice(label: 'Second', value: 8),
              ChartSlice(label: 'Third', value: 5),
              ChartSlice(label: 'Fourth', value: 3),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Third'), findsNothing);
      expect(find.text('Fourth'), findsNothing);
      // The tail, summed and named once.
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('8'), findsNWidgets(2)); // Second's 8, and 5 + 3.
    });

    testWidgets('a whole that is entirely zero draws a ring, not a crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const DonutChart(
            otherLabel: 'Other',
            slices: [
              ChartSlice(label: 'Internal', value: 0),
              ChartSlice(label: 'External', value: 0),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('Internal'), findsNothing);
    });
  });

  group('the plotted marks', () {
    // fl_chart lays itself out against the space it is given and animates on
    // arrival. These are not appearance tests — they are the check that each
    // mark survives being built, at both ends of its data, inside the pane the
    // dashboard actually puts it in.
    Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 300, child: child)),
    );

    testWidgets('a trend draws its series, and says so when there is none', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          TrendChart(
            emptyLabel: 'Nothing filed',
            labelForDay: (d) => '${d.day}',
            points: [
              for (var i = 0; i < 30; i++)
                TrendPoint(day: DateTime(2026, 7, i + 1), value: i % 5),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Nothing filed'), findsNothing);

      await tester.pumpWidget(
        wrap(const TrendChart(emptyLabel: 'Nothing filed', points: [])),
      );
      await tester.pump();
      expect(find.text('Nothing filed'), findsOneWidget);
    });

    testWidgets('a distribution keeps the place of a rating nobody gave', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const StarBars(counts: [0, 0, 1, 2, 4])));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      // Five columns on the axis, including the two nobody gave: a missing bar
      // would say the rating does not exist.
      for (final star in ['1', '2', '3', '4', '5']) {
        expect(find.text(star), findsWidgets);
      }
    });

    testWidgets('a gauge states its share and clamps a bad one', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const GaugeRing(value: 0.75, label: '30 of 40 opened')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('75%'), findsOneWidget);

      // A share over one is a bug upstream, not a ring drawn twice round.
      await tester.pumpWidget(wrap(const GaugeRing(value: 1.4, label: 'x')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('100%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a sparkline needs three points to be a shape', (tester) async {
      await tester.pumpWidget(
        wrap(const Sparkline(values: [1, 2], color: Color(0xFF00897B))),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tile carrying a plot can still be levelled with its row', (
      tester,
    ) async {
      // The headline tiles share a row and are forced to one height, which
      // means every one of them is asked for its INTRINSIC height — and a
      // chart cannot answer that question: it measures itself against the space
      // it is handed. The fixed box around every plot is what makes the
      // question answerable, and this is the test that it stays there.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: AdaptiveGrid(
                minTileWidth: 200,
                children: [
                  StatTile(
                    label: 'Reports',
                    value: '412',
                    icon: Icons.description,
                    color: const Color(0xFF00897B),
                    caption: 'from 12 authors',
                    spark: const [1, 4, 2, 9, 3, 6],
                  ),
                  StatTile(
                    label: 'Files',
                    value: '18',
                    icon: Icons.folder,
                    color: const Color(0xFFA8801A),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('412'), findsOneWidget);
    });
  });

  group('RankedBars', () {
    testWidgets('ranks by size and stops where a reader stops', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: RankedBars(
                maxRows: 3,
                slices: const [
                  ChartSlice(label: 'Third', value: 3),
                  ChartSlice(label: 'First', value: 30),
                  ChartSlice(label: 'Fourth', value: 1),
                  ChartSlice(label: 'Second', value: 12),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final first = tester.getTopLeft(find.text('First')).dy;
      final second = tester.getTopLeft(find.text('Second')).dy;
      final third = tester.getTopLeft(find.text('Third')).dy;
      expect(first, lessThan(second));
      expect(second, lessThan(third));
      expect(find.text('Fourth'), findsNothing);
    });
  });
}
