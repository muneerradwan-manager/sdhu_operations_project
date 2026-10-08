import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/constants/permission_codes.dart';
import 'package:sdhu_operations_project/features/export/data/export_catalog.dart';

/// Taking the data out is a grant, and holding it opens every type.
///
/// The interesting half of this is not the catalogue — it is that the widening
/// had to happen in the ROW POLICIES, because offering a dataset whose policy
/// refuses the reader produces an empty file and no error, and an empty export
/// is worse than a refusal: he carries it away believing it is the data.
void main() {
  group('what the grant offers', () {
    test('everything, which is the point of it', () {
      final offered = ExportCatalog.visibleTo(
        isAdmin: false,
        permissions: {PermissionCodes.exportData},
      );

      expect(offered.length, ExportCatalog.all.length);
    });

    test('and without it, only what the reader could already open', () {
      // The old rule, kept for a narrower grant somebody may want later.
      final offered = ExportCatalog.visibleTo(
        isAdmin: false,
        permissions: {PermissionCodes.referenceView},
      );

      expect(offered.length, lessThan(ExportCatalog.all.length));
      expect(
        offered.any(
          (d) => d.permissions.contains(PermissionCodes.employeesView),
        ),
        isFalse,
        reason: 'the employees were offered to somebody who cannot read them',
      );
      expect(
        offered.any(
          (d) => d.permissions.contains(PermissionCodes.referenceView),
        ),
        isTrue,
      );
    });

    test('an admin needs no code at all', () {
      expect(
        ExportCatalog.visibleTo(isAdmin: true, permissions: const {}).length,
        ExportCatalog.all.length,
      );
    });
  });

  group('what the grant must NOT open', () {
    late String sql;

    setUpAll(() {
      sql = File(
        'supabase/migrations/0100_export_and_map_are_grants.sql',
      ).readAsStringSync();
    });

    test('the fence around a manager\'s own case stays up', () {
      // The sharpest sentence in 0079: without the fence, `complaints.view`
      // "would be the way to find out who accused you, and the first person to
      // notice would be the one it was hidden from."
      //
      // A bare `or has_permission('export.data')` bolted onto complaints_select
      // would destroy it — the holder would export the table and read who
      // complained about him. So the widening goes INSIDE the helper the fence
      // is built around, and this asserts it went there and nowhere else.
      expect(
        sql,
        contains('function can_read_all_complaints'),
        reason: 'the widening must go inside the helper, not around the fence',
      );
      expect(
        sql,
        contains('function can_read_all_evaluations'),
      );
      expect(
        sql,
        isNot(contains('policy complaints_select')),
        reason: 'touching the policy directly is how the self-exclusion clause '
            'gets dropped',
      );
      expect(sql, isNot(contains('policy evaluations_select')));
    });

    test('the widened policies are the ones we meant to widen', () {
      // Written out so that adding a table to this list is an edit somebody
      // makes on purpose. Each one hands a holder rows he cannot see on any
      // screen, which is the whole cost of the grant.
      for (final policy in const [
        'policy profiles_select',
        'policy season_participants_select',
      ]) {
        expect(sql, contains(policy));
      }

      // NOT widened, deliberately: the files, their members and their duties
      // turn on membership or `modules.view_all`, and handing over the whole
      // season's staffing on the strength of a grant named "export" is a
      // decision that should be taken on its own.
      for (final untouched in const [
        'policy modules_select',
        'policy module_members_select',
        'policy module_node_members_select',
      ]) {
        expect(
          sql,
          isNot(contains(untouched)),
          reason: '$untouched was widened without anybody deciding to',
        );
      }
    });
  });
}
