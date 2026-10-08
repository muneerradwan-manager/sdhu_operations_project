import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/modules/domain/operational_module.dart';
import 'package:sdhu_operations_project/features/modules/domain/reference_item.dart';

/// Where a man sleeps, and how full the building is (0139).
///
/// Two things worth pinning here rather than only in SQL. The first is that the
/// posting row carries a hotel at all and that reading it back is not silently
/// lossy — a dropped `housing_item_id` in `fromMap` would show up as a قطاع
/// supervisor whose السكن went blank every time the page reloaded, and nothing
/// would throw. The second is the arithmetic of the occupancy card, which is the
/// figure somebody decides on: whether a hotel is full.
void main() {
  group('a posting carries a hotel', () {
    test('reads it back off the row', () {
      final member = ModuleMember.fromMap({
        'id': 'm1',
        'role_id': 'sector_supervisor',
        'profile_id': 'p1',
        'node_id': 'sector-1',
        'housing_item_id': 'hotel-safwa',
      });

      expect(member.housingItemId, 'hotel-safwa');
    });

    test('and null is a man whose bed nobody has said yet', () {
      final member = ModuleMember.fromMap({
        'id': 'm2',
        'role_id': 'tower_supervisor',
        'profile_id': 'p2',
        'node_id': 'tower-1',
      });

      expect(member.housingItemId, isNull);
    });

    test('housingOf keeps a key for the man with no hotel', () {
      // The distinction the write path turns on: a profile absent from the map
      // means "this level never asked", and a profile present with null means
      // "somebody cleared it". Collapsing the two would make a سكن impossible
      // to remove once set.
      final node = ModuleNode(
        id: 'sector-1',
        moduleId: 'file-1',
        levelId: 'sector',
        members: const [
          ModuleMember(
            id: 'm1',
            roleId: 'r1',
            profileId: 'p1',
            housingItemId: 'hotel-safwa',
          ),
          ModuleMember(id: 'm2', roleId: 'r1', profileId: 'p2'),
          ModuleMember(id: 'm3', roleId: 'r2', profileId: 'p3'),
        ],
      );

      final housing = node.housingOf('r1');
      expect(housing, hasLength(2));
      expect(housing['p1'], 'hotel-safwa');
      expect(housing.containsKey('p2'), isTrue);
      expect(housing['p2'], isNull);
      expect(housing.containsKey('p3'), isFalse, reason: 'that is another role');
    });
  });

  group('how full a hotel is', () {
    test('a bed is a bed — staff and pilgrims share the ceiling', () {
      const o = PlaceOccupancy(staff: 8, pilgrims: 112, capacity: 130);
      expect(o.total, 120);
      expect(o.isOver, isFalse);
    });

    test('the staff are what tips it over', () {
      // The case 0139 exists for: 128 pilgrims alone read as inside a 130-bed
      // hotel, and the eight of the mission asleep in it were counted nowhere.
      const pilgrimsOnly = PlaceOccupancy(
        staff: 0,
        pilgrims: 128,
        capacity: 130,
      );
      expect(pilgrimsOnly.isOver, isFalse);

      const withStaff = PlaceOccupancy(staff: 8, pilgrims: 128, capacity: 130);
      expect(withStaff.total, 136);
      expect(withStaff.isOver, isTrue);
      expect(withStaff.excess, 6);
    });

    test('a ceiling nobody set is not a ceiling of zero', () {
      // 3142 states no capacity for some hotels. Treating the absence as 0
      // would paint every one of them red.
      const o = PlaceOccupancy(staff: 8, pilgrims: 112);
      expect(o.capacity, isNull);
      expect(o.isOver, isFalse);
      expect(o.excess, 0);
    });
  });

  group('the migration is where this test gets its truth', () {
    final sql = File(
      'supabase/migrations/0139_a_sector_supervisor_sleeps_somewhere_too.sql',
    ).readAsStringSync();

    test('the rule is stated once, and it is a coalesce', () {
      // Not a parse of the SQL — just that the one expression the whole change
      // turns on is still written down, in the one place it is meant to live.
      expect(sql, contains('coalesce(mnm.housing_item_id, mn.reference_item_id)'));
      expect(sql, contains('create view module_member_places'));
    });

    test('the four readers go through the view', () {
      // Each of these grew its own copy of the join before 0139. A reader that
      // stopped reading the view would answer a different question from the
      // other three, and the disagreement would be silent.
      for (final reader in [
        'function housing_for',
        'function season_map',
        'function presence_gaps',
        'function place_occupancy',
      ]) {
        expect(sql, contains(reader));
      }
      expect(
        'module_member_places'.allMatches(sql).length,
        greaterThanOrEqualTo(5),
        reason: 'the view, and the four functions that read it',
      );
    });

    test('accommodation is still hotels and not places-in-general', () {
      // 0136 argued the camp exclusion at length: a man supervises several
      // مخيمات for five days of the rites, and that is his work, not his bed.
      // The Dart names the same list.
      expect(sql, contains("rs.code = 'hotels'"));
      expect(ReferenceSet.hotelsCode, 'hotels');
    });

    test('a سكن that is not a hotel is refused', () {
      expect(sql, contains('module_node_members_housing_is_a_hotel'));
      expect(sql, contains('housing must be a hotel'));
    });
  });
}
