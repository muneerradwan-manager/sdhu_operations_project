import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/checkin/application/place_code_cubit.dart';
import 'package:sdhu_operations_project/features/checkin/domain/check_in.dart';

/// A place code is a sticker on a wall, and 0114 gives it an expiry date.
///
/// Everything here guards the same thing from two sides: **nobody may be
/// surprised by a rotation.** The day a code rotates, every printed copy of it
/// stops working and nobody can check in at that place until somebody has
/// reprinted the poster and walked out to stick it up. So the warning has to
/// come first, by both routes — the notification the server sends
/// `warn_before_days` ahead, and the line the card shows to whoever happens to
/// open the page.
///
/// The card's threshold must be the WIDER of the two. If it were narrower, a
/// person could open the page, see nothing, and have the paper die under him
/// before the notification he never read.
void main() {
  final today = DateTime.now();
  DateTime day(int offset) =>
      DateTime(today.year, today.month, today.day + offset);

  PlaceCodeState ready({DateTime? dueAt}) => PlaceCodeState(
    status: PlaceCodeStatus.ready,
    code: const PlaceCode(itemId: 'i', secret: 'abc'),
    dueAt: dueAt,
  );

  group('when the card starts warning', () {
    test('a schedule that is switched off never warns', () {
      // `place_code_due_at` answers null while `is_enabled` is false, and the
      // honest reading of that is "nothing will rotate on its own" — not "it
      // rotates today".
      expect(ready().isRotatingSoon, isFalse);
    });

    test('a database without 0114 is the same silence, not a warning', () {
      // The column is absent rather than null there, and the repository maps
      // both to null. A red line on every card of an un-migrated database
      // would be a warning about something that cannot happen.
      expect(ready(dueAt: null).isRotatingSoon, isFalse);
    });

    test('a month away is stated, not warned about', () {
      expect(ready(dueAt: day(30)).isRotatingSoon, isFalse);
    });

    test('inside the last week it is a warning', () {
      expect(ready(dueAt: day(6)).isRotatingSoon, isTrue);
      expect(ready(dueAt: day(1)).isRotatingSoon, isTrue);
    });

    test('a code already over its date still reads as due', () {
      // The daily pass runs at 02:40; between the date passing and the job
      // firing, the card must not go quiet.
      expect(ready(dueAt: day(-1)).isRotatingSoon, isTrue);
    });
  });

  group('the card and the server agree about the notice', () {
    late String migration;

    setUpAll(() {
      final file = File(
        'supabase/migrations/0114_a_code_expires_and_says_so_first.sql',
      );
      expect(
        file.existsSync(),
        isTrue,
        reason: 'run from the project root — ${file.absolute.path}',
      );
      migration = file.readAsStringSync();
    });

    /// What the card uses, held in one place so the two tests below cannot
    /// drift from each other.
    const cardWarnsWithinDays = 7;

    test('the card warns no later than the notification does', () {
      final match = RegExp(
        r'warn_before_days\s+integer\s+not\s+null\s+default\s+(\d+)',
      ).firstMatch(migration);
      expect(match, isNotNull, reason: 'warn_before_days lost its default');

      final serverDays = int.parse(match!.group(1)!);
      expect(
        serverDays,
        lessThanOrEqualTo(cardWarnsWithinDays),
        reason:
            'the notification would arrive before the card said anything — '
            'widen isRotatingSoon to at least $serverDays days',
      );

      // And the card's own threshold is what these tests were written against.
      expect(ready(dueAt: day(cardWarnsWithinDays - 1)).isRotatingSoon, isTrue);
    });

    test('the interval is long enough that posters are not reprinted daily', () {
      // The reason this feature is a schedule and not a 24-hour rotation. A
      // day's interval would mean every sticker in مكة and منى dies each
      // morning; the check constraint is what stops somebody setting it there.
      final floor = RegExp(
        r'rotate_every_days\s+integer\s+not\s+null\s+default\s+(\d+)\s*'
        r'check\s*\(rotate_every_days\s+between\s+(\d+)\s+and\s+(\d+)\)',
      ).firstMatch(migration.replaceAll(RegExp(r'\s+'), ' '));
      expect(floor, isNotNull, reason: 'the interval lost its bounds');

      expect(int.parse(floor!.group(1)!), greaterThanOrEqualTo(7));
      expect(int.parse(floor.group(2)!), greaterThanOrEqualTo(7));
    });

    test('the schedule is a daily PASS, not a daily rotation', () {
      // The cron entry runs once a day; what it rotates is only what is over
      // its interval. Losing either half turns this back into the thing that
      // was asked for and refused.
      expect(migration, contains("'rotate-place-codes'"));
      expect(migration, contains('run_place_code_rotation()'));
      expect(
        migration,
        contains(r'make_interval(days => v_policy.rotate_every_days)'),
      );
    });

    test('the migration does not rotate everything on the way in', () {
      // Applying it must not kill every poster already on a wall: the clock is
      // restarted for every code instead, so the first automatic rotation is a
      // full interval away and is warned about first.
      expect(
        migration,
        contains('update place_codes set rotated_at = now(), warned_at = null'),
      );
    });
  });
}
