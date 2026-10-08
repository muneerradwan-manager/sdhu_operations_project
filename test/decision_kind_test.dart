import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/reports/domain/report.dart';

/// القرارات were never only قرارات.
///
/// A قرار DECIDES — forms a committee, appoints a supervisor, allots the camps
/// — and somebody is bound by it. A تعميم TELLS — the meal times, the movement
/// plan — and everybody is meant to know it. Filed in one undifferentiated
/// list, a man looking for what he must DO reads past everything he merely
/// needs to know.
void main() {
  test('the database spellings round-trip', () {
    for (final kind in DecisionKind.values) {
      expect(DecisionKind.fromDb(kind.dbName), kind);
    }
  });

  test('a spelling this build does not know is a قرار, not a crash', () {
    // An older app reading a kind a newer migration added must not throw in
    // somebody's hand. Falling back to `decision` is the honest default: it is
    // what every row in the table was before 0102, and what the column's own
    // default still is.
    expect(DecisionKind.fromDb('memorandum'), DecisionKind.decision);
    expect(DecisionKind.fromDb(null), DecisionKind.decision);
  });

  test('and the column agrees with the enum about that default', () {
    // Two defaults, one meaning. If the column ever defaulted to `circular`
    // while Dart read an unknown value as `decision`, a row created by an older
    // build would be filed one way and displayed the other.
    final sql = File(
      'supabase/migrations/0102_a_decision_or_a_circular.sql',
    ).readAsStringSync();

    expect(sql, contains("not null default 'decision'"));
  });

  test('a document carries a kind whether or not the server sent one', () {
    // The list and the detail screens read the same rows, and one of them
    // forgetting the column would otherwise show every document as whatever
    // Dart's field default happened to be.
    final report = Report.fromMap({
      'id': 'r-1',
      'report_type_id': 't-1',
      'title': 'قرار تشكيل لجنة',
      'updated_at': DateTime(2026, 8, 6).toIso8601String(),
    });

    expect(report.kind, DecisionKind.decision);
  });

  test('the two fields that were a second place to write the body are gone', () {
    // A "subtitle" is a heading block that cannot be moved and "notes" is a
    // paragraph block that is always last and never where it belongs. Both
    // invited somebody to put the substance of a قرار where the reader is not
    // looking for it.
    final sql = File(
      'supabase/migrations/0102_a_decision_or_a_circular.sql',
    ).readAsStringSync();

    expect(sql, contains('delete from report_type_fields'));
    expect(sql, contains("f.key in ('subtitle', 'note')"));
    // The VALUES stay. Deleting a manager's typed sentence to tidy a schema is
    // not a trade a migration is entitled to make.
    expect(sql, isNot(contains("data - 'subtitle'")));
  });
}
