import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/theme/app_icons.dart';
import 'package:sdhu_operations_project/core/widgets/search_field.dart';

/// Sixteen screens narrow a list, and before [AppSearchField] they did it with
/// four different boxes: a pill in the directory, a dense one in التقارير, a
/// bare one in الصلاحيات, and one folded behind an icon in المهام. Half of them
/// had no way to empty the box once it had something in it.
///
/// What is asserted here is what a reader is entitled to carry from one screen
/// to the next: the box is one width, it sits at the start edge, and it has a
/// way out.
void main() {
  Widget inWindow(double width, Widget child, {TextDirection? dir}) =>
      MaterialApp(
        locale: dir == TextDirection.rtl ? const Locale('ar') : null,
        home: Directionality(
          textDirection: dir ?? TextDirection.ltr,
          child: Scaffold(
            body: Center(
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      );

  testWidgets('the clear button arrives with the first letter and not before', (
    tester,
  ) async {
    final seen = <String>[];
    await tester.pumpWidget(
      inWindow(400, AppSearchField(hint: 'ابحث', onChanged: seen.add)),
    );

    expect(find.byType(IconButton), findsNothing);

    await tester.enterText(find.byType(TextField), 'أحمد');
    await tester.pump();

    expect(find.byType(IconButton), findsOneWidget);
    expect(seen, ['أحمد']);
  });

  testWidgets('clearing empties the box AND the query', (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(
      inWindow(400, AppSearchField(hint: 'ابحث', onChanged: seen.add)),
    );

    await tester.enterText(find.byType(TextField), 'أحمد');
    await tester.pump();
    await tester.tap(find.byType(IconButton));
    await tester.pump();

    // A box that empties itself while the list stays narrowed is a lie about
    // the list, and it is the failure half these screens shipped with.
    expect(seen.last, '');
    expect(find.text('أحمد'), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('a caller that owns the controller still gets a working clear', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'قائم');
    addTearDown(controller.dispose);
    var query = 'قائم';

    await tester.pumpWidget(
      inWindow(
        400,
        AppSearchField(
          hint: 'ابحث',
          controller: controller,
          onChanged: (v) => query = v,
        ),
      ),
    );

    // Seeded from the controller, so the way out is there on the first frame —
    // a filter bar rebuilt from state opens with its query already in it.
    expect(find.byType(IconButton), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(controller.text, '');
    expect(query, '');
  });

  testWidgets('the box stops at 460 however wide the window gets', (
    tester,
  ) async {
    await tester.pumpWidget(
      inWindow(1400, AppSearchField(hint: 'ابحث', onChanged: (_) {})),
    );

    expect(tester.getSize(find.byType(TextField)).width, kSearchFieldMaxWidth);
  });

  testWidgets('and holds the START edge, which is the right in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      inWindow(
        1000,
        AppSearchField(hint: 'ابحث', onChanged: (_) {}),
        dir: TextDirection.rtl,
      ),
    );

    final box = tester.getRect(find.byType(TextField));
    final band = tester.getRect(find.byType(AppSearchField));

    // Right-aligned, not centred: the one screen that let ResponsivePage centre
    // its box put it in the middle of the glass while its neighbour's sat on
    // the edge, which is the whole complaint this widget answers.
    expect(box.right, band.right);
    expect(box.left, greaterThan(band.left));
  });

  testWidgets('a lens at the start of the box, one size everywhere', (
    tester,
  ) async {
    await tester.pumpWidget(
      inWindow(400, AppSearchField(hint: 'ابحث', onChanged: (_) {})),
    );

    final lens = tester.widget<Icon>(find.byIcon(AppIcons.search));
    expect(lens.size, 20);
  });

  testWidgets('the band puts the box above the filters, never below', (
    tester,
  ) async {
    await tester.pumpWidget(
      inWindow(
        600,
        SearchFilterBar(
          hint: 'ابحث',
          onChanged: (_) {},
          filters: const Chip(label: Text('الجارية')),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.byType(TextField)).dy,
      lessThan(tester.getTopLeft(find.byType(Chip)).dy),
    );
  });

  testWidgets(
    'and puts a banner above the box, being true of the list itself',
    (tester) async {
      await tester.pumpWidget(
        inWindow(
          600,
          SearchFilterBar(
            hint: 'ابحث',
            onChanged: (_) {},
            above: const Text('نسخة محفوظة'),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('نسخة محفوظة')).dy,
        lessThan(tester.getTopLeft(find.byType(TextField)).dy),
      );
    },
  );
}
