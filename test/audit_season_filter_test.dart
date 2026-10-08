import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/audit/application/audit_cubit.dart';
import 'package:sdhu_operations_project/features/audit/domain/audit_event.dart';

/// Filtering the log by season, which it could not do before 0116.
///
/// The season is STAMPED on the line when it is written, not worked out from a
/// window of dates afterwards. Roughly-by-date is the thing this replaces: two
/// seasons that overlap by a day are two different answers, and the أعمال of
/// 1447 continue while 1448 is being prepared beside them.
///
/// The filter has THREE states, and the third is the one that matters. Most of
/// the log belongs to no season at all — accounts, grants, master data, place
/// codes — so a filter that could only ever narrow TO a season would hide the
/// majority of the log the moment somebody touched it. Those lines are a real
/// answer of their own, not a bucket of leftovers.
void main() {
  const season = AuditSeason(id: 's-1448', hijriYear: 1448, count: 120);
  const other = AuditSeason(id: 's-1447', hijriYear: 1447, count: 80);

  group('the three states', () {
    test('all is the default, and is the log as it has always been', () {
      const filters = AuditFilters();

      expect(filters.seasonScope, AuditSeasonScope.all);
      expect(filters.seasonScope.isAll, isTrue);
      expect(filters.seasonScope.isNone, isFalse);
      expect(filters.seasonScope.season, isNull);
      // And it does not count as a filter: the "clear filters" button must not
      // appear because the reader opened the page.
      expect(filters.isEmpty, isTrue);
    });

    test('one season carries the season and is not "none"', () {
      const scope = AuditSeasonScope.of(season);

      expect(scope.season, season);
      expect(scope.isNone, isFalse);
      expect(scope.isAll, isFalse);
    });

    test('no season is not the same value as all', () {
      // Both have a null season, and reading only that field would collapse
      // "everything" into "the lines belonging to nothing" — the filter would
      // silently show a tenth of the log and call it the whole.
      expect(AuditSeasonScope.none, isNot(AuditSeasonScope.all));
      expect(AuditSeasonScope.none.isAll, isFalse);
      expect(AuditSeasonScope.none.isNone, isTrue);
    });

    test('a contradiction cannot be written down', () {
      // There is no constructor that takes both a season and "none", which is
      // why nothing downstream has to arbitrate between them.
      const chosen = AuditSeasonScope.of(season);
      expect(chosen.isNone && chosen.season != null, isFalse);
      expect(AuditSeasonScope.none.season, isNull);
    });
  });

  group('what the filter bar reads', () {
    test('choosing a season marks the filter as set', () {
      const filters = AuditFilters(seasonScope: AuditSeasonScope.of(season));

      expect(filters.isEmpty, isFalse);
    });

    test('choosing "no season" marks it as set too', () {
      // It narrows the log as much as any other choice does, so the clear
      // button has to appear — otherwise the reader is left on a partial log
      // with no visible way back.
      const filters = AuditFilters(seasonScope: AuditSeasonScope.none);

      expect(filters.isEmpty, isFalse);
    });

    test('two seasons are two different filters', () {
      const a = AuditFilters(seasonScope: AuditSeasonScope.of(season));
      const b = AuditFilters(seasonScope: AuditSeasonScope.of(other));

      // The cubit reloads on `filters != state.filters`; equal filters would
      // leave 1447 showing while the chip said 1448.
      expect(a, isNot(b));
    });
  });

  group('copyWith', () {
    const base = AuditFilters(seasonScope: AuditSeasonScope.of(season));

    test('leaves the season alone when it is not mentioned', () {
      expect(base.copyWith(query: 'محمد').seasonScope.season, season);
    });

    test('clears through the value, not through a sentinel', () {
      // `all` is a value rather than an absence, which is what lets this one
      // field say all three things.
      expect(
        base.copyWith(seasonScope: AuditSeasonScope.all).seasonScope.isAll,
        isTrue,
      );
    });

    test('switching from a season to "none" leaves no season behind', () {
      final next = base.copyWith(seasonScope: AuditSeasonScope.none);

      expect(next.seasonScope.isNone, isTrue);
      expect(next.seasonScope.season, isNull);
    });

    test('switching from "none" to a season leaves "none" behind', () {
      const noneFilters = AuditFilters(seasonScope: AuditSeasonScope.none);
      final next = noneFilters.copyWith(
        seasonScope: const AuditSeasonScope.of(season),
      );

      expect(next.seasonScope.season, season);
      expect(next.seasonScope.isNone, isFalse);
    });
  });

  group('the option list', () {
    test('a season is read off the RPC', () {
      final parsed = AuditSeason.fromMap({
        'season_id': 's-1',
        'hijri_year': 1448,
        'n': 120,
      });

      expect(parsed.id, 's-1');
      expect(parsed.hijriYear, 1448);
      expect(parsed.count, 120);
    });

    test('two seasons are told apart by id, not by year', () {
      const a = AuditSeason(id: 'x', hijriYear: 1448, count: 1);
      const b = AuditSeason(id: 'y', hijriYear: 1448, count: 1);

      expect(a, isNot(b));
    });
  });

  group('the migration', () {
    late String sql;

    setUpAll(() {
      final file = File(
        'supabase/migrations/0116_the_log_learns_which_season_it_was.sql',
      );
      expect(
        file.existsSync(),
        isTrue,
        reason: 'run from the project root — ${file.absolute.path}',
      );
      sql = file.readAsStringSync();
    });

    test('the two RPCs are dropped before being recreated', () {
      // Adding a parameter changes the signature, so CREATE OR REPLACE would
      // leave a SECOND overload standing — and PostgREST cannot choose between
      // two functions of the same name.
      expect(sql, contains('drop function if exists audit_events('));
      expect(sql, contains('drop function if exists audit_summary('));
    });

    test('both apply the same three-state rule, spelled the same way', () {
      // 0111's rule: a header counting a wider set than the list beneath it is
      // a header that disagrees with its own page.
      final clauses = RegExp(
        r'when coalesce\(p_seasonless, false\) then a\.season_id is null',
      ).allMatches(sql);
      expect(clauses, hasLength(2));
    });

    test('the stamp never costs the write it records', () {
      // audit_season_of runs inside the trigger of every audited table. A
      // malformed id or a row that has gone must not abort the edit it exists
      // to record: an unstamped line beats a refused save.
      expect(sql, contains('when others then'));
      expect(sql, contains('return null'));
    });

    test('the lines already written are stamped, and only the ones that can be', () {
      expect(sql, contains('update audit_log a'));
      expect(
        sql,
        contains(r"?| array['season_id', 'module_id', 'node_id']"),
      );
    });

    test('a row that hangs off a file inherits the file\'s season', () {
      // module_nodes, module_members, module_tasks and module_reports carry no
      // season of their own, and building a file is exactly the work somebody
      // filtering by season is looking for.
      expect(sql, contains("p_data ? 'module_id'"));
      expect(sql, contains("p_data ? 'node_id'"));
      expect(sql, contains("p_table = 'seasons'"));
    });
  });
}
