import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/modules/domain/reference_item.dart';
import 'package:sdhu_operations_project/features/reports/domain/table_cells.dart';
import 'package:sdhu_operations_project/features/reports/domain/table_column.dart';

TableColumn col(String id, [String? label]) =>
    TableColumn(id: id, label: label ?? id);

/// Keeping a table's cells under the right headings when its columns change.
///
/// The predecessor (`realignRows`) matched by heading TEXT and guessed at
/// renames; its documented worst case — two headings changing at once — could
/// only be answered by emptying both columns. Columns have ids now, so every
/// case it guessed at is exact, and the one test that asserted data loss is
/// INVERTED below.
void main() {
  final abc = [col('a', 'أ'), col('b', 'ب'), col('c', 'ج')];
  final rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
  ];

  group('typed columns alone', () {
    test('nothing changed leaves every cell where it was', () {
      expect(moveCells(before: abc, after: abc, rows: rows), rows);
    });

    test('a column added in the middle does not shift what follows it', () {
      final after = [abc[0], col('x', 'س'), abc[1], abc[2]];

      expect(moveCells(before: abc, after: after, rows: rows), [
        ['1', '', '2', '3'],
        ['4', '', '5', '6'],
      ]);
    });

    test('a removed column takes only its own cells', () {
      expect(
        moveCells(before: abc, after: [abc[0], abc[2]], rows: rows),
        [
          ['1', '3'],
          ['4', '6'],
        ],
      );
    });

    test('reordering carries each column with its data', () {
      final after = [abc[2], abc[0], abc[1]];

      expect(moveCells(before: abc, after: after, rows: rows), [
        ['3', '1', '2'],
        ['6', '4', '5'],
      ]);
    });

    test('renaming keeps the column, because the id did not change', () {
      final after = [abc[0].copyWith(label: 'اليوم'), abc[1], abc[2]];

      expect(moveCells(before: abc, after: after, rows: rows), rows);
    });

    test('renaming TWO headings at once keeps both columns', () {
      // The inversion. The old heuristic could not tell two renames from a
      // swap or four edits, and its honest answer was to empty both columns of
      // numbers — asserted by its own test. Ids make guessing unnecessary.
      final after = [
        abc[0].copyWith(label: 'اليوم'),
        abc[1].copyWith(label: 'الوجبة'),
        abc[2],
      ];

      expect(moveCells(before: abc, after: after, rows: rows), rows);
    });

    test('a short row is padded rather than throwing', () {
      expect(
        moveCells(
          before: abc,
          after: abc,
          rows: [
            ['1'],
          ],
        ),
        [
          ['1', '', ''],
        ],
      );
    });

    test('emptying the columns empties the rows with them', () {
      expect(
        moveCells(before: abc, after: const [], rows: rows),
        [<String>[], <String>[]],
      );
    });

    test('no rows is no work', () {
      expect(moveCells(before: abc, after: abc, rows: const []), isEmpty);
    });
  });

  group('across the splice', () {
    // توزيع الوجبات: typed أ ب ج د, three generated cells between ج and د.
    final typed = [col('a', 'أ'), col('b', 'ب'), col('c', 'ج'), col('d', 'د')];
    final spliced = [
      ['1', '2', '3', 'x0', 'x1', 'x2', '4'],
    ];

    test('a typed column added does not truncate the generated cells', () {
      final after = [...typed, col('e', 'هـ')];

      expect(
        moveCells(
          before: typed,
          after: after,
          rows: spliced,
          expandedCount: 3,
          beforeAt: 3,
          afterAt: 3,
        ),
        [
          ['1', '2', '3', 'x0', 'x1', 'x2', '4', ''],
        ],
      );
    });

    test('the generated block follows the insertion point when it moves', () {
      final after = [typed[0], typed[2], typed[3]]; // ب removed

      expect(
        moveCells(
          before: typed,
          after: after,
          rows: spliced,
          expandedCount: 3,
          beforeAt: 3,
          afterAt: 2,
        ),
        [
          ['1', '3', 'x0', 'x1', 'x2', '4'],
        ],
      );
    });

    test('a generated cell keeps its cluster when a typed column is removed',
        () {
      final after = [typed[0], typed[1], typed[3]]; // ج removed

      final moved = moveCells(
        before: typed,
        after: after,
        rows: spliced,
        expandedCount: 3,
        beforeAt: 3,
        afterAt: 2,
      );

      // x0 is still the FIRST generated cell — it did not slide onto x1.
      expect(moved.single, ['1', '2', 'x0', 'x1', 'x2', '4']);
    });
  });

  group('what a cell shows a reader', () {
    const text = TableText();

    test('a reference cell draws through the resolver, or blank when gone', () {
      final resolved = TableText(
        referenceName: (set, id) => id == 'i-1' ? '٨ ذي الحجة' : '',
      );
      final column = const TableColumn(
        id: 'c0',
        label: 'التاريخ',
        kind: TableColumnKind.reference,
        setCode: 'mashaaer_days',
      );

      expect(drawCell(column, 'i-1', resolved), '٨ ذي الحجة');
      // A uuid nobody can use is worse than a gap.
      expect(drawCell(column, 'i-gone', resolved), '');
    });

    test('a legacy Arabic time sentence still reads as a range', () {
      // The retired editor stored the LOCALIZED sentence, so the stored value
      // depended on the app's UI language at entry time. The three converted
      // documents carry these, and they must keep rendering.
      final range = TableText(timeRange: (a, b) => '$a → $b');
      const column = TableColumn(
        id: 'c0',
        label: 'التوقيت',
        kind: TableColumnKind.timeRange,
      );

      expect(
        drawCell(column, 'من الساعة 13:00 إلى الساعة 16:00', range),
        '13:00 → 16:00',
      );
      expect(drawCell(column, '13:00-16:00', range), '13:00 → 16:00');
    });

    test('a range that cannot be read draws as it was stored, never blank', () {
      const column = TableColumn(
        id: 'c0',
        label: 'التوقيت',
        kind: TableColumnKind.timeRange,
      );

      expect(drawCell(column, 'بعد العشاء', text), 'بعد العشاء');
    });

    test('a date draws formatted, and an unparseable one as stored', () {
      final dated = TableText(date: (iso) => 'يوم $iso');
      const column = TableColumn(
        id: 'c0',
        label: 'التاريخ',
        kind: TableColumnKind.date,
      );

      expect(drawCell(column, '2026-08-06', dated), 'يوم 2026-08-06');
      expect(drawCell(column, 'الخميس', dated), 'الخميس');
    });
  });

  group('what a cell becomes when its column changes kind', () {
    final set = ReferenceSet(
      id: 's',
      code: 'meal_times',
      name: const LocalizedName(ar: 'الوجبات'),
      items: const [
        ReferenceItem(
          id: 'i-1',
          setId: 's',
          name: LocalizedName(ar: 'الغداء', en: 'Lunch'),
        ),
      ],
    );

    test('to text keeps everything', () {
      expect(
        coerceCell('anything at all', TableColumnKind.text),
        (value: 'anything at all', lost: false),
      );
    });

    test('to reference keeps a cell that already names an entry', () {
      expect(
        coerceCell('i-1', TableColumnKind.reference, set: set),
        (value: 'i-1', lost: false),
      );
      expect(
        coerceCell('الغداء', TableColumnKind.reference, set: set),
        (value: 'i-1', lost: false),
      );
      expect(
        coerceCell('العشاء', TableColumnKind.reference, set: set),
        (value: '', lost: true),
      );
    });

    test('to time normalises and pads, or empties and says so', () {
      expect(
        coerceCell('9:30', TableColumnKind.time),
        (value: '09:30', lost: false),
      );
      expect(
        coerceCell('صباحاً', TableColumnKind.time),
        (value: '', lost: true),
      );
    });

    test('to a range writes the canonical machine form', () {
      // NOT the localized sentence — the stored value must not depend on the
      // UI language at entry time, which is the legacy bug being retired.
      expect(
        coerceCell('من الساعة 9:00 إلى الساعة 12:30', TableColumnKind.timeRange),
        (value: '09:00-12:30', lost: false),
      );
    });

    test('an empty cell is never a loss', () {
      expect(
        coerceCell('', TableColumnKind.reference, set: set),
        (value: '', lost: false),
      );
    });
  });
}
