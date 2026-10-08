import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sdhu_operations_project/features/checkin/application/check_in_cubit.dart';
import 'package:sdhu_operations_project/features/checkin/domain/check_in.dart';

/// The board read from the other side.
void main() {
  PresenceGap gap({
    required String name,
    required String place,
    DateTime? lastSeen,
  }) => PresenceGap(
    profileId: name,
    fullName: name,
    itemId: place,
    placeName: place,
    lastSeen: lastSeen,
  );

  group('what the reader is shown', () {
    test('a gap with no check-in at all says so, rather than showing a time', () {
      expect(gap(name: 'أحمد', place: 'فندق').neverSeen, isTrue);
      expect(
        gap(name: 'أحمد', place: 'فندق', lastSeen: DateTime(2026)).neverSeen,
        isFalse,
      );
    });

    test('the search box narrows by name and by place', () {
      final state = PresenceState(
        gaps: [
          gap(name: 'أحمد', place: 'فندق الأنصار'),
          gap(name: 'خالد', place: 'مخيم ١٤'),
        ],
      );

      expect(state.copyWith(query: 'أحمد').shownGaps.length, 1);
      expect(state.copyWith(query: 'مخيم').shownGaps.length, 1);
      expect(state.copyWith(query: '').shownGaps.length, 2);
    });

    test('hiding a group does NOT hide a gap', () {
      // The one that matters. A group is derived from a check-in's place on the
      // board, and a man who has never checked in has no such row to derive one
      // from — so a group filter cannot judge him. Applying it anyway would
      // make an absence disappear twice: once from the world, once from the
      // screen that exists to notice it.
      final state = PresenceState(
        gaps: [gap(name: 'أحمد', place: 'فندق الأنصار')],
        hiddenGroups: const {'مكة', 'منى', '—'},
      );

      expect(state.shownGaps, hasLength(1));
    });

    test('the count is of gaps, not of what the search left', () {
      // The number on the toggle answers "is there anything wrong", which is
      // asked before anybody types in the search box — and must not drop to
      // zero because the reader is looking for one particular name.
      final state = PresenceState(
        gaps: [
          gap(name: 'أحمد', place: 'فندق'),
          gap(name: 'خالد', place: 'مخيم'),
        ],
        query: 'أحمد',
      );

      expect(state.shownGaps, hasLength(1));
      expect(state.gapCount, 2);
    });
  });

  group('the row carries what it is for', () {
    test('a telephone number is read off the posting, both kinds', () {
      const g = PresenceGap(
        profileId: 'p',
        fullName: 'أحمد',
        itemId: 'i',
        placeName: 'فندق',
        phoneSy: '+963111',
        phoneSa: '+966222',
      );
      expect(g.phoneSy, isNotNull);
      expect(g.phoneSa, isNotNull);
    });

    test('a row parses from what the function returns', () {
      final parsed = PresenceGap.fromMap({
        'profile_id': 'p1',
        'full_name': 'أحمد محمد',
        'phone_sy': '+963111',
        'phone_sa': null,
        'item_id': 'i1',
        'place_name': 'فندق الأنصار',
        'set_code': 'hotels',
        'module_id': 'm1',
        'module_name': 'الإسكان',
        'node_label': 'فندق الأنصار',
        'role_name': 'مشرف',
        'last_seen': '2026-08-07T06:00:00Z',
      });

      expect(parsed.fullName, 'أحمد محمد');
      expect(parsed.roleName, 'مشرف');
      expect(parsed.neverSeen, isFalse);
      expect(parsed.lastSeen!.isUtc, isFalse, reason: 'shown in local time');
    });

    test('a null last_seen parses to never, not to the epoch', () {
      final parsed = PresenceGap.fromMap({
        'profile_id': 'p1',
        'full_name': 'أحمد',
        'item_id': 'i1',
        'place_name': 'فندق',
        'last_seen': null,
      });
      expect(parsed.neverSeen, isTrue);
    });
  });

  test('the migration asks after posts at PLACES, not at every node', () {
    // A sector is a node too and nobody checks in to a sector. `is_place`
    // (0098) is what says which lists are things in the world, and reading it
    // rather than naming hotels and camps here is what lets a seventh kind of
    // place arrive without touching the function.
    final sql = File('supabase/migrations/'
            '0110_the_board_learns_to_say_who_is_missing.sql')
        .readAsStringSync()
        .toLowerCase();

    expect(sql, contains('rs.is_place'));
    expect(
      sql,
      contains('has_permission(\'checkin.board\')'),
      reason:
          'security definer does not inherit the policies on the tables it '
          'reads — without this it hands out the postings and every telephone '
          'number in the mission',
    );
    expect(
      sql,
      contains('p.account_status = \'approved\''),
      reason:
          'a suspended account is not an empty post; it belongs on a different '
          'screen',
    );
  });
}
