import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../modules/data/modules_repository.dart';
import '../../modules/domain/reference_item.dart';
import '../../seasons/data/seasons_repository.dart';
import '../../seasons/domain/season.dart';
import '../data/reports_repository.dart';
import '../domain/report.dart';
import '../domain/report_type.dart';
import '../domain/table_cells.dart';

enum EditorStatus { loading, ready, saving, error }

/// A block being written, before it has an id of its own.
///
/// Everything a table block means comes from [TableBlockData], shared with
/// [ReportBlock] — the mixin exists because these two once duplicated seven
/// getters, drifted by exactly one (`expandAt`), and the editor spent a
/// release writing cells at indices the reader did not draw them at.
class DraftBlock with TableBlockData {
  DraftBlock(this.kind, {Map<String, dynamic>? data}) : data = {...?data};

  final ReportBlockKind kind;
  @override
  final Map<String, dynamic> data;

  String get text => data['text']?.toString() ?? '';

  List<String> get items => [
    for (final i in (data['items'] as List?) ?? const []) '$i',
  ];

  bool spansAt(int column) {
    final cols = tableColumns;
    return column < cols.length && cols[column].span;
  }

  bool tagsAt(int column) {
    final cols = tableColumns;
    return column < cols.length && cols[column].kind == TableColumnKind.tags;
  }
}

/// A row being edited, before it has an id of its own.
class DraftRow {
  DraftRow({Map<String, dynamic>? data}) : data = {...?data};
  final Map<String, dynamic> data;

  String value(String key) => data[key]?.toString() ?? '';
}

class ReportEditorState extends Equatable {
  const ReportEditorState({
    this.status = EditorStatus.loading,
    this.types = const [],
    this.seasons = const [],
    this.referenceSets = const [],
    this.otherReports = const [],
    this.typeId,
    this.title = '',
    this.subtitle = '',
    this.kind = DecisionKind.decision,
    this.number = '',
    this.seasonId,
    this.data = const {},
    this.rows = const [],
    this.blocks = const [],
    this.isPublished = false,
    this.error,
  });

  final EditorStatus status;
  final List<ReportType> types;
  final List<Season> seasons;
  final List<ReferenceSet> referenceSets;

  /// Every report except the one being edited, in the list projection. Held so
  /// the form can refuse a second تقرير of a once-per-season kind before the
  /// database has to.
  final List<Report> otherReports;

  final String? typeId;
  final String title;

  /// A second line naming the document. Not the `subheading` block (0102).
  final String subtitle;

  /// Whether this decides something or announces something (0102).
  final DecisionKind kind;

  /// The reference number it was issued under, when it has one.
  final String number;

  /// Null is GENERAL, and it is where a new report starts. Most of what gets
  /// written down outlives one year.
  final String? seasonId;

  final Map<String, dynamic> data;
  final List<DraftRow> rows;

  /// What a WRITTEN report contains. A type with no table is written rather
  /// than filled in, and these are what it is made of.
  final List<DraftBlock> blocks;

  final bool isPublished;
  final String? error;

  ReportType? get type => types.where((t) => t.id == typeId).firstOrNull;

  ReferenceSet? setById(String? id) =>
      id == null ? null : referenceSets.where((s) => s.id == id).firstOrNull;

  /// The entries a table block's `expand` becomes one column each of, in THIS
  /// document's season.
  ///
  /// The mirror of `ReportDetailState.expansionOf`, and the two must agree:
  /// the editor and the reader splice the generated columns at the same width
  /// or the editor writes a value under one heading and the reader draws it
  /// under another — which is the error nobody notices until the numbers are
  /// quoted.
  List<ReferenceItem> expansionOf(DraftBlock block) {
    final code = block.expandSetCode;
    if (code == null) return const [];
    final set = referenceSets.where((s) => s.code == code).firstOrNull;
    if (set == null) return const [];
    return [
      for (final item in set.itemsForSeason(seasonId))
        if (item.isActive) item,
    ];
  }

  /// Whether the chosen kind is entered once per season and that season
  /// already has its report. The season includes the GENERAL bucket: one
  /// document there too, not many.
  bool get onceConflict {
    final t = type;
    if (t == null || !t.oncePerSeason) return false;
    return otherReports.any(
      (r) => r.reportTypeId == t.id && r.seasonId == seasonId,
    );
  }

  bool get canSave =>
      title.trim().isNotEmpty && typeId != null && !onceConflict;

  ReportEditorState copyWith({
    EditorStatus? status,
    List<ReportType>? types,
    List<Season>? seasons,
    List<ReferenceSet>? referenceSets,
    List<Report>? otherReports,
    Object? typeId = _unset,
    String? title,
    String? subtitle,
    DecisionKind? kind,
    String? number,
    Object? seasonId = _unset,
    Map<String, dynamic>? data,
    List<DraftRow>? rows,
    List<DraftBlock>? blocks,
    bool? isPublished,
    String? error,
  }) => ReportEditorState(
    status: status ?? this.status,
    types: types ?? this.types,
    seasons: seasons ?? this.seasons,
    referenceSets: referenceSets ?? this.referenceSets,
    otherReports: otherReports ?? this.otherReports,
    typeId: typeId == _unset ? this.typeId : typeId as String?,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    kind: kind ?? this.kind,
    number: number ?? this.number,
    // Null means general, so it cannot be defaulted away with `??`.
    seasonId: seasonId == _unset ? this.seasonId : seasonId as String?,
    data: data ?? this.data,
    rows: rows ?? this.rows,
    blocks: blocks ?? this.blocks,
    isPublished: isPublished ?? this.isPublished,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    types,
    seasons,
    referenceSets,
    otherReports,
    typeId,
    title,
    // Both of these were missing, and the failure would have been silent in the
    // worst way: Equatable compares this list, so a state that differed only by
    // kind or subtitle would compare EQUAL and the cubit would not emit. The
    // segmented button would refuse to move under the finger.
    subtitle,
    kind,
    number,
    seasonId,
    data,
    rows,
    blocks,
    isPublished,
    error,
  ];
}

const Object _unset = Object();

/// Entering a report, and correcting one.
class ReportEditorCubit extends SafeCubit<ReportEditorState> {
  ReportEditorCubit(this._repo, this._modules, this._seasons, {this.existing})
    : super(const ReportEditorState()) {
    _load();
  }

  /// A cubit standing on a state that is already loaded.
  ///
  /// For exercising the block-table arithmetic — splices, realignments,
  /// effective indices — without a repository or a network behind it, which is
  /// most of what there is to get wrong here and none of it needs a server to
  /// be wrong in.
  @visibleForTesting
  ReportEditorCubit.forTest(super.initial)
    : _repo = ReportsRepository(),
      _modules = ModulesRepository(),
      _seasons = SeasonsRepository(),
      existing = null;

  final ReportsRepository _repo;
  final ModulesRepository _modules;
  final SeasonsRepository _seasons;

  /// The report being corrected, or null when a new one is being entered.
  final Report? existing;

  Future<void> _load() async {
    try {
      final types = await _repo.fetchTypes();
      final seasons = await _seasons.fetchSeasons();
      final sets = await _modules.fetchReferenceSets(activeOnly: false);
      // All seasons, not the current one: the editor lets a report be filed
      // under any season, and the once-per-season check must know each.
      final reports = await _repo.fetchReports();
      final e = existing;
      emit(
        ReportEditorState(
          status: EditorStatus.ready,
          types: types,
          seasons: seasons,
          referenceSets: sets,
          otherReports: [
            for (final r in reports)
              if (r.id != e?.id) r,
          ],
          // A new document is always WRITTEN, and the editor no longer asks
          // which shape it is (0102). `general` is not one choice among four
          // any more — it is the only one a person can start, and its tables
          // are built inside its own content.
          //
          // Falls back to the first type if `general` is ever missing, so the
          // editor opens with a saveable document rather than a dead save
          // button and no way to see why.
          typeId:
              e?.reportTypeId ??
              types
                  .where((t) => t.code == 'general')
                  .firstOrNull
                  ?.id ??
              types.firstOrNull?.id,
          title: e?.title ?? '',
          subtitle: e?.subtitle ?? '',
          kind: e?.kind ?? DecisionKind.decision,
          number: e?.number ?? '',
          seasonId: e?.seasonId,
          data: {...?e?.data},
          rows: [for (final r in e?.rows ?? const []) DraftRow(data: r.data)],
          blocks: [
            for (final b in e?.blocks ?? const [])
              DraftBlock(b.kind, data: b.data),
          ],
          isPublished: e?.isPublished ?? false,
        ),
      );
    } catch (err) {
      emit(
        ReportEditorState(status: EditorStatus.error, error: err.toString()),
      );
    }
  }

  void setType(String? id) => emit(state.copyWith(typeId: id, rows: const []));
  void setTitle(String v) => emit(state.copyWith(title: v));
  void setSubtitle(String v) => emit(state.copyWith(subtitle: v));
  void setKind(DecisionKind v) => emit(state.copyWith(kind: v));
  void setNumber(String v) => emit(state.copyWith(number: v));
  void setSeason(String? id) => emit(state.copyWith(seasonId: id));
  void setPublished(bool v) => emit(state.copyWith(isPublished: v));

  void setField(String key, dynamic value) {
    final data = {...state.data};
    if (value == null || (value is String && value.isEmpty)) {
      data.remove(key);
    } else {
      data[key] = value;
    }
    emit(state.copyWith(data: data));
  }


  // ------------------------------------------------------------- the blocks

  void addBlock(ReportBlockKind kind) =>
      emit(state.copyWith(blocks: [...state.blocks, DraftBlock(kind)]));

  void removeBlock(int index) {
    final blocks = [...state.blocks]..removeAt(index);
    emit(state.copyWith(blocks: blocks));
  }

  /// Up or down by one. A notice is written in the order it is read, and the
  /// order is the thing most often got wrong on the first pass.
  void moveBlock(int index, int delta) {
    final to = index + delta;
    if (to < 0 || to >= state.blocks.length) return;
    final blocks = [...state.blocks];
    final moved = blocks.removeAt(index);
    blocks.insert(to, moved);
    emit(state.copyWith(blocks: blocks));
  }

  /// Writes one block's typed columns and moves the cells with them.
  ///
  /// All column edits — add, rename, retype, move, remove, span — funnel here,
  /// because the movement is the dangerous half and it must happen exactly one
  /// way. [moveCells] realigns by column ID (exact where the old heading-text
  /// heuristic guessed) and carries the generated block across the splice
  /// untouched — its predecessor returned rows of `after.length`, which on
  /// توزيع الوجبات threw thirteen columns of cluster counts away on a rename.
  ///
  /// Every write normalises: the columns are stored as objects and the legacy
  /// `spans`/`tags` parallel lists are dropped, so a document saved once never
  /// carries both shapes.
  void _setBlockTableColumns(int index, List<TableColumn> after) {
    final b = state.blocks[index];
    final before = b.tableColumns;
    final expanded = state.expansionOf(b).length;
    final beforeAt = b.expandAt ?? before.length;
    final afterAt = beforeAt.clamp(0, after.length);

    final blocks = [...state.blocks];
    final data = {...b.data}
      ..remove('spans')
      ..remove('tags');
    data['columns'] = [for (final c in after) c.toJson()];
    if (b.expandSetCode != null) data['expand_at'] = afterAt;
    data['rows'] = moveCells(
      before: before,
      after: after,
      rows: b.rows,
      expandedCount: expanded,
      beforeAt: beforeAt,
      afterAt: afterAt,
    );
    blocks[index] = DraftBlock(b.kind, data: data);
    emit(state.copyWith(blocks: blocks));
  }

  void addBlockColumn(int index) {
    final b = state.blocks[index];
    final cols = b.tableColumns;
    // A fresh id past every existing one — never the label's, never reused.
    var n = cols.length;
    final taken = {for (final c in cols) c.id};
    while (taken.contains('c$n')) {
      n++;
    }
    _setBlockTableColumns(index, [
      ...cols,
      TableColumn(id: 'c$n', label: ''),
    ]);
  }

  /// Label only, touching no row — which is the whole point of ids. The old
  /// path ran every rename through a heuristic that emptied both columns when
  /// two headings changed at once.
  void renameBlockColumn(int index, String columnId, String label) {
    _setBlockTableColumns(index, [
      for (final c in state.blocks[index].tableColumns)
        c.id == columnId ? c.copyWith(label: label) : c,
    ]);
  }

  /// Changes what a column's cells ARE, coercing what is already in them.
  ///
  /// The one column edit that can genuinely invalidate data, so the caller is
  /// handed the loss count FIRST via [retypeLossCount] and asks the person
  /// before calling this. Nothing else in this app empties a column silently,
  /// and this must not be the first.
  void retypeBlockColumn(
    int index,
    String columnId,
    TableColumnKind kind, {
    String? setCode,
  }) {
    final b = state.blocks[index];
    final cols = b.tableColumns;
    final at = cols.indexWhere((c) => c.id == columnId);
    if (at < 0) return;

    final set = setCode == null
        ? null
        : state.referenceSets.where((s) => s.code == setCode).firstOrNull;
    final effective = b.effectiveIndexOf(at, state.expansionOf(b).length);

    // Coerce the cells in place first, then swap the column: the movement
    // helper keys by id and the id does not change here.
    final rows = [
      for (final row in b.rows)
        [
          for (var i = 0; i < row.length; i++)
            i == effective
                ? coerceCell(row[i], kind, set: set).value
                : row[i],
        ],
    ];
    final blocks = [...state.blocks];
    final data = {...b.data}
      ..remove('spans')
      ..remove('tags');
    data['columns'] = [
      for (final c in cols)
        (c.id == columnId
                ? c.copyWith(
                    kind: kind,
                    setCode: kind == TableColumnKind.reference
                        ? setCode
                        : null,
                  )
                : c)
            .toJson(),
    ];
    data['rows'] = rows;
    blocks[index] = DraftBlock(b.kind, data: data);
    emit(state.copyWith(blocks: blocks));
  }

  /// How many filled cells a retype would empty — asked before [retypeBlockColumn].
  int retypeLossCount(
    int index,
    String columnId,
    TableColumnKind kind, {
    String? setCode,
  }) {
    final b = state.blocks[index];
    final cols = b.tableColumns;
    final at = cols.indexWhere((c) => c.id == columnId);
    if (at < 0) return 0;
    final set = setCode == null
        ? null
        : state.referenceSets.where((s) => s.code == setCode).firstOrNull;
    final effective = b.effectiveIndexOf(at, state.expansionOf(b).length);
    var lost = 0;
    for (final row in b.rows) {
      if (effective < row.length &&
          coerceCell(row[effective], kind, set: set).lost) {
        lost++;
      }
    }
    return lost;
  }

  void moveBlockColumn(int index, String columnId, int delta) {
    final cols = [...state.blocks[index].tableColumns];
    final at = cols.indexWhere((c) => c.id == columnId);
    final to = at + delta;
    if (at < 0 || to < 0 || to >= cols.length) return;
    final moved = cols.removeAt(at);
    cols.insert(to, moved);
    _setBlockTableColumns(index, cols);
  }

  void removeBlockColumn(int index, String columnId) {
    _setBlockTableColumns(index, [
      for (final c in state.blocks[index].tableColumns)
        if (c.id != columnId) c,
    ]);
  }

  /// Whether a repeated value prints once against the rows it covers.
  void toggleBlockColumnSpan(int index, String columnId) {
    _setBlockTableColumns(index, [
      for (final c in state.blocks[index].tableColumns)
        c.id == columnId ? c.copyWith(span: !c.span) : c,
    ]);
  }

  /// The master-data list whose entries become one column each.
  ///
  /// The rows are NOT realigned. A generated column's values are keyed by
  /// position after the typed ones, and changing which list generates them
  /// changes how many there are — carrying the old values across would put a
  /// count that belonged to one تكتل under another's name, which is the error
  /// `realignRows` exists to prevent and the one nobody notices until the
  /// numbers are quoted. Emptying is the honest answer.
  void setBlockExpand(int index, String? code) {
    final b = state.blocks[index];
    if (b.expandSetCode == code) return;
    final expanded = state.expansionOf(b).length;
    final at = b.expandAt ?? b.columns.length;
    _setBlock(index, {
      'expand': code,
      // A new list starts its columns at the end; a document that wants them
      // in the middle records that at conversion (0103) or on a column edit.
      'expand_at': code == null ? null : b.columns.length,
      // The generated cells are CUT OUT, not truncated from the end: the old
      // `take(columns.length)` assumed they sat last, and on توزيع الوجبات —
      // where المجموع sits after them — it kept the clusters and threw away
      // the totals.
      'rows': [
        for (final row in b.rows)
          [...row.take(at), ...row.skip(at + expanded)],
      ],
    });
  }

  void addBlockRow(int index) {
    final b = state.blocks[index];
    // Sized to every column the table HAS — typed and generated alike. Sized
    // to the typed ones alone, a 17-column distribution row was born 4 cells
    // wide, and the first cluster count typed into it landed under المجموع.
    final width = b.columns.length + state.expansionOf(b).length;
    _setBlock(index, {
      'rows': [
        ...b.rows,
        List.filled(width, ''),
      ],
    });
  }

  void removeBlockRow(int index, int row) {
    final rows = [...state.blocks[index].rows]..removeAt(row);
    _setBlock(index, {'rows': rows});
  }

  /// Writes one cell. [column] is the EFFECTIVE index — the position in the
  /// stored row, generated columns included — and the UI must supply it as
  /// such. The editor used to hand this its typed loop index, which on any
  /// table with an expansion pointed at the wrong cell: the حقل labelled
  /// المجموع read and overwrote the first تكتل's count.
  void setBlockCell(int index, int row, int column, String value) {
    final rows = [
      for (final r in state.blocks[index].rows) [...r],
    ];
    while (rows[row].length <= column) {
      rows[row].add('');
    }
    rows[row][column] = value;
    _setBlock(index, {'rows': rows});
  }

  void _setBlock(int index, Map<String, dynamic> patch) {
    final blocks = [...state.blocks];
    blocks[index] = DraftBlock(
      blocks[index].kind,
      data: {...blocks[index].data, ...patch},
    );
    emit(state.copyWith(blocks: blocks));
  }

  void setBlockValue(int index, String key, Object? value) {
    final blocks = [...state.blocks];
    final data = {...blocks[index].data};
    if (value == null || (value is String && value.isEmpty)) {
      data.remove(key);
    } else {
      data[key] = value;
    }
    blocks[index] = DraftBlock(blocks[index].kind, data: data);
    emit(state.copyWith(blocks: blocks));
  }

  // NOTE: `DraftRow`, `state.rows` and the `p_rows` mapping in `save()` are
  // KEPT even though no editor path writes them any more. `save_report`
  // deletes and re-inserts rows, so an editor that forgot them would strip a
  // legacy typed document's table on its next save. "There are none left" is
  // a fact about production, not about the code.

  /// Saves and returns the report's id, or null with [state.error] set.
  ///
  /// The rows and blocks are replaced wholesale rather than diffed. A report's
  /// table is small and entered as one thing; matching row against row to
  /// write three updates instead of a delete and an insert would be more code
  /// and more ways to leave it half-written.
  ///
  /// One RPC, not five requests: the `save_report` function (migration 0074)
  /// does header + rows + blocks in a single transaction, so a connection that
  /// dies mid-save can no longer leave a report stripped of its table.
  Future<String?> save() async {
    if (!state.canSave) return null;
    emit(state.copyWith(status: EditorStatus.saving, error: null));
    try {
      final id =
          await supabase.rpc(
                'save_report',
                params: {
                  'p_report_id': existing?.id,
                  'p_report_type_id': state.typeId,
                  'p_season_id': state.seasonId,
                  'p_title': state.title.trim(),
                  // Empty is NULL, not an empty string: a report without a
                  // number has none, and '' would sort and search as though
                  // it did.
                  'p_number': state.number.trim().isEmpty
                      ? null
                      : state.number.trim(),
                  'p_kind': state.kind.dbName,
                  'p_subtitle': state.subtitle.trim().isEmpty
                      ? null
                      : state.subtitle.trim(),
                  'p_data': state.data,
                  'p_is_published': state.isPublished,
                  'p_rows': [
                    for (var i = 0; i < state.rows.length; i++)
                      if (state.rows[i].data.isNotEmpty)
                        {'data': state.rows[i].data, 'sort_order': i + 1},
                  ],
                  'p_blocks': [
                    for (var i = 0; i < state.blocks.length; i++)
                      {
                        'kind': state.blocks[i].kind.db,
                        'data': state.blocks[i].data,
                        'sort_order': i + 1,
                      },
                  ],
                },
              )
              as String;

      emit(state.copyWith(status: EditorStatus.ready));
      return id;
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.ready, error: e.toString()));
      return null;
    }
  }
}
