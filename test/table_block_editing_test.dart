import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/modules/domain/reference_item.dart';
import 'package:sdhu_operations_project/features/reports/application/report_editor_cubit.dart';
import 'package:sdhu_operations_project/features/reports/domain/report.dart';

/// Editing a table that has an expansion, without corrupting it.
///
/// توزيع الوجبات is the shape that found all three of these: four typed
/// columns (التاريخ، الوجبة، النسبة، المجموع), thirteen generated ones spliced
/// between النسبة and المجموع, rows seventeen wide. Every rule here was broken
/// in a way that put a number under the wrong heading — the one error nobody
/// notices until the numbers are quoted.
void main() {
  ReferenceItem cluster(int i) => ReferenceItem(
    id: 'cluster-$i',
    setId: 'clusters-set',
    name: LocalizedName(ar: 'تكتل $i'),
  );

  final clusters = ReferenceSet(
    id: 'clusters-set',
    code: 'clusters',
    name: const LocalizedName(ar: 'التكتلات'),
    items: [for (var i = 0; i < 3; i++) cluster(i)],
  );

  /// A distribution-shaped block: typed columns أ ب ج د, expansion of three
  /// spliced at 3 (before د), rows seven wide.
  DraftBlock distribution() => DraftBlock(
    ReportBlockKind.table,
    data: {
      'columns': ['أ', 'ب', 'ج', 'د'],
      'expand': 'clusters',
      'expand_at': 3,
      'rows': [
        ['a', 'b', 'c', 'x0', 'x1', 'x2', 'd'],
      ],
    },
  );

  ReportEditorCubit cubit({DraftBlock? block}) {
    final c = ReportEditorCubit.forTest(
      const ReportEditorState(status: EditorStatus.ready),
    );
    c.emit(
      c.state.copyWith(
        referenceSets: [clusters],
        blocks: [block ?? distribution()],
      ),
    );
    return c;
  }

  group('the draft mirrors what the reader reads', () {
    test('expand_at reaches the draft', () {
      // This getter was MISSING from DraftBlock, which is half the corruption:
      // the editor read the generated block as sitting at the end while the
      // reader spliced it into the middle.
      expect(distribution().expandAt, 3);
    });

    test('and a typed column after the splice lands past the expansion', () {
      expect(distribution().effectiveIndexOf(3, 3), 6);
      expect(distribution().effectiveIndexOf(2, 3), 2);
    });
  });

  group('a new row', () {
    test('is born as wide as the table, not as wide as its typed columns', () {
      // Born four cells wide, a seventeen-column row was unfillable past
      // position 3 — and the first cluster count typed into it landed under
      // المجموع.
      final c = cubit()..addBlockRow(0);

      expect(c.state.blocks[0].rows.last, hasLength(7));
    });
  });

  group('editing the columns', () {
    test('renaming one keeps every generated cell', () {
      // The old heading-text realign returned rows of `after.length` — FOUR
      // cells: the three cluster counts and the total were simply gone, on a
      // rename. Identity makes the rename exact, and the splice-aware move
      // carries the generated block untouched.
      final c = cubit();
      final id = c.state.blocks[0].tableColumns[1].id;
      c.renameBlockColumn(0, id, 'باء');

      expect(c.state.blocks[0].tableColumns[1].label, 'باء');
      expect(c.state.blocks[0].rows.single, [
        'a', 'b', 'c', 'x0', 'x1', 'x2', 'd',
      ]);
    });

    test('adding a typed column keeps the generated block where it was', () {
      final c = cubit()..addBlockColumn(0);

      final b = c.state.blocks[0];
      expect(b.expandAt, 3);
      expect(b.rows.single, ['a', 'b', 'c', 'x0', 'x1', 'x2', 'd', '']);
    });

    test('removing a typed column before the splice clamps it', () {
      final c = cubit();
      final ids = [for (final col in c.state.blocks[0].tableColumns) col.id];
      c.removeBlockColumn(0, ids[2]); // ج
      c.removeBlockColumn(0, ids[3]); // د

      final b = c.state.blocks[0];
      expect(b.expandAt, 2);
      expect(b.rows.single, ['a', 'b', 'x0', 'x1', 'x2']);
    });

    test('moving a column carries its cells and leaves the splice alone', () {
      final c = cubit();
      final id = c.state.blocks[0].tableColumns[0].id; // أ one step down
      c.moveBlockColumn(0, id, 1);

      final b = c.state.blocks[0];
      expect([for (final col in b.tableColumns) col.label],
          ['ب', 'أ', 'ج', 'د']);
      expect(b.rows.single, ['b', 'a', 'c', 'x0', 'x1', 'x2', 'd']);
    });

    test('a column edit normalises the block and drops the legacy lists', () {
      final legacy = DraftBlock(
        ReportBlockKind.table,
        data: {
          'columns': ['أ', 'ب'],
          'spans': [true, false],
          'tags': [false, true],
          'rows': [
            ['1', 'x\ny'],
          ],
        },
      );
      final c = cubit(block: legacy);
      c.renameBlockColumn(0, 'c0', 'اليوم');

      final data = c.state.blocks[0].data;
      expect(data.containsKey('spans'), isFalse);
      expect(data.containsKey('tags'), isFalse);
      // The marks survived the normalisation as properties of the columns.
      final cols = c.state.blocks[0].tableColumns;
      expect(cols[0].span, isTrue);
      expect(cols[1].kind, TableColumnKind.tags);
      expect(c.state.blocks[0].rows.single, ['1', 'x\ny']);
    });

    test('a retype counts its losses before it is asked to happen', () {
      final c = cubit();
      final id = c.state.blocks[0].tableColumns[0].id; // cells: 'a'

      expect(c.retypeLossCount(0, id, TableColumnKind.time), 1);
      expect(c.retypeLossCount(0, id, TableColumnKind.text), 0);
    });
  });

  group('changing the expansion', () {
    test('cuts the generated cells OUT, keeping what sits after them', () {
      // The old truncation kept the first `columns.length` cells — which on
      // this shape kept the clusters and threw away المجموع.
      final c = cubit()..setBlockExpand(0, null);

      expect(c.state.blocks[0].rows.single, ['a', 'b', 'c', 'd']);
    });
  });

  test('a cell is written at the effective index the UI names', () {
    final c = cubit()..setBlockCell(0, 0, 6, 'total');

    expect(c.state.blocks[0].rows.single[6], 'total');
    expect(
      c.state.blocks[0].rows.single[3],
      'x0',
      reason: 'المجموع wrote over the first تكتل',
    );
  });
}
