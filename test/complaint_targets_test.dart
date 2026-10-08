import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/complaints/domain/complaint.dart';

/// What a complaint may be pointed at (0140).
///
/// The rule lives in SQL, so what is checked here is that it is still stated
/// there — and stated as the POLICIES state it. The failure this guards against
/// is quiet in a way a screenshot would not catch: widen the picker back and
/// nothing errors, nothing looks wrong, and every employee in the mission is
/// once again nameable by everybody.
void main() {
  final sql = File(
    'supabase/migrations/0140_you_complain_about_the_people_you_work_with.sql',
  ).readAsStringSync();

  group('the picker asks the policies, it does not invent a rule', () {
    test('a colleague is shares_a_module_with, the policy\'s own function', () {
      // Called, not copied. A second definition of "who do I work with" would
      // be a second answer, and the two would drift.
      expect(sql, contains('shares_a_module_with(p.id)'));
      expect(sql, contains('is_module_member(m.id)'));
    });

    test('and the manager clauses are the policies\' own', () {
      // profiles_select (0137) and modules_select (0073). Restated by hand
      // because `security definer` inherits no policy — so a change on either
      // side has to be made here too, and this test is where that is noticed.
      for (final grant in [
        "has_permission('employees.view')",
        "has_permission('employees.edit')",
        "has_permission('export.data')",
        "has_permission('modules.view_all')",
        "has_permission('modules.members')",
      ]) {
        expect(sql, contains(grant), reason: '$grant is no longer consulted');
      }
      expect(sql, contains('is_admin()'));
    });

    test('a draft file is still nobody\'s to complain about', () {
      // 0082's rule, unchanged by 0140: a file not yet handed out was handed to
      // nobody, so there is nothing to complain about yet.
      expect(sql, contains('m.is_active'));
    });

    test('and the account must still be approved, and not yourself', () {
      expect(sql, contains("p.account_status = 'approved'"));
      expect(sql, contains('p.id <> auth.uid()'));
    });

    test('three columns leave, and no more', () {
      // The narrowness is what `security definer` was for (0082). A phone or a
      // document added to this signature would empty employees.view through a
      // side door.
      expect(sql, contains('returns table (id uuid, name text, photo_url text)'));
    });
  });

  group('the escape hatch stays open', () {
    test('«شكوى أخرى» needs nothing to point at', () {
      // The whole safety valve for a man in no file: he has no colleagues and
      // no files to name, and this is where his complaint goes.
      expect(ComplaintTarget.other.needsTarget, isFalse);
      for (final t in ComplaintTarget.values) {
        if (t == ComplaintTarget.other) continue;
        expect(t.needsTarget, isTrue, reason: '$t must still name something');
      }
    });

    test('the kinds 0140 deliberately left alone are still listed', () {
      // A قرار is published to the mission at large and a فندق is master data;
      // neither is narrowed by who works where.
      expect(sql, contains("when 'report' then"));
      expect(sql, contains("rs.code = v_type::text || 's'"));
    });
  });
}
