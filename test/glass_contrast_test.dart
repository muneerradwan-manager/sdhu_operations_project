import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/theme/app_colors.dart';
import 'package:sdhu_operations_project/core/theme/app_theme.dart';
import 'package:sdhu_operations_project/core/theme/glass_tokens.dart';

import 'contrast.dart';

/// Every glass surface in the app is a translucent fill over the backdrop and a
/// hairline drawn on top of it, and neither is a colour anyone can read off the
/// token file: both are alphas, and what they come out as depends entirely on
/// what is behind them.
///
/// That is how light mode lost its edges. The light tokens were the dark ones
/// with the same numbers — white fills, a white hairline — which over a
/// near-white field composited to a pane's border at 1.008 against the pane it
/// was bounding. A ratio of one is not a faint line, it is no line; every card
/// in the app had to be inferred from a twelve-pixel shadow. On a phone the
/// screen edge covered for it. On a monitor, where three panes stand side by
/// side in the middle of the field, nothing did.
///
/// Nothing in the file said so, because the file only ever said `0.20`. So
/// these tests composite the tokens the way the widgets do and measure the
/// result.
void main() {
  /// A pane as it is actually drawn: [fill] laid over the backdrop behind it.
  Color pane(Color fill, Color field) => Color.alphaBlend(fill, field);

  // Each token set against the backdrop it was derived for — which is the
  // pairing the whole exercise is about.
  final backdrops = <String, (GlassTokens, Color)>{
    'paper': (GlassTokens.light, AppColors.paperMid),
    'night': (GlassTokens.dark, AppColors.nightMid),
    // The glass-free sets, measured the same way and against the same fields —
    // which is what the backdrop actually paints for them, since it lies flat
    // in this mode. Opaque is not a licence to skip this: an opaque pane can
    // still be the colour of the page it sits on, and would then be no pane at
    // all with nothing to blame it on.
    'paper (solid)': (GlassTokens.lightSolid, AppColors.paperMid),
    'night (solid)': (GlassTokens.darkSolid, AppColors.nightMid),
  };

  backdrops.forEach((name, pair) {
    final (glass, field) = pair;
    final surface = pane(glass.fill, field);

    group('on $name', () {
      test('a pane is a step away from the field it stands on', () {
        expect(
          contrast(surface, field),
          greaterThanOrEqualTo(1.15),
          reason:
              'a card the same colour as the background is not a card — this '
              'is the separation a row of panes on a wide window relies on',
        );
      });

      test('the hairline is visible against the pane it closes', () {
        expect(
          contrast(pane(glass.stroke, surface), surface),
          greaterThanOrEqualTo(1.30),
          reason: 'the light hairline was once white on white, at 1.008',
        );
      });

      test('the emphasised hairline is heavier than the plain one', () {
        expect(
          contrast(pane(glass.strokeStrong, surface), surface),
          greaterThan(contrast(pane(glass.stroke, surface), surface)),
          reason: 'selected and focused states are told apart by this',
        );
      });

      test('a nested well is a step away from the pane it is cut into', () {
        final well = pane(glass.fillSubtle, surface);
        expect(
          contrast(well, surface),
          greaterThanOrEqualTo(1.04),
          reason: 'a well that matches its pane is not a well',
        );

        // Up on night, down on paper. Getting this backwards is the same
        // mistake as the hairline, one level in: a lighter fill inside an
        // already-white card shows nothing.
        expect(
          luminance(well) < luminance(surface),
          glass.onPaper,
          reason: glass.onPaper
              ? 'on paper a well recedes'
              : 'on night a well catches more light',
        );
      });

      test('chrome is denser than a content pane', () {
        if (glass.reduced) {
          // Nothing to be denser THAN. Density is how much of the page below
          // shows through, and in this mode none of it does from either — an
          // app bar and a card are both simply opaque. The distinction the
          // assertion is about does not exist here rather than being violated.
          return;
        }
        expect(
          glass.fillStrong.a,
          greaterThan(glass.fill.a),
          reason: 'an app bar has content scrolling under it; a card does not',
        );
      });
    });
  });

  test('the two sets are derived, not mirrored', () {
    expect(
      GlassTokens.light.onPaper && !GlassTokens.dark.onPaper,
      isTrue,
      reason: 'each set knows which backdrop it was measured against',
    );
  });

  // A pane may be washed in an accent — the dashboard's cards are red and
  // gold, and [GlassSurface.tint] is passed in eight other places besides. The
  // wash is the card's whole identity, and anything structural drawn over it
  // has to have no opinion about hue: a red card ringed in green is two
  // colours arguing across one millimetre.
  //
  // Night got this right by accident, its hairline being white. Paper did not,
  // and the first cut of this fix drew every edge in the brand green.
  group('nothing structural carries a hue of its own', () {
    void isNeutral(String what, Color c) {
      test(what, () {
        final channels = [c.r, c.g, c.b];
        expect(
          channels.reduce(math.max) - channels.reduce(math.min),
          lessThan(0.02),
          reason:
              '$what is drawn over panes washed red, gold and green alike, so '
              'it may be a neutral or it may be white — never a brand colour',
        );
      });
    }

    for (final glass in [GlassTokens.light, GlassTokens.dark]) {
      final on = glass.onPaper ? 'paper' : 'night';
      isNeutral('the hairline on $on', glass.stroke);
      isNeutral('the emphasised hairline on $on', glass.strokeStrong);
      isNeutral('a well on $on', glass.fillSubtle);
      isNeutral('the sheen on $on', glass.sheen);
    }

    isNeutral('the seat under a pane on paper', GlassTokens.light.shadow);

    // Divider and border roles rule ACROSS those same washed panes.
    final light = AppTheme.light().colorScheme;
    isNeutral('the light outline role', light.outline);
    isNeutral('the light outlineVariant role', light.outlineVariant);
  });
}
