import '../../modules/domain/reference_item.dart';
import 'table_column.dart';

/// What a table block holds, read one way by the editor and the reader both.
///
/// `ReportBlock` and the editor's `DraftBlock` each wrap the same jsonb, and
/// before this mixin they duplicated every getter — seven pairs, with a comment
/// on the draft warning that a getter existing on one and not the other is how
/// an editor and a reader come to disagree about what a document says. The
/// warning was earned: `expandAt` was missing from the draft, and the editor
/// spent a release writing cells at indices the reader did not draw them at.
/// One mixin, so the next getter cannot be added to one side only.
mixin TableBlockData {
  /// The jsonb. The one thing each side supplies.
  Map<String, dynamic> get data;

  /// The typed columns, in the shape 0104 writes and every earlier shape too:
  /// bare strings with parallel `spans`/`tags` lists parse as text columns
  /// with positional ids. See [TableColumn.parseList].
  List<TableColumn> get tableColumns => TableColumn.parseList(
    data['columns'],
    spans: data['spans'],
    tags: data['tags'],
  );

  /// The headings alone, for everything that thinks in labels — the reader's
  /// `effectiveColumns`, `isEmpty`, and every test written before columns had
  /// identity.
  List<String> get columns => [for (final c in tableColumns) c.label];

  /// A master-data list whose entries become one column each, by CODE so a
  /// document written this season still resolves next season: the entries
  /// differ, the list does not.
  String? get expandSetCode {
    final code = data['expand']?.toString().trim();
    return (code == null || code.isEmpty) ? null : code;
  }

  /// What a GENERATED column's cells are. Default number: 0068 declared the
  /// expanding column `number`, and a count per تكتل is the whole use case —
  /// but a table expanding over days might hold a note each, so the block may
  /// say otherwise.
  TableColumnKind get expandKind => TableColumnKind.fromDb(
    data['expand_kind']?.toString() ?? 'number',
  );

  /// Where among the typed columns the generated ones are spliced. Null means
  /// at the end. توزيع الوجبات wants them in the MIDDLE — المجموع is the sum
  /// across the clusters and belongs after the things it totals.
  int? get expandAt {
    final at = data['expand_at'];
    final cols = tableColumns.length;
    if (at is int) return at.clamp(0, cols);
    final parsed = int.tryParse('${at ?? ''}');
    return parsed?.clamp(0, cols);
  }

  /// Rows as stored: positional lists against the EFFECTIVE columns.
  ///
  /// Deliberately not keyed by column id. Generated columns have no column id
  /// — their identity is the reference item's, and their count changes with
  /// the season — and `ReportTable` speaks `List<List<String>>`. Identity is
  /// for EDIT operations; storage stays positional.
  List<List<String>> get rows => [
    for (final r in (data['rows'] as List?) ?? const [])
      [for (final c in (r as List? ?? const [])) '$c'],
  ];

  /// Every heading the table actually has, given the season's entries.
  List<String> effectiveColumns(List<String> expanded) {
    final cols = columns;
    if (expandSetCode == null || expanded.isEmpty) return cols;
    final at = expandAt ?? cols.length;
    return [...cols.take(at), ...expanded, ...cols.skip(at)];
  }

  /// Where a typed column ends up once the generated ones are spliced in.
  int effectiveIndexOf(int typedColumn, int expandedCount) {
    if (expandSetCode == null || expandedCount == 0) return typedColumn;
    final at = expandAt ?? tableColumns.length;
    return typedColumn < at ? typedColumn : typedColumn + expandedCount;
  }

  /// Every column the table actually HAS, generated ones included, in row
  /// order — which is the editor's iteration and the reader's formatting in
  /// one list.
  ///
  /// A generated column's id is its ENTRY's id (stable across edits, unique by
  /// construction), its label the entry's name, its kind the block's
  /// [expandKind] — and it never spans: two clusters that happen to hold the
  /// same count are a coincidence, not a merged cell.
  List<TableColumn> effectiveTableColumns(List<ReferenceItem> expansion) {
    final typed = tableColumns;
    if (expandSetCode == null || expansion.isEmpty) return typed;
    final at = expandAt ?? typed.length;
    return [
      ...typed.take(at),
      for (final item in expansion)
        TableColumn(id: item.id, label: item.name.ar, kind: expandKind),
      ...typed.skip(at),
    ];
  }
}
