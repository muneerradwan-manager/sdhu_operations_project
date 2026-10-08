import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/widgets/photo_viewer.dart';
import 'package:sdhu_operations_project/core/widgets/profile_hero.dart';

/// The portrait in the identity block — the one "my profile", the employee page
/// and the approval page all share — opens the photograph full screen. It only
/// does so when there *is* a photograph: initials on a coloured disc have no
/// larger version, and a tap that opens a black page holding nothing is worse
/// than a tap that does nothing at all.
void main() {
  Widget harness({String? photoUrl}) {
    return MaterialApp(
      home: Scaffold(
        body: ProfileHero(name: 'أحمد الحسن', photoUrl: photoUrl),
      ),
    );
  }

  testWidgets('tapping a portrait with a photo opens the viewer', (
    tester,
  ) async {
    await tester.pumpWidget(harness(photoUrl: 'https://example.test/a.jpg'));

    await tester.tap(find.byType(InkWell));
    // Not pumpAndSettle: the image never resolves under the test HttpClient, so
    // its placeholder spins forever. Pumping the route transition is enough.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final viewer = tester.widget<PhotoViewer>(find.byType(PhotoViewer));
    expect(viewer.url, 'https://example.test/a.jpg');
    expect(
      viewer.title,
      'أحمد الحسن',
      reason: 'the page is titled with whose face it is',
    );
  });

  testWidgets('initials are not tappable', (tester) async {
    await tester.pumpWidget(harness());

    expect(find.byType(InkWell), findsNothing);
  });
}
