import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sdhu_operations_project/core/widgets/glass.dart';
import 'package:sdhu_operations_project/core/widgets/info_section.dart';

/// Reaching the urgent report, and reaching a colleague.
void main() {
  group('the report button in a bar with no session', () {
    // [GlassAppBar] is on the login screen, on registration and on all three
    // pre-approval status screens — none of them under a SessionCubit — and it
    // is built by other widget tests inside a bare MaterialApp with no
    // providers at all. The button it now carries has to tolerate that.
    //
    // The gate is not cosmetic either way: `raise_incident` refuses anybody who
    // is not approved (0088), so an unapproved account reaching the form would
    // type out an emergency and be refused by the database at the last possible
    // moment.
    testWidgets('draws nothing, and does not throw', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(appBar: GlassAppBar(title: Text('t'))),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('leaves the screen its own actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: GlassAppBar(
              title: Text('t'),
              actions: [Icon(Icons.abc)],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.abc), findsOneWidget);
    });
  });

  group('the WhatsApp link', () {
    // `wa.me` takes a full international number with no `+` and no leading
    // zeros. Anything else opens onto an error page, which is worse than no
    // button — so a number that is not in that shape produces null and the
    // button is simply not drawn.
    test('accepts a + number', () {
      expect(
        InfoAction.whatsAppUri('+963 11 222 3344').toString(),
        'https://wa.me/963112223344',
      );
    });

    test('accepts a 00 number, which is the same number written differently', () {
      expect(
        InfoAction.whatsAppUri('00963112223344').toString(),
        'https://wa.me/963112223344',
      );
    });

    test('refuses a local number — it reaches nobody from abroad', () {
      expect(InfoAction.whatsAppUri('0999123456'), isNull);
    });

    test('refuses what is too short to be a number at all', () {
      expect(InfoAction.whatsAppUri('+123'), isNull);
      expect(InfoAction.whatsAppUri(''), isNull);
      expect(InfoAction.whatsAppUri('—'), isNull);
    });

    test('reduces the same way the dialler does', () {
      // One reduction, used by both, because two copies drift the first time
      // somebody stores a number with a dash in it.
      expect(
        InfoAction.whatsAppUri('+963-11-222-3344').toString(),
        InfoAction.whatsAppUri('+963 11 222 3344').toString(),
      );
      expect(
        InfoAction.call.uriFor('+963-11-222-3344').toString(),
        'tel:+963112223344',
      );
    });
  });
}
