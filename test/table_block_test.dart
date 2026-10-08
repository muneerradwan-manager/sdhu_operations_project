import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/reports/domain/report_block.dart';

ReportBlock table(Map<String, dynamic> data) =>
    ReportBlock(id: 'b-1', kind: ReportBlockKind.table, data: data);

/// A table written inside a قرار, reaching what only a report TYPE could reach.
///
/// The three meal shapes — توزيع، مواعيد، مكونات — were report types of their
/// own because a hand-written table could not do two things: grow a column per
/// تكتل from master data, and print a repeated value once against the rows it
/// covers. A type that exists only to supply those two is not a kind of
/// document; it is a table with extra powers. So the powers moved to the table
/// and the types stopped being needed (0102).
void main() {
  group('a column per entry of a list', () {
    test('the block names the list, not its entries', () {
      // By CODE rather than by id, and that is the whole reason this survives a
      // season roll: the entries differ next year, the list does not. A
      // document written this season still resolves against next season's
      // تكتلات without anybody opening it.
      final block = table({
        'columns': ['التاريخ', 'الوجبة'],
        'expand': 'clusters',
      });

      expect(block.expandSetCode, 'clusters');
      expect(block.columns, ['التاريخ', 'الوجبة']);
    });

    test('and the headings it actually has are both together', () {
      final block = table({
        'columns': ['التاريخ', 'الوجبة'],
        'expand': 'clusters',
      });

      expect(
        block.effectiveColumns(['تكتل الكعبة', 'تكتل عطاء']),
        ['التاريخ', 'الوجبة', 'تكتل الكعبة', 'تكتل عطاء'],
      );
    });

    test('an ordinary table ignores what it was handed', () {
      // No `expand`, so nothing is appended even if a caller resolves something
      // — the block decides, not the screen.
      final block = table({
        'columns': ['البند', 'العدد'],
      });

      expect(block.expandSetCode, isNull);
      expect(block.effectiveColumns(['تكتل الكعبة']), ['البند', 'العدد']);
    });

    test('an empty expand is no expand', () {
      // A dropdown set back to "none" writes '' rather than removing the key,
      // and '' must not read as a list whose code is the empty string.
      expect(table({'expand': ''}).expandSetCode, isNull);
      expect(table({'expand': '  '}).expandSetCode, isNull);
    });
  });

  group('a value printed once against the rows it covers', () {
    test('which columns merge is per column, and false past the end', () {
      final block = table({
        'columns': ['التاريخ', 'الوجبة', 'النسبة'],
        'spans': [true, false],
      });

      expect(block.spansAt(0), isTrue);
      expect(block.spansAt(1), isFalse);
      // Never declared, because `spans` was written when the table had two
      // columns and a third was added after.
      expect(block.spansAt(2), isFalse);
      // And past the columns entirely.
      expect(block.spansAt(9), isFalse);
    });

    test('a table that never declared any merges nothing', () {
      final block = table({
        'columns': ['البند', 'العدد'],
      });

      expect(block.tableColumns.any((c) => c.span), isFalse);
      expect(block.spansAt(0), isFalse);
    });

    test('a non-boolean in the list is not a merge', () {
      // The jsonb is written by an editor and read by a reader, and anything
      // that ever put a string there must not read as true.
      final block = table({
        'columns': ['أ', 'ب'],
        'spans': ['yes', 1],
      });

      expect(block.spansAt(0), isFalse);
      expect(block.spansAt(1), isFalse);
    });
  });

  group('where the generated columns go', () {
    // توزيع الوجبات is التاريخ، الوجبة، النسبة، then a column per تكتل, then
    // المجموع — the total is the sum ACROSS the clusters and belongs after the
    // things it totals. Appending blindly moves a published document's column.
    final distribution = table({
      'columns': ['التاريخ', 'الوجبة', 'النسبة', 'المجموع'],
      'expand': 'clusters',
      'expand_at': 3,
      'spans': [true, false, false, false],
    });

    test('in the middle, when the document says so', () {
      expect(distribution.effectiveColumns(['تكتل أ', 'تكتل ب']), [
        'التاريخ',
        'الوجبة',
        'النسبة',
        'تكتل أ',
        'تكتل ب',
        'المجموع',
      ]);
    });

    test('at the end, when it does not', () {
      final plain = table({
        'columns': ['أ', 'ب'],
        'expand': 'clusters',
      });

      expect(plain.effectiveColumns(['ج']), ['أ', 'ب', 'ج']);
    });

    test('and a merge follows its own column across the splice', () {
      // The marks were ticked against the TYPED columns and the table is drawn
      // against the spliced ones. Unmapped, a merge meant for التاريخ would
      // land on a cluster's count.
      expect(distribution.effectiveIndexOf(0, 2), 0);
      expect(distribution.effectiveIndexOf(2, 2), 2);
      // المجموع is the fourth typed column and the sixth drawn one.
      expect(distribution.effectiveIndexOf(3, 2), 5);
    });

    test('nothing moves when there is nothing to splice', () {
      expect(distribution.effectiveIndexOf(3, 0), 3);
      expect(distribution.effectiveColumns(const []), [
        'التاريخ',
        'الوجبة',
        'النسبة',
        'المجموع',
      ]);
    });

    test('an insertion point past the end is clamped, not thrown', () {
      // A column removed after the point was recorded. Better a table that
      // renders with its extra columns at the end than an editor that crashes
      // on a document somebody has to correct.
      final stale = table({
        'columns': ['أ'],
        'expand': 'clusters',
        'expand_at': 9,
      });

      expect(stale.effectiveColumns(['ج']), ['أ', 'ج']);
    });
  });

  test('an empty table is still empty when it only names a list', () {
    // `expand` alone is a table somebody started and did not fill. It must not
    // render as a header row over nothing.
    expect(table({'expand': 'clusters'}).isEmpty, isTrue);
    expect(
      table({
        'columns': ['أ'],
        'rows': [
          ['1'],
        ],
      }).isEmpty,
      isFalse,
    );
  });
}
