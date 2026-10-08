/// What one column of a written table IS.
///
/// Until 0104 a column was a bare string — its heading — and every cell was a
/// text box. The retired report TYPES knew better: `report_type_columns`
/// carried a kind, a reference set and an input hint, which is how توزيع
/// الوجبات offered a dropdown of this season's clusters instead of a box to
/// misspell one into. The table block inherited their tables without their
/// intelligence; this is the intelligence, moved to where the tables now live.
library;

/// The seven things a cell can be.
enum TableColumnKind {
  text,
  number,
  date,
  time,
  timeRange,
  reference,

  /// A list of small things, stored one per line — how the published document
  /// prints مكونات الوجبات. A KIND rather than a flag beside one, because tags
  /// and text are two ways of reading one cell: `kind: date, tags: true` would
  /// be nonsense, and a shape that can express nonsense eventually will.
  tags;

  /// Unknown reads as [text], deliberately: a column typed by a newer build
  /// must render as something on an older one, not crash a published document
  /// in a reader's hand.
  static TableColumnKind fromDb(String? v) => switch (v) {
    'number' => TableColumnKind.number,
    'date' => TableColumnKind.date,
    'time' => TableColumnKind.time,
    'time_range' => TableColumnKind.timeRange,
    'reference' => TableColumnKind.reference,
    'tags' => TableColumnKind.tags,
    _ => TableColumnKind.text,
  };

  String get db => switch (this) {
    TableColumnKind.timeRange => 'time_range',
    _ => name,
  };
}

/// One typed column: its identity, its heading, and what its cells are.
class TableColumn {
  const TableColumn({
    required this.id,
    required this.label,
    this.kind = TableColumnKind.text,
    this.setCode,
    this.span = false,
  });

  /// Stable, and NEVER derived from the label. Identity is what lets a rename
  /// keep its data, a reorder carry its cells, and a span mark follow its
  /// column — all of which were positional guesses before, and one of which
  /// (`realignRows`' rename heuristic) had a documented case it could only
  /// answer by emptying two columns of numbers.
  final String id;

  final String label;
  final TableColumnKind kind;

  /// The list a reference cell draws from, by CODE — the same reason
  /// `ReportBlock.expandSetCode` is a code: a document written this season must
  /// resolve next season, when the entries differ and the list does not.
  final String? setCode;

  /// Whether a repeated value prints once against the rows it covers.
  /// Orthogonal to [kind]: a date column spans, a reference column can too.
  final bool span;

  bool get isReference => kind == TableColumnKind.reference && setCode != null;

  TableColumn copyWith({
    String? label,
    TableColumnKind? kind,
    Object? setCode = _unset,
    bool? span,
  }) => TableColumn(
    id: id,
    label: label ?? this.label,
    kind: kind ?? this.kind,
    setCode: setCode == _unset ? this.setCode : setCode as String?,
    span: span ?? this.span,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'kind': kind.db,
    if (setCode != null) 'set': setCode,
    if (span) 'span': true,
  };

  /// Reads a stored column list, whichever shape it was written in.
  ///
  /// One parser, called by both `ReportBlock` and `DraftBlock`, because the
  /// editor and the reader disagreeing about what a document says is the
  /// failure the mirror comment on `DraftBlock` warns about.
  ///
  /// The legacy shape — bare strings with parallel `spans`/`tags` bool lists —
  /// is consumed HERE and nowhere else. A bare string becomes a text column
  /// whose id is its POSITION (`c0`, `c1`, …): position is the legacy
  /// identity, since the rows are positional; the label would collide the
  /// moment two columns were both ملاحظات. This tolerance is permanent, not
  /// transitional — seeds write the old shape and are re-run by hand.
  static List<TableColumn> parseList(
    Object? columns, {
    Object? spans,
    Object? tags,
  }) {
    bool flagAt(Object? list, int i) =>
        list is List && i < list.length && list[i] == true;

    final seen = <String>{};
    final out = <TableColumn>[];
    final raw = columns is List ? columns : const [];

    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      TableColumn column;
      if (entry is Map) {
        final kind = TableColumnKind.fromDb(entry['kind']?.toString());
        final set = entry['set']?.toString().trim();
        column = TableColumn(
          id: entry['id']?.toString().trim() ?? '',
          label: entry['label']?.toString() ?? '',
          // A reference column with no list degrades to text: a picker with
          // nothing to pick from is a dead field, and dead quietly.
          kind: kind == TableColumnKind.reference && (set ?? '').isEmpty
              ? TableColumnKind.text
              : kind,
          setCode: (set ?? '').isEmpty ? null : set,
          span: entry['span'] == true,
        );
      } else {
        column = TableColumn(
          id: 'c$i',
          label: '$entry',
          kind: flagAt(tags, i) ? TableColumnKind.tags : TableColumnKind.text,
          span: flagAt(spans, i),
        );
      }

      // A missing or duplicate id gets a fresh positional one. Two columns
      // sharing an id would share a cell in every id-keyed operation — the
      // wrong-heading error again, arrived at from the other side.
      var id = column.id;
      if (id.isEmpty || seen.contains(id)) {
        id = 'c$i';
        var n = i;
        while (seen.contains(id)) {
          id = 'c${++n}';
        }
        column = TableColumn(
          id: id,
          label: column.label,
          kind: column.kind,
          setCode: column.setCode,
          span: column.span,
        );
      }
      seen.add(id);
      out.add(column);
    }
    return out;
  }
}

const Object _unset = Object();
