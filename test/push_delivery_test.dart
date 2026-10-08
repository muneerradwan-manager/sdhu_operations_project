import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The three ways push delivery breaks without anything reporting it.
///
/// Migration 0107 moved push from the client to a trigger on `notifications`.
/// That fixed the silence — nine server-side writers, including 0088's urgent
/// reports and 0086's nightly escalation, had been filling inboxes and waking
/// nobody — but it also created three failure modes that share a property: the
/// app compiles, the query succeeds, no log line appears, and the only symptom
/// is a phone that stayed quiet or rang twice. Nobody finds those by running
/// the app; they are found in the field, during a season, by not being told
/// something.
///
/// This is a lint over the sources, not a check against a live project. It
/// cannot tell whether Vault is configured or whether FCM accepted anything. It
/// can tell whether the pieces still agree with each other, which is the
/// mistake that actually gets made.
void main() {
  File source(String path) {
    final file = File(path);
    expect(
      file.existsSync(),
      isTrue,
      reason: 'run from the project root — ${file.absolute.path}',
    );
    return file;
  }

  /// Dart with its whole-line `//` and `///` comments dropped.
  ///
  /// Necessary rather than fastidious, and `migration_permission_codes_test`
  /// needed the same thing for the same reason: the comment explaining WHY the
  /// client stopped pushing has to name what it stopped calling, and a check
  /// that could not tell prose from code would fail on its own documentation.
  ///
  /// Whole-line only, deliberately. Truncating every line at its first `//`
  /// would also cut `'https://…'` in half, and an offender hiding inside a URL
  /// is precisely what must not be allowed to slip through.
  String withoutComments(String dart) => dart
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  test('the client does not push — the trigger would make it twice', () {
    // Before 0107 this repository called `send-notification` after each of its
    // three sends. The trigger now pushes every row on the way in, so a
    // reinstated client call is not a redundancy, it is a second alarm — and on
    // the one message where that matters, at the hour it matters, the reader
    // has to decide whether two buzzes mean two emergencies.
    //
    // Scoped to the notifications feature rather than all of lib/, because
    // `functions.invoke` is a perfectly ordinary thing to write elsewhere: the
    // four admin functions are called that way and must keep being.
    final directory = Directory('lib/features/notifications');
    final offenders = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) => withoutComments(f.readAsStringSync()).contains(
            'send-notification',
          ),
        )
        .map((f) => f.uri.pathSegments.last)
        .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'push belongs to the database since migration 0107 — a client call '
          'to send-notification now duplicates the trigger: ${offenders.join(', ')}',
    );
  });

  /// The migration that currently defines the push trigger's function.
  ///
  /// Found rather than named, because it has already moved once: 0107
  /// introduced it and 0108 replaced it four hours later, over a wrong
  /// assumption about which schema pg_net installs into. A test pinned to
  /// `0107_*` would from that moment have been checking a file the database no
  /// longer runs — passing, and guarding nothing.
  String currentTriggerSql() {
    final defining =
        Directory('supabase/migrations')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .where(
              (f) => f
                  .readAsStringSync()
                  .contains('function push_notification_batch'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    expect(
      defining,
      isNotEmpty,
      reason: 'no migration defines push_notification_batch — 0107 is gone',
    );
    // Comments dropped, and for the third time in this file the reason is the
    // same: a migration that fixes a mistake explains it by NAMING it, so 0108
    // contains the exact `net.http_post` spelling it exists to remove. A check
    // that could not tell prose from SQL would fail on the paragraph describing
    // the bug rather than on the bug.
    return defining.last
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('--'))
        .join('\n')
        .toLowerCase();
  }

  test('the push trigger fires per statement, not per row', () {
    // The whole argument of 0041 was that a broadcast to five hundred people
    // must cost ONE FCM call and not five hundred: the inbox rows are per
    // person because a read mark is, but the push names a topic and Google
    // fans it out.
    //
    // `for each row` here would undo that silently. Everything would still
    // work — every phone would still be told — and the bill, the rate limit and
    // the five hundred sockets would be the only evidence. Worse, it degrades
    // with success: it is invisible on a test file with three members and
    // arrives on the day a real file has four hundred.
    final sql = currentTriggerSql();

    expect(
      sql,
      contains('for each statement'),
      reason: 'a row-level trigger restores the fan-out 0041 removed',
    );
    expect(
      sql,
      contains('referencing new table as new_rows'),
      reason: 'the batch is what makes one push per group possible',
    );
    expect(
      sql.contains('for each row'),
      isFalse,
      reason: 'see above — this is the regression, spelled exactly',
    );

    // A trigger that raises takes the INSERT down with it, which would turn a
    // missed push into a lost incident: the outcome worse than the bug 0107
    // fixed. The handler is what stops that, and it is not optional.
    expect(
      sql,
      contains('exception when others'),
      reason:
          'the push must never be able to roll back the notification it '
          'is announcing',
    );

    // Naming pg_net's schema is how 0107 shipped broken, and the failure is
    // invisible by construction: the handler above swallows the "no such
    // function" and the trigger returns as if nothing were configured. On this
    // project the extension sits in `extensions` while its tables answer to
    // `net`, so either spelling is a coin toss — and the call is written
    // unqualified precisely so that neither has to be guessed.
    expect(
      sql.contains('net.http_post') || sql.contains('extensions.http_post'),
      isFalse,
      reason:
          'call http_post unqualified and let search_path resolve it — a '
          'qualified call fails silently wherever pg_net is not installed',
    );
    expect(
      sql,
      contains('search_path = public, extensions, net'),
      reason: 'both candidate schemas must be on the path for that to work',
    );
  });

  test('one spelling of "incident" across the three files that must agree', () {
    // The urgent channel is chosen by matching `data.type` against this string
    // in three places, in three languages: the database writes it, the Edge
    // Function reads it to pick the alarm channel, and the app reads it again
    // to mirror that choice while foregrounded.
    //
    // Change any one and nothing breaks loudly. The alarm simply arrives on the
    // general channel — silenceable, sorted with the circulars, no sound — and
    // it arrives that way only for the message where being noticed IS the
    // feature.
    const type = 'incident';

    expect(
      source('supabase/migrations/0088_incidents.sql').readAsStringSync(),
      contains("'type', '$type'"),
      reason: 'the payload the database writes',
    );
    expect(
      source('supabase/functions/send-notification/index.ts').readAsStringSync(),
      contains("payload?.type === '$type'"),
      reason: 'what the function matches to pick the alarm channel',
    );
    expect(
      source('lib/features/notifications/data/push_service.dart')
          .readAsStringSync(),
      contains("incidentType = '$type'"),
      reason: 'what the foreground mirror matches to make the same choice',
    );
  });

  test('the function is reachable by the database that now calls it', () {
    // A Supabase secret key is not a JWT, so the gateway's own check refuses
    // the trigger's call before the function can authorise it. The symptom is
    // the exact one 0107 exists to remove — inbox rows appear, no phone rings —
    // and it would look identical to the bug having never been fixed.
    expect(
      source('supabase/config.toml').readAsStringSync(),
      contains('[functions.send-notification]'),
      reason:
          'without verify_jwt = false the trigger is refused at the gateway '
          'and 0107 delivers nothing',
    );

    // And the function must still be a gate of its own, since the gateway is
    // no longer one in front of it.
    final fn = source('supabase/functions/send-notification/index.ts')
        .readAsStringSync();
    expect(
      fn,
      contains('unauthorized'),
      reason: 'a call with no session and no service key must still be refused',
    );
    expect(
      fn,
      contains('fromDatabase'),
      reason:
          'the trusted path must be an explicit key comparison, not the '
          'absence of a check',
    );
  });
}
