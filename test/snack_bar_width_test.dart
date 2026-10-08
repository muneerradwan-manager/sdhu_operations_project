import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/theme/app_theme.dart';
import 'package:sdhu_operations_project/core/theme/glass_tokens.dart';
import 'package:sdhu_operations_project/core/widgets/responsive.dart';

/// A floating snack bar fills the window less its margins, which is what a
/// phone wants and what a monitor very much does not. [SnackBarWidthCap] caps
/// it — but only where a cap is an improvement, because the same theme value
/// that narrows the bar on a desktop would glue it to both edges of a phone.
void main() {
  Widget harness() {
    return MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) =>
          SnackBarWidthCap(child: child ?? const SizedBox.shrink()),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('saved'))),
            child: const Text('go'),
          ),
        ),
      ),
    );
  }

  Future<Rect> showBar(WidgetTester tester, Size window) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    // The SnackBar widget's own box carries the margin; the Material inside it
    // is the bar the user sees.
    return tester.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
  }

  testWidgets('a wide window gets a capped, centred bar', (tester) async {
    const window = Size(1600, 900);
    final bar = await showBar(tester, window);

    expect(bar.width, kSnackBarMaxWidth);
    expect(
      bar.center.dx,
      moreOrLessEquals(window.width / 2),
      reason: 'the leftover width goes to both sides, not one',
    );
  });

  testWidgets('a phone keeps the full-width bar and its margins', (
    tester,
  ) async {
    const window = Size(390, 844);
    final bar = await showBar(tester, window);

    expect(bar.width, window.width - AppSpacing.lg * 2);
    expect(bar.left, AppSpacing.lg);
  });
}
