import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/theme/glass_tokens.dart';
import 'package:sdhu_operations_project/core/widgets/glass.dart';

/// Screens that extend behind the glass app bar rely on
/// [GlassThemeX.scrollPadding] to keep their first row clear of it. The value
/// comes from the MediaQuery that Scaffold rewrites for its *body* — read it
/// from a context above the Scaffold and the list silently slides underneath
/// the bar, which is exactly the regression these tests guard.
void main() {
  const statusBarHeight = 40.0;
  final expectedTopInset = statusBarHeight + kToolbarHeight;

  Widget harness({required Widget Function(BuildContext) bodyBuilder}) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(top: statusBarHeight),
        ),
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: const GlassAppBar(title: Text('t')),
          body: Builder(builder: bodyBuilder),
        ),
      ),
    );
  }

  testWidgets('scrollPadding clears the app bar inside the body', (
    tester,
  ) async {
    late EdgeInsets padding;
    await tester.pumpWidget(
      harness(
        bodyBuilder: (context) {
          padding = context.scrollPadding();
          return const SizedBox.shrink();
        },
      ),
    );

    expect(padding.top, expectedTopInset + AppSpacing.md);
    expect(padding.left, AppSpacing.lg);
    expect(padding.right, AppSpacing.lg);
  });

  testWidgets('a list using it starts below the app bar', (tester) async {
    await tester.pumpWidget(
      harness(
        bodyBuilder: (context) => ListView(
          padding: context.scrollPadding(),
          children: const [
            SizedBox(height: 40, child: Text('first', key: Key('first'))),
          ],
        ),
      ),
    );

    final top = tester.getTopLeft(find.byKey(const Key('first'))).dy;
    expect(
      top,
      greaterThanOrEqualTo(expectedTopInset),
      reason: 'first row must not be hidden behind the glass app bar',
    );
  });

  group('the bottom, which Android 15 made everybody\'s problem', () {
    // Edge-to-edge stopped being opt-in in Android 15: an app targeting it is
    // drawn behind the gesture bar whether it asked to be or not. So the last
    // row of every list, and every button that sits at the end of one, is
    // underneath that bar unless the padding accounts for it.
    //
    // `viewPadding` and not `padding`: the two differ precisely when a keyboard
    // is up, and it is `viewPadding` that keeps reporting the gesture bar
    // underneath it. Reading the wrong one gives a list that is correct until
    // somebody types, and wrong afterwards.
    const gestureBar = 48.0;

    Widget insetHarness({required Widget Function(BuildContext) bodyBuilder}) =>
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(bottom: gestureBar),
              viewPadding: EdgeInsets.only(bottom: gestureBar),
            ),
            child: Scaffold(body: Builder(builder: bodyBuilder)),
          ),
        );

    testWidgets('scrollPadding clears the gesture bar', (tester) async {
      late EdgeInsets padding;
      await tester.pumpWidget(
        insetHarness(
          bodyBuilder: (context) {
            padding = context.scrollPadding();
            return const SizedBox.shrink();
          },
        ),
      );

      expect(
        padding.bottom,
        gestureBar + AppSpacing.xl,
        reason: 'the window inset must be ADDED to the page gutter, not '
            'replace it — otherwise the last row is flush against the bar',
      );
    });

    testWidgets('a keyboard does not get counted twice', (tester) async {
      // The case that looks like a bug and is not.
      //
      // With a keyboard up, Scaffold has ALREADY lifted its body clear of it
      // and zeroed the bottom inset it hands down — the gesture bar is behind
      // the keyboard, so there is nothing left down there to clear. Adding the
      // bar again here would push the last row of every form a gesture bar's
      // height above the keyboard, which reads as a layout bug and is the
      // reason to pin this rather than "fix" it later.
      late EdgeInsets padding;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(bottom: gestureBar),
              viewPadding: EdgeInsets.only(bottom: gestureBar),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  padding = context.scrollPadding();
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(
        padding.bottom,
        AppSpacing.xl,
        reason: 'the Scaffold already accounted for it; this must not add it '
            'a second time',
      );
    });

    testWidgets('the last row of a list is not under the bar', (tester) async {
      await tester.pumpWidget(
        insetHarness(
          bodyBuilder: (context) => ListView(
            padding: context.scrollPadding(),
            children: const [
              SizedBox(height: 40, child: Text('last', key: Key('last'))),
            ],
          ),
        ),
      );

      final windowHeight = tester.view.physicalSize.height /
          tester.view.devicePixelRatio;
      final bottom = tester.getBottomLeft(find.byKey(const Key('last'))).dy;

      expect(
        bottom,
        lessThan(windowHeight - gestureBar),
        reason: 'the last row is behind the Android 15 gesture bar',
      );
    });
  });
}
