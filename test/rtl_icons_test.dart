import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/theme/app_icons.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// [AppIcons] re-declares a few Iconsax glyphs by code point so it can set
/// `matchTextDirection: true` — Iconsax ships them without it, and a `const`
/// expression cannot read `Iconsax.logout.codePoint`. That duplication is the
/// risk: a renumbered font would silently render the wrong picture.
void main() {
  group('mirrored icons still point at the glyph they claim', () {
    const cases = <String, (IconData, IconData)>{
      'logout': (AppIcons.logout, Iconsax.logout),
      'login': (AppIcons.login, Iconsax.login),
      'send': (AppIcons.send, Iconsax.send_2),
      'upload': (AppIcons.upload, Iconsax.export_1),
    };

    cases.forEach((name, pair) {
      final (ours, theirs) = pair;
      test(name, () {
        expect(ours.codePoint, theirs.codePoint);
        expect(ours.fontFamily, theirs.fontFamily);
        expect(ours.fontPackage, theirs.fontPackage);
        expect(
          ours.matchTextDirection,
          isTrue,
          reason: 'the whole point is that it flips in Arabic',
        );
      });
    });
  });

  testWidgets('a mirrored icon flips under RTL but not under LTR', (
    tester,
  ) async {
    Future<Matrix4?> transformFor(TextDirection direction) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: const Icon(AppIcons.logout),
        ),
      );
      final transforms = tester
          .widgetList<Transform>(find.byType(Transform))
          .toList();
      return transforms.isEmpty ? null : transforms.first.transform;
    }

    expect(await transformFor(TextDirection.ltr), isNull);

    final rtl = await transformFor(TextDirection.rtl);
    expect(rtl, isNotNull);
    // Horizontal flip about the centre.
    expect(rtl!.entry(0, 0), -1.0);
    expect(rtl.entry(1, 1), 1.0);
  });

  testWidgets('the nav chevron points the way navigation goes', (tester) async {
    // Asserting the chosen IconData is not enough: both chevron glyphs carry
    // `matchTextDirection`, so a widget that hand-picks the left one for Arabic
    // gets it flipped a second time and ends up pointing right. What matters is
    // the glyph AND the flip together.
    Future<(IconData?, bool)> chevronIn(TextDirection direction) async {
      await tester.pumpWidget(
        Directionality(textDirection: direction, child: const NavChevron()),
      );
      final icon = tester.widget<Icon>(find.byType(Icon)).icon;
      final flipped = tester
          .widgetList<Transform>(find.byType(Transform))
          .any((t) => t.transform.entry(0, 0) == -1.0);
      return (icon, flipped);
    }

    final (ltrIcon, ltrFlipped) = await chevronIn(TextDirection.ltr);
    expect(ltrIcon, Icons.chevron_right_rounded);
    expect(ltrFlipped, isFalse, reason: 'already points along the reading run');

    final (rtlIcon, rtlFlipped) = await chevronIn(TextDirection.rtl);
    expect(
      rtlIcon,
      Icons.chevron_right_rounded,
      reason: 'same glyph in both — Flutter is the one that mirrors it',
    );
    expect(rtlFlipped, isTrue, reason: 'so it points left in Arabic');
  });
}
