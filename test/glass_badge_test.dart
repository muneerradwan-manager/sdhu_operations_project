import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/widgets/glass.dart';

/// A badge carries whatever name the database holds, and some of those are
/// sentences — a file called "تشكيل فرق المشاعر (منى يوم التروية، عرفات، منى
/// أيام التشريق)" appeared in one beside a season year and overflowed its row
/// by 92 pixels. The pill is the smallest thing on the screen; it must never be
/// what breaks the layout around it.
void main() {
  /// A [Wrap] inside a fixed width — the shape the badge actually sits in on
  /// the employee picker, and one that hands its children a bounded width. (A
  /// Row would not: it lays non-flex children out unbounded, so the badge would
  /// never see the limit and the Row itself would be what overflowed.)
  Widget inBox(Widget child, {double width = 200}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: Wrap(children: [child])),
      ),
    ),
  );

  testWidgets('a label longer than the room it has does not overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      inBox(
        const GlassBadge(
          label: 'Mashaaer Teams (Mina on Tarwiyah, Arafat, Mina on the days '
              'of Tashreeq) · 1443',
          icon: Icons.folder,
          dense: true,
        ),
      ),
    );

    // takeException() returns the overflow assertion if one was thrown.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same in Arabic, right to left', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: inBox(
          const GlassBadge(
            label: 'تشكيل فرق المشاعر (منى يوم التروية، عرفات، منى أيام '
                'التشريق) · ١٤٤٨',
            icon: Icons.folder,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a short label still hugs its text', (tester) async {
    await tester.pumpWidget(inBox(const GlassBadge(label: 'حالي')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Nowhere near the 200 it was given: the pill did not stretch to fill.
    expect(tester.getSize(find.byType(GlassBadge)).width, lessThan(120));
  });
}
