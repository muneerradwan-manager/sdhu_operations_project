import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/widgets/glass.dart';

/// A [BackdropFilter] re-reads and re-blurs everything behind it on every frame
/// the pane moves — which, inside a scrolling list, is every frame of the
/// scroll. One is affordable — the app bar. A screenful is not: the home
/// dashboard and the employee page each stacked half a dozen inside a scrolling
/// list, and both crawled until [GlassCard] stopped blurring by default.
///
/// These tests hold that line. The failure they guard against is silent — the
/// screen still looks right, it just stops being smooth on a real device, which
/// is the one thing a widget test can catch and a reviewer cannot see.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('a screenful of content panes mounts no backdrop filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ListView(
          children: [
            for (var i = 0; i < 6; i++)
              GlassCard(onTap: () {}, child: Text('pane $i')),
          ],
        ),
      ),
    );

    expect(find.byType(GlassCard), findsNWidgets(6));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('chrome still frosts — that is what the blur is for', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const GlassSurface(strong: true, child: Text('app bar'))),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('a lone pane over something busy can still opt in', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const GlassCard(blur: true, child: Text('over a map'))),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
