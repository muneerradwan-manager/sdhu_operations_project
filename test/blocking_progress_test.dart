import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/widgets/blocking_progress.dart';

/// Signing out is a round trip to Firebase and then to Supabase, and until it
/// came back the app stayed fully live: you could tap the button again, open a
/// file, send a notification — and then the session went out from under it.
///
/// So the rule is that the interface is sealed for the duration, and this is
/// what proves it: a tap that lands while the work is in flight changes nothing.
void main() {
  testWidgets('nothing gets through while the action is in flight', (
    tester,
  ) async {
    var taps = 0;
    final work = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                taps++;
                runBlocking(context, () => work.future, message: 'working');
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(taps, 1);
    expect(find.text('working'), findsOneWidget);

    // The same button, still on screen, now behind the barrier.
    await tester.tap(find.text('go'), warnIfMissed: false);
    await tester.pump();
    expect(taps, 1, reason: 'the barrier should have swallowed that tap');

    work.complete();
    await tester.pumpAndSettle();

    expect(find.text('working'), findsNothing);
    // And the screen is live again.
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('the barrier is lifted even when the action fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                try {
                  await runBlocking(
                    context,
                    () async => throw StateError('no network'),
                    message: 'working',
                  );
                } catch (_) {
                  // The caller's business; what matters is the barrier going.
                }
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('working'), findsNothing);
  });
}
