import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sdhu_operations_project/core/theme/app_theme.dart';
import 'package:sdhu_operations_project/core/theme/glass_tokens.dart';
import 'package:sdhu_operations_project/core/widgets/glass.dart';
import 'package:sdhu_operations_project/core/widgets/selection_indicator.dart';

/// Taking the glass out, and what has to be true once it is gone.
void main() {
  GlassTokens tokensOf(ThemeData theme) => theme.extension<GlassTokens>()!;

  group('the solid token sets', () {
    test('carry no blur at all', () {
      // Not "less blur". Zero is what [GlassSurface] reads to skip building the
      // filter, and a small non-zero sigma would keep every save-layer alive
      // while looking almost the same — the worst of both.
      for (final tokens in [GlassTokens.lightSolid, GlassTokens.darkSolid]) {
        expect(tokens.blur, 0);
        expect(tokens.blurStrong, 0);
        expect(tokens.reduced, isTrue);
      }
    });

    test('are actually opaque — the point of the mode', () {
      // A "solid" fill left at 90% is still a pane the sun shines through, and
      // the whole claim of this mode is that it does not.
      for (final tokens in [GlassTokens.lightSolid, GlassTokens.darkSolid]) {
        expect(tokens.fill.a, 1.0);
        expect(tokens.fillStrong.a, 1.0);
        expect(tokens.fillSubtle.a, 1.0);
      }
    });

    test('lean harder on the edge, since the fill no longer separates', () {
      // Once a pane is opaque it stops standing out from the page by tone, so
      // the hairline is the only thing left saying where it ends.
      expect(
        GlassTokens.lightSolid.stroke.a,
        greaterThan(GlassTokens.light.stroke.a),
      );
      expect(
        GlassTokens.darkSolid.stroke.a,
        greaterThan(GlassTokens.dark.stroke.a),
      );
    });

    test('the ordinary sets are untouched', () {
      // The switch must be a switch: off is exactly what it always was.
      expect(GlassTokens.light.reduced, isFalse);
      expect(GlassTokens.dark.reduced, isFalse);
      expect(GlassTokens.light.blur, greaterThan(0));
    });
  });

  group('the themes carry the choice', () {
    test('solid: true reaches the tokens, in both brightnesses', () {
      expect(tokensOf(AppTheme.light(solid: true)).reduced, isTrue);
      expect(tokensOf(AppTheme.dark(solid: true)).reduced, isTrue);
      expect(tokensOf(AppTheme.light()).reduced, isFalse);
      expect(tokensOf(AppTheme.dark()).reduced, isFalse);
    });

    test('each variant is built once and handed back', () {
      // Four ThemeDatas, cached. `_build` runs ColorScheme.fromSeed and ~20
      // sub-themes, and the shell rebuilds on every settings change.
      expect(identical(AppTheme.light(solid: true), AppTheme.light(solid: true)), isTrue);
      expect(identical(AppTheme.light(), AppTheme.light()), isTrue);
      expect(identical(AppTheme.light(), AppTheme.light(solid: true)), isFalse);
    });
  });

  group('the surface honours it', () {
    Widget harness(ThemeData theme) => MaterialApp(
      theme: theme,
      home: const Scaffold(
        body: GlassSurface(child: Text('t')),
      ),
    );

    testWidgets('no BackdropFilter is built when the sigma is zero', (t) async {
      await t.pumpWidget(harness(AppTheme.light(solid: true)));
      expect(
        find.byType(BackdropFilter),
        findsNothing,
        reason:
            'a zero-sigma filter is still a save-layer — the compositor reads '
            'back everything behind the pane every frame to blur it by nothing',
      );
    });

    testWidgets('and one is built when there is glass', (t) async {
      await t.pumpWidget(harness(AppTheme.light()));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  testWidgets('a chosen row says so, not merely looks it', (t) async {
    // Selection was drawn as a fill and a tick and carried to a screen reader
    // by nothing at all, so every picker announced its rows identically
    // whether they were chosen or not.
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SelectionIndicator(selected: true),
              SelectionIndicator(selected: false),
            ],
          ),
        ),
      ),
    );

    final nodes = t
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.checked != null)
        .toList();

    expect(nodes.map((s) => s.properties.checked), containsAll([true, false]));
  });
}
