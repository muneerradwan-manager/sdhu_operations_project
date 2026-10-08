import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/reports/domain/table_column.dart';

/// Reading a table's columns, whichever shape they were written in.
///
/// Two shapes coexist permanently: 0104 writes objects, but the seeds write
/// bare strings and are re-run by hand, and every document saved before 0104
/// carries strings with parallel `spans`/`tags` bool lists. One parser serves
/// both — and it is ONE parser, called by `ReportBlock` and `DraftBlock` alike,
/// because the editor and the reader disagreeing about what a document says is
/// the failure that already happened once with `expandAt`.
void main() {
  group('the legacy shape', () {
    test('a bare string is a text column, and its position is its id', () {
      // Position IS the legacy identity: the rows are positional. The label
      // would collide the moment two columns were both ملاحظات — and after
      // that every id-keyed operation lands on the wrong column.
      final cols = TableColumn.parseList(['التاريخ', 'الوجبة']);

      expect(cols[0].id, 'c0');
      expect(cols[0].label, 'التاريخ');
      expect(cols[0].kind, TableColumnKind.text);
      expect(cols[1].id, 'c1');
    });

    test('a legacy spans list becomes the column that carried it', () {
      final cols = TableColumn.parseList(
        ['التاريخ', 'الوجبة'],
        spans: [true, false],
      );

      expect(cols[0].span, isTrue);
      expect(cols[1].span, isFalse);
    });

    test('a legacy tags list becomes the tags KIND, not a second flag', () {
      // Tags and text are two ways of reading one cell, so they are
      // alternatives. A flag beside `kind` could say `date, tags: true`,
      // which is nonsense — and a shape that can express nonsense will.
      final cols = TableColumn.parseList(
        ['المكونات'],
        tags: [true],
      );

      expect(cols[0].kind, TableColumnKind.tags);
    });

    test('a non-boolean in a legacy list is not a mark', () {
      final cols = TableColumn.parseList(
        ['أ', 'ب'],
        spans: ['yes', 1],
        tags: [1, 'x'],
      );

      expect(cols.any((c) => c.span), isFalse);
      expect(cols.any((c) => c.kind == TableColumnKind.tags), isFalse);
    });
  });

  group('the object shape', () {
    test('is read as written', () {
      final cols = TableColumn.parseList([
        {
          'id': 'c0',
          'label': 'التاريخ',
          'kind': 'reference',
          'set': 'mashaaer_days',
          'span': true,
        },
      ]);

      expect(cols.single.id, 'c0');
      expect(cols.single.kind, TableColumnKind.reference);
      expect(cols.single.setCode, 'mashaaer_days');
      expect(cols.single.span, isTrue);
      expect(cols.single.isReference, isTrue);
    });

    test('an unknown kind reads as text rather than throwing', () {
      // A column typed by a newer build must render as something on an older
      // one — a published document in a reader's hand is the wrong place for
      // a crash about vocabulary.
      final cols = TableColumn.parseList([
        {'id': 'c0', 'label': 'أ', 'kind': 'hologram'},
      ]);

      expect(cols.single.kind, TableColumnKind.text);
    });

    test('two columns cannot share an id', () {
      // Or an edit lands on the wrong cell — the same wrong-heading corruption
      // ids exist to end, arrived at from the other side.
      final cols = TableColumn.parseList([
        {'id': 'c0', 'label': 'أ'},
        {'id': 'c0', 'label': 'ب'},
      ]);

      expect(cols[0].id, isNot(cols[1].id));
    });

    test('a reference column with no set is a text column', () {
      // A picker with no list is a dead field, and dead quietly.
      final cols = TableColumn.parseList([
        {'id': 'c0', 'label': 'أ', 'kind': 'reference'},
      ]);

      expect(cols.single.kind, TableColumnKind.text);
      expect(cols.single.isReference, isFalse);
    });
  });

  test('saving emits objects and never the parallel lists', () {
    // The first save of a legacy block normalises it, so the two shapes do not
    // linger past one edit.
    final json = TableColumn.parseList(
      ['التاريخ'],
      spans: [true],
      tags: [false],
    ).map((c) => c.toJson()).toList();

    expect(json.single['id'], 'c0');
    expect(json.single['span'], isTrue);
    expect(json.single.containsKey('spans'), isFalse);
    expect(json.single.containsKey('tags'), isFalse);
  });

  test('the database spellings round-trip', () {
    for (final kind in TableColumnKind.values) {
      expect(TableColumnKind.fromDb(kind.db), kind);
    }
  });
}
