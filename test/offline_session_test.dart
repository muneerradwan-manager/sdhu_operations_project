import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one read the whole offline story hangs from.
///
/// Everything in this app that survives a dead network — the task list off
/// disk, the roster, the queue of writes waiting for a signal — sits behind an
/// approved session, and the session sits behind two calls: the profile row and
/// the permission set. While those two went straight to the server, a launch
/// with no signal resolved to nothing, the router held at the splash, and an
/// app full of carefully offline-capable screens could not be reached from the
/// first frame. The offline work was all there and none of it was reachable.
///
/// That is a defect with no error message and no failing test — the app simply
/// showed a retry button — which is why this file is a lint over the SOURCE
/// rather than a unit test. Testing it properly would mean standing up Supabase
/// and a fake auth stream to prove a negative; what actually needs guarding is
/// far simpler and is the thing that regressed: these two reads must go through
/// [readWithSnapshot], and nobody must quietly change them back.
///
/// The same shape as `migration_permission_codes_test.dart`: it cannot tell you
/// the app works, it can tell you the one line that made it work is still
/// there.
void main() {
  String read(String path) {
    final file = File(path);
    expect(
      file.existsSync(),
      isTrue,
      reason: 'run from the project root — ${file.absolute.path}',
    );
    return file.readAsStringSync();
  }

  group('the session survives a dead network', () {
    test('the profile row is read through a snapshot', () {
      final source = read('lib/features/profile/data/profile_repository.dart');

      expect(
        source.contains('Future<Cached<Profile?>> fetchMine()'),
        isTrue,
        reason:
            'fetchMine must hand back whether the answer came off disk — a '
            'bare Profile? cannot say, and the splash has no way to know it '
            'may proceed',
      );
      expect(
        source.contains('readWithSnapshot'),
        isTrue,
        reason: 'without this a launch with no signal resolves to nothing',
      );
      expect(
        source.contains("'session.profile."),
        isTrue,
        reason:
            'the key carries the user id: a shared handset must not open on '
            'the previous man name and permissions',
      );
    });

    test('the permission set is read through a snapshot', () {
      final source = read('lib/features/auth/application/session_cubit.dart');

      expect(
        source.contains('Future<Cached<Set<String>>> _loadPermissions()'),
        isTrue,
        reason:
            'a restored session with no grants opens every door for an '
            'administrator and none for anybody else, which is a worse answer '
            'than not opening at all',
      );
      expect(source.contains("'session.permissions."), isTrue);
    });

    test('the session says WHEN it was last true', () {
      final source = read('lib/features/auth/application/session_cubit.dart');

      expect(
        source.contains('final DateTime? restoredAt'),
        isTrue,
        reason:
            'a time, not a flag: what is stale here is the permission set, '
            'and how old it is is the only thing a reader needs in order to '
            'decide whether to trust it',
      );
    });

    test('a restored session goes and checks itself when the signal returns', () {
      final source = read('lib/features/auth/application/session_cubit.dart');

      expect(
        source.contains('Stream<void>? reconnects'),
        isTrue,
        reason:
            'otherwise a man who started the app in a dead spot carries '
            'yesterday permissions until he closes and reopens it, which '
            'nobody does mid-shift',
      );
      expect(
        source.contains('state.restoredAt != null || state.loadFailed'),
        isTrue,
        reason:
            'and only when there is something to correct — a live session '
            'refetching itself every time a wifi flickers is work done to '
            'arrive at the answer already on screen',
      );
    });

    test('the reconnect hint is actually handed in', () {
      final source = read('lib/app.dart');

      expect(
        source.contains('reconnects: platformReconnects()'),
        isTrue,
        reason:
            'the parameter existing and nobody passing it is the same bug '
            'wearing a seatbelt',
      );
    });
  });

  group('what the person is told', () {
    test('the home page says the session came off disk', () {
      final source = read(
        'lib/features/home/presentation/home_sidebar_view.dart',
      );

      expect(
        source.contains('SavedCopyBanner(savedAt: session.restoredAt)'),
        isTrue,
        reason:
            'opening the app on a saved session and saying nothing is the app '
            'letting somebody act on Tuesday permissions believing they are '
            'this morning',
      );
    });
  });
}
