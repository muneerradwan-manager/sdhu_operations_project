import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/dashboard/domain/dashboard_stats.dart';

/// The five sections 0123 added, and the one failure worth a test.
///
/// `dashboard_stats` hands back untyped JSON built by hand in PL/pgSQL, and the
/// Dart reads it key by key with `?? 0` behind every one. So a key spelled
/// `check_in` on one side and `checkin` on the other does not throw, does not
/// warn, and does not fail to compile — it renders a card of zeros, which is
/// the exact thing this dashboard was extended to stop doing. Nothing but
/// reading both sides catches it.
void main() {
  final sql = File(
    'supabase/migrations/0123_the_dashboard_catches_up.sql',
  ).readAsStringSync();

  /// Every key the RPC's section for [section] emits, as the SQL spells them.
  ///
  /// Read between the section's own marker and the next one, so a key that
  /// exists in a DIFFERENT section cannot vouch for this one — which is how a
  /// naive whole-file search would have passed `series` for a section that
  /// never built one.
  String sectionSql(String startMarker, String endMarker) {
    final start = sql.indexOf(startMarker);
    final end = sql.indexOf(endMarker, start + 1);
    expect(start, greaterThan(-1), reason: 'marker missing: $startMarker');
    expect(end, greaterThan(start), reason: 'marker missing: $endMarker');
    return sql.substring(start, end);
  }

  group('the app and the RPC agree on every key', () {
    test('the migration is where this test gets its truth', () {
      expect(sql, contains('create or replace function dashboard_stats'));
    });

    // Each entry: the section's slice of the SQL, and the keys the Dart reads
    // out of it. Written out rather than derived, because the list IS the
    // contract — deriving it from the Dart would only prove the Dart agrees
    // with itself.
    final contracts = <String, ({String from, String to, List<String> keys})>{
      'tasks': (
        from: '------------------------------------------------------------- the tasks',
        to: '-------------------------------------------------------- the complaints',
        keys: [
          'total',
          'open',
          'late',
          'awaiting_review',
          'blocked',
          'escalated',
          'assignees',
          'recent',
          'by_state',
          'by_priority',
        ],
      ),
      'complaints': (
        from: '-------------------------------------------------------- the complaints',
        to: '------------------------------------------------------- the evaluations',
        keys: [
          'total',
          'open',
          'locked',
          'dismissed',
          'recent',
          'by_target',
        ],
      ),
      'evaluations': (
        from: '------------------------------------------------------- the evaluations',
        to: '---------------------------------------------------------- the check-ins',
        keys: [
          'total',
          'submitted',
          'draft',
          'late',
          'evaluators',
          'average_pct',
          'by_target',
        ],
      ),
      'checkin': (
        from: '---------------------------------------------------------- the check-ins',
        to: '---------------------------------------------------------- the incidents',
        keys: ['total', 'people', 'places', 'today', 'recent', 'series'],
      ),
      'incidents': (
        from: '---------------------------------------------------------- the incidents',
        to: 'return jsonb_strip_nulls',
        keys: [
          'total',
          'open',
          'in_progress',
          'closed',
          'recent',
          'avg_minutes_to_handle',
          'series',
        ],
      ),
    };

    for (final entry in contracts.entries) {
      test('${entry.key}: every field the app reads is one the RPC sends', () {
        final body = sectionSql(entry.value.from, entry.value.to);
        for (final key in entry.value.keys) {
          expect(
            body,
            contains("'$key',"),
            reason:
                "dashboard_stats' ${entry.key} section never emits '$key', so "
                'the card reads null and draws a zero',
          );
        }
      });
    }

    test('the five sections reach the top level under the app\'s names', () {
      // The names `DashboardStats.fromMap` looks for. `checkin` has no
      // underscore on purpose on this side and a capital I on the other
      // (`checkIn`), which is exactly the sort of pair that drifts.
      for (final key in [
        'tasks',
        'complaints',
        'evaluations',
        'checkin',
        'incidents',
      ]) {
        expect(sql, contains("'$key', v_"), reason: 'not in the final object');
      }
    });
  });

  group('what the sections parse to', () {
    test('a full answer is read field for field', () {
      final stats = DashboardStats.fromMap({
        'season': {'id': 's1', 'hijri_year': 1447, 'is_current': true},
        'incidents': {
          'total': 40,
          'open': 3,
          'in_progress': 2,
          'closed': 35,
          'recent': 9,
          'avg_minutes_to_handle': 12.5,
          'series': [
            {'day': '2026-08-01', 'n': 2},
          ],
        },
        'checkin': {
          'total': 900,
          'people': 120,
          'places': 14,
          'today': 31,
          'recent': 400,
          'series': [],
        },
        'tasks': {
          'total': 88,
          'open': 20,
          'late': 4,
          'awaiting_review': 6,
          'blocked': 1,
          'escalated': 2,
          'assignees': 17,
          'recent': 30,
          'by_state': [
            {'key': 'submitted', 'count': 6},
          ],
          'by_priority': [
            {'key': 'high', 'count': 5},
          ],
        },
        'evaluations': {
          'total': 25,
          'submitted': 18,
          'draft': 7,
          'late': 2,
          'evaluators': 9,
          'average_pct': 81.4,
          'by_target': [
            {'key': 'employee', 'count': 20},
          ],
        },
        'complaints': {
          'total': 12,
          'open': 5,
          'locked': 3,
          'dismissed': 4,
          'recent': 2,
          'by_target': [
            {'key': 'employee', 'count': 11},
          ],
        },
      });

      expect(stats.incidents!.open, 3);
      expect(stats.incidents!.avgMinutesToHandle, 12.5);
      expect(stats.checkIn!.today, 31);
      expect(stats.tasks!.awaitingReview, 6);
      expect(stats.tasks!.byState.single.key, 'submitted');
      expect(stats.evaluations!.averagePct, 81.4);
      expect(stats.complaints!.locked, 3);
      expect(stats.isEmpty, isFalse);
    });

    test('a withheld section is absent, never a zero', () {
      // Same rule the older sections follow: no permission means the key is
      // not in the object at all, and the screen must draw nothing rather than
      // report "0 open emergencies" to somebody who simply may not ask.
      final stats = DashboardStats.fromMap({
        'season': {'id': 's1', 'hijri_year': 1447, 'is_current': true},
      });

      expect(stats.incidents, isNull);
      expect(stats.checkIn, isNull);
      expect(stats.tasks, isNull);
      expect(stats.evaluations, isNull);
      expect(stats.complaints, isNull);
      expect(stats.isEmpty, isTrue);
    });

    test('an average nobody has earned yet is null, not zero', () {
      // A submitted-nothing season must not report 0% — and an unanswered
      // register must not report an instant response time.
      final stats = DashboardStats.fromMap({
        'evaluations': {'total': 4, 'submitted': 0, 'draft': 4},
        'incidents': {'total': 2, 'open': 2},
      });

      expect(stats.evaluations!.averagePct, isNull);
      expect(stats.incidents!.avgMinutesToHandle, isNull);
    });
  });
}
