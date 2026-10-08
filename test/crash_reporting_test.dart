import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/logging/error_reporting.dart';

/// Crash reporting has to survive two ordinary facts about this app, and both
/// of them are about TIMING rather than about crashes.
///
/// The first is that the error handlers are installed before Firebase exists.
/// `bootstrap` does that deliberately — so that a failure in everything below
/// them is itself caught — which leaves a window at start-up with nowhere to
/// send anything, and start-up is when the failures worth seeing happen: a
/// missing `.env`, a key the server rejects, a keystore that will not open.
/// Those must be held and sent once there is somewhere to send them.
///
/// The second is that there is no Firebase at all on Windows or the web, and
/// none in a test. Nothing may throw on that account, and nothing may go on
/// holding errors forever waiting for a reporter that is never coming.
void main() {
  setUp(CrashReporting.resetForTest);
  tearDown(CrashReporting.resetForTest);

  test('an error before there is a reporter is held rather than lost', () {
    CrashReporting.record(StateError('.env is missing SUPABASE_URL'), null);

    expect(CrashReporting.pendingCount, 1);
  });

  test('a framework error is held the same way', () {
    CrashReporting.recordFlutterError(
      FlutterErrorDetails(exception: Exception('bad build')),
    );

    expect(CrashReporting.pendingCount, 1);
  });

  test('a build throwing on every frame does not fill memory with it', () {
    for (var i = 0; i < 500; i++) {
      CrashReporting.record(Exception('overflow $i'), null);
    }

    expect(
      CrashReporting.pendingCount,
      lessThanOrEqualTo(20),
      reason: 'the useful information is the first few, not all five hundred',
    );
  });

  test('attaching where there is no Firebase does not throw', () async {
    await expectLater(CrashReporting.attach(), completes);
  });

  test('what was held is let go once attaching has had its chance', () async {
    CrashReporting.record(Exception('at start-up'), null);
    expect(CrashReporting.pendingCount, 1);

    // No Firebase here, so nothing is actually sent — but the buffer existed
    // to bridge one moment, and holding it past that moment would be a leak
    // that grows for as long as the app is open.
    await CrashReporting.attach();

    expect(CrashReporting.pendingCount, 0);
  });

  test('naming the user before attaching is a no-op, not a crash', () {
    expect(() => CrashReporting.setUser('a-user-id'), returnsNormally);
    expect(() => CrashReporting.setUser(null), returnsNormally);
    expect(() => CrashReporting.setContext('season', '1447'), returnsNormally);
    expect(() => CrashReporting.log('opened the Mina file'), returnsNormally);
  });
}
