import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/theme/app_accents.dart';
import 'package:sdhu_operations_project/core/theme/app_colors.dart';

import 'contrast.dart';

/// The brand palette is a PRINT palette, and it does not divide evenly across
/// an app with both a night mode and a paper one: measured against the two
/// backdrops, every red fails on the dark and every gold on the light. That is
/// how a card ended up drawn in a colour nobody could read, and why the app had
/// drifted into using green for nearly everything.
///
/// So each accent carries both variants, and these tests are the measurement
/// itself rather than a note claiming it was taken.
void main() {
  // What the aurora settles to behind the content, top to bottom.
  const night = AppColors.nightMid;

  // The BOTTOM of the light field rather than its middle. The paper backdrop
  // is a gradient, and an accent that clears 4.5 halfway down a page and fails
  // at the foot of it has not cleared anything — a long page is exactly where
  // a colour is read last and looked at least.
  const paper = AppColors.paperEnd;

  const accents = <String, Accent>{
    'green': Accent.green,
    'greenDeep': Accent.greenDeep,
    'greenDark': Accent.greenDark,
    'gold': Accent.gold,
    'goldSoft': Accent.goldSoft,
    'red': Accent.red,
    'redDeep': Accent.redDeep,
  };

  group('every accent is legible on the surface it is meant for', () {
    accents.forEach((name, accent) {
      test('$name on night', () {
        expect(
          contrast(accent.onDark, night),
          greaterThanOrEqualTo(4.5),
          reason: '$name would be drawn on the dark backdrop',
        );
      });

      test('$name on paper', () {
        expect(
          contrast(accent.onLight, paper),
          greaterThanOrEqualTo(4.5),
          reason: '$name would be drawn on the light backdrop',
        );
      });
    });
  });

  test('the accents are distinct — a colour that repeats says nothing', () {
    final onDark = {for (final a in accents.values) a.onDark};
    final onLight = {for (final a in accents.values) a.onLight};

    expect(onDark.length, accents.length);
    expect(onLight.length, accents.length);
  });

  testWidgets('it picks by the theme it is asked in', (tester) async {
    // An explicit Theme rather than MaterialApp's themeMode: pumping a second
    // MaterialApp reuses the element tree, and the swap does not take.
    Future<Color> resolve(Brightness brightness) async {
      late Color picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: ThemeData(brightness: brightness),
            child: Builder(
              builder: (context) {
                picked = Accent.redDeep.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return picked;
    }

    expect(await resolve(Brightness.dark), Accent.redDeep.onDark);
    expect(await resolve(Brightness.light), Accent.redDeep.onLight);
    expect(
      Accent.redDeep.onLight,
      AppColors.mediumRed,
      reason: 'paper takes the brand value unmixed',
    );
  });
}
