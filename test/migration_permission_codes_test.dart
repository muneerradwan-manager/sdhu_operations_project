import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A permission code that no longer exists is not an error anywhere.
///
/// Migration 0073 split the coarse grants into fine ones and then DELETED the
/// old rows — `modules.manage`, `modules.types`, `reports.manage` and two more.
/// From that moment `has_permission('modules.manage')` is a clause that can
/// never be true. Postgres does not object: the string is just a string, the
/// policy is valid, and it silently grants nothing.
///
/// So a migration written afterwards that reaches for one of the retired names
/// produces a table only an administrator can read, and the people it was built
/// for find out during a season by not being able to see something. That is a
/// class of bug with no error message, no failing query and no log line — which
/// is exactly the kind worth a test.
///
/// This is a lint over the SQL, not a check against a live database. It cannot
/// tell whether a policy is still in force; it can tell whether a migration
/// used a name that a migration before it had already retired, and that is the
/// mistake that actually gets made.
void main() {
  final directory = Directory('supabase/migrations');

  late List<File> migrations;

  setUpAll(() {
    expect(
      directory.existsSync(),
      isTrue,
      reason: 'run from the project root — ${directory.absolute.path}',
    );
    migrations =
        directory
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
  });

  /// The four-digit prefix. Order is what makes "already retired" meaningful.
  int numberOf(File file) {
    final name = file.uri.pathSegments.last;
    return int.parse(name.substring(0, 4));
  }

  /// SQL with `--` comments removed.
  ///
  /// Necessary rather than fastidious: the comment ABOVE the fix in 0086
  /// explains the retirement by naming the retired code, and a check that could
  /// not tell prose from code would fail on its own documentation.
  String withoutComments(String sql) =>
      sql.split('\n').map((line) {
        final marker = line.indexOf('--');
        return marker < 0 ? line : line.substring(0, marker);
      }).join('\n');

  test('no migration uses a permission code an earlier one retired', () {
    // `delete from permissions where code in ('a', 'b', …)`
    final retirement = RegExp(
      r"delete\s+from\s+permissions\s+where\s+code\s+in\s*\(([^)]*)\)",
      caseSensitive: false,
      multiLine: true,
    );
    final quoted = RegExp(r"'([^']+)'");

    // Two spellings, and the second one matters more than it looks.
    //
    // 0073 rewrites eight catalog policies from inside a `do $$ … execute
    // format(…) $$` loop, where the policy names are built at run time and the
    // code reads `has_permission(''reference.edit'')` — doubled quotes, because
    // it is a string inside a string. A check that only knew the plain form
    // would be blind to every policy written that way, which is exactly how
    // one would slip a retired code past this test.
    final used = RegExp(r"has_permission\(''?([^']+)''?\)");

    // code -> the migration number that retired it.
    final retiredAt = <String, int>{};
    for (final file in migrations) {
      final sql = withoutComments(file.readAsStringSync());
      for (final match in retirement.allMatches(sql)) {
        for (final code in quoted.allMatches(match.group(1)!)) {
          retiredAt[code.group(1)!] = numberOf(file);
        }
      }
    }

    expect(
      retiredAt,
      isNotEmpty,
      reason: 'the retirement in 0073 should be found — if this is empty the '
          'pattern has drifted and the whole test is passing vacuously',
    );

    final offences = <String>[];
    for (final file in migrations) {
      final number = numberOf(file);
      final sql = withoutComments(file.readAsStringSync());
      for (final match in used.allMatches(sql)) {
        final code = match.group(1)!;
        final retired = retiredAt[code];
        // Strictly after: the migration that does the retiring names the codes
        // on its way past, and everything before it ran when they were real.
        if (retired != null && number > retired) {
          offences.add(
            '${file.uri.pathSegments.last} uses "$code", retired by '
            'migration ${retired.toString().padLeft(4, '0')}',
          );
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason:
          'a retired code can never be true, so the clause grants nothing and '
          'nothing reports it:\n  ${offences.join('\n  ')}',
    );
  });

  test('every code the app names is seeded by some migration', () {
    // The other direction, and it was open until 0098 needed it.
    //
    // `PermissionCodes` is what the app asks `session.can` about, and the
    // session's set comes from rows in `permissions`. A constant added in Dart
    // and never inserted in SQL therefore reads as "nobody holds this" — the
    // button never appears, the guard never opens, and NOTHING reports it. Same
    // silent class as a retired code, approached from the other side: one is a
    // clause that can never be true, the other a code nobody can ever be
    // granted.
    //
    // A lint over the SQL text, like its neighbour above. It cannot say whether
    // anybody was granted a code; it can say whether the code exists to grant,
    // and that is the mistake that gets made.
    final dart = File(
      'lib/core/constants/permission_codes.dart',
    ).readAsStringSync();

    // `static const someName = 'section.thing';`
    final declared = RegExp(r"static\s+const\s+\w+\s*=\s*'([^']+)'")
        .allMatches(dart)
        .map((m) => m.group(1)!)
        .where((code) => code.contains('.'))
        .toSet();

    expect(
      declared,
      isNotEmpty,
      reason: 'no codes were found — the pattern has drifted and this test is '
          'passing vacuously',
    );

    final seeded = <String>{};
    for (final file in migrations) {
      final sql = withoutComments(file.readAsStringSync());
      for (final match in RegExp(r"'([a-z_]+\.[a-z_]+)'").allMatches(sql)) {
        seeded.add(match.group(1)!);
      }
    }

    final missing = declared.difference(seeded).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason: 'named in Dart, seeded nowhere — so nobody can ever hold it and '
          'the screens behind it are dark:\n  ${missing.join('\n  ')}',
    );
  });

  test('the retired codes are the ones 0073 is known to have retired', () {
    // Pins the list. If a later migration retires something else this fails,
    // which is the moment to check that nothing was left resting on it.
    final sql = withoutComments(
      migrations
          .firstWhere((f) => f.path.contains('0073'))
          .readAsStringSync(),
    );

    for (final code in const [
      'modules.manage',
      'modules.types',
      'reports.manage',
      'seasons.manage',
      'seasons.participants',
    ]) {
      expect(sql, contains("'$code'"), reason: '$code should be named in 0073');
    }
  });
}
