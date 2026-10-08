import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/audit/domain/audit_labels.dart';

/// The log is only as good as what it can be ASKED.
///
/// Two failures had been sitting in this screen, and neither one broke
/// anything loudly enough to be found:
///
///   * a table whose migration attaches the audit trigger, but which no group
///     here names — its rows are written, they appear in the unfiltered list,
///     and there is no way to filter to them. A whole section of the app
///     (`evaluations`, since 0084) was in that state.
///   * a table a group DOES name but `_tables` does not label — it renders as
///     `personal_task_events` in a column of Arabic sentences.
///
/// Both are the same shape as the one `permission_labels_test.dart` guards
/// against, and both are caught by reading the migrations rather than by
/// remembering to come back here.
void main() {
  final migrations = Directory('supabase/migrations');

  /// Every table any migration attaches the generic row trigger to.
  ///
  /// Read from the SQL, not from a list kept here, because a list kept here is
  /// the thing that was already wrong. Both spellings are matched: the explicit
  /// `create trigger audit_row … on <table>` and the `foreach t in array
  /// array[…]` loops the later migrations use.
  Set<String> auditedTables() {
    final found = <String>{};
    final explicit = RegExp(
      r'create trigger audit_row\s+after[^;]*?\son\s+(\w+)',
      caseSensitive: false,
      dotAll: true,
    );
    // The loop's BODY has to be matched too, not just its array. Migrations
    // drive plenty of other `foreach t in array array[…]` loops — 0017 attaches
    // RLS policies with one — and reading their arrays as audited tables was
    // this test's first false positive: `module_type_role_tasks`, a name that
    // stopped existing when 0028 renamed it.
    final loop = RegExp(
      r'foreach\s+t\s+in\s+array\s+array\[(.*?)\]\s*loop(.*?)end\s+loop',
      caseSensitive: false,
      dotAll: true,
    );
    final quoted = RegExp(r"'(\w+)'");

    for (final file in migrations.listSync().whereType<File>()) {
      if (!file.path.endsWith('.sql')) continue;
      final sql = file.readAsStringSync();
      for (final m in explicit.allMatches(sql)) {
        found.add(m.group(1)!);
      }
      for (final m in loop.allMatches(sql)) {
        if (!m.group(2)!.contains('audit_row')) continue;
        // The whole-schema sweep in 0077 selects its tables from pg_class
        // rather than listing them, so it has no array to read and is not one
        // of these. That is correct: everything it covers existed before it,
        // and every table created since is named by its own migration — which
        // is exactly the rule this test exists to hold.
        for (final t in quoted.allMatches(m.group(1)!)) {
          found.add(t.group(1)!);
        }
      }
    }
    return found;
  }

  group('what the filter can reach', () {
    test('the migrations are where this test gets its truth', () {
      expect(
        migrations.existsSync(),
        isTrue,
        reason: 'run from the project root',
      );
      // A regex that silently matched nothing would make every assertion below
      // pass for the wrong reason, so the reading is checked against tables
      // whose migrations are known to attach the trigger — one from each of the
      // three spellings the SQL uses.
      final audited = auditedTables();
      expect(audited.length, greaterThan(10));
      expect(
        audited,
        containsAll([
          'complaints', // explicit, 0079
          'evaluation_templates', // array loop, 0084
          'personal_task_events', // array loop, 0117
          'place_check_ins', // explicit, 0122
          'incidents', // explicit, 0121
        ]),
      );
      // And a table nothing attaches must NOT be read as attached: 0028
      // renamed this one out of existence, and 0017 drives an unrelated
      // `foreach` loop over it that an earlier version of this test misread.
      expect(audited, isNot(contains('module_type_role_tasks')));
    });

    test('every audited table belongs to some section', () {
      final grouped = {for (final g in AuditLabels.groups) ...g.tables};
      final orphans = auditedTables().difference(grouped).toList()..sort();

      expect(
        orphans,
        isEmpty,
        reason:
            'these tables are written to the log and cannot be filtered to. '
            'Add them to a group in AuditLabels.groups: ${orphans.join(', ')}',
      );
    });

    test('every table a section names is labelled in Arabic', () {
      final unlabelled = <String>[];
      for (final group in AuditLabels.groups) {
        for (final table in group.tables) {
          // The fallback IS the raw table name — see `AuditLabels.table`.
          if (AuditLabels.table(table).ar == table) unlabelled.add(table);
        }
      }

      expect(
        unlabelled..sort(),
        isEmpty,
        reason:
            'these render as an English table name in an Arabic list. '
            'Add them to AuditLabels._tables: ${unlabelled.join(', ')}',
      );
    });

    test('no section is empty, and no table is claimed by two', () {
      final seen = <String, String>{};
      for (final group in AuditLabels.groups) {
        expect(group.tables, isNotEmpty, reason: '${group.key} names nothing');
        for (final table in group.tables) {
          expect(
            seen[table],
            isNull,
            reason: '$table is in both ${seen[table]} and ${group.key}',
          );
          seen[table] = group.key;
        }
      }
    });
  });
}
