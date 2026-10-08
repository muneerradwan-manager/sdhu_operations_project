import '../../../core/l10n/localized_name.dart';
import '../../modules/domain/module_type.dart';

export '../../modules/domain/module_type.dart' show ModuleFieldKind;

/// One column of the table a kind of report is.
///
/// [sourceSetId] is the interesting one: set, this single declaration stands
/// for a column per entry of that master-data list — توزيع الوجبات has a column
/// per تكتل, and the clusters are contracted per season, so the type cannot
/// name them. The cells of an expanded column are keyed by the entry's id
/// rather than by [key].
class ReportColumn {
  const ReportColumn({
    required this.id,
    required this.key,
    required this.label,
    required this.kind,
    this.sourceSetId,
    this.referenceSetId,
    this.spansRows = false,
    this.input,
  });

  final String id;
  final String key;
  final LocalizedName label;
  final ModuleFieldKind kind;

  /// The list this one declaration expands over, or null for a plain column.
  final String? sourceSetId;

  /// The list a CELL of this column draws its value from, for a reference cell.
  final String? referenceSetId;

  /// Whether a blank cell means "the same as above" — the التاريخ of all three
  /// meal documents is written once and read down the page. Presentation only:
  /// what is stored stays per row.
  final bool spansRows;

  /// How the editor asks for this column when a LIST will not do: 'time_range'
  /// for a from–to span, 'sum' for a value worked out rather than entered.
  /// A column that offers a choice says so with [kind] and [referenceSetId],
  /// like every other chooser in the app.
  final String? input;

  bool get isExpanded => sourceSetId != null;

  /// A choice from a real list the Administration keeps — the days of the
  /// Mashaaer, the meals, their kinds — said the same way the hotels and the
  /// clusters say it, so the same screen edits them all.
  bool get isChoice =>
      kind == ModuleFieldKind.reference && referenceSetId != null;

  /// A list of small things, added and removed one at a time. Stored one per
  /// line, which is how the published document prints them.
  bool get isTags => input == 'tags';

  bool get isTimeRange => input == 'time_range';

  /// Worked out from the row rather than entered — the total of a distribution
  /// is the sum of its clusters, and typing it is how it comes to disagree.
  bool get isComputed => input == 'sum';

  factory ReportColumn.fromMap(Map<String, dynamic> map) => ReportColumn(
    id: map['id'] as String,
    key: map['key'] as String,
    label: LocalizedName.fromMap(map, prefix: 'label'),
    kind: ModuleFieldKind.fromDb(map['kind'] as String?),
    sourceSetId: map['source_set_id'] as String?,
    referenceSetId: map['reference_set_id'] as String?,
    spansRows: (map['spans_rows'] as bool?) ?? false,
    input: map['input'] as String?,
  );
}

/// A kind of report: what its header states, and what its table holds.
///
/// The reader never meets this. It exists so that whoever enters a report is
/// asked for the right columns, and so that a new kind of report is data rather
/// than a schema change — the same bargain the operational files make.
class ReportType {
  const ReportType({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.fields = const [],
    this.columns = const [],
    this.isActive = true,
    this.oncePerSeason = false,
    this.sortOrder = 0,
  });

  final String id;
  final String code;
  final LocalizedName name;
  final LocalizedName? description;

  /// What a report of this kind says about itself, above its table.
  final List<ModuleField> fields;

  /// Its table, in the order the columns are read.
  final List<ReportColumn> columns;

  final bool isActive;

  /// Entered once for the whole season — the three meal documents. A second
  /// one of the same season is refused, here and by the database.
  final bool oncePerSeason;

  final int sortOrder;

  bool get hasTable => columns.isNotEmpty;

  factory ReportType.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> sorted(String key) {
      final rows = ((map[key] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .toList();
      rows.sort(
        (a, b) => ((a['sort_order'] as int?) ?? 0).compareTo(
          (b['sort_order'] as int?) ?? 0,
        ),
      );
      return rows;
    }

    return ReportType(
      id: map['id'] as String,
      code: map['code'] as String,
      name: LocalizedName.fromMap(map),
      description: map['description_ar'] == null
          ? null
          : LocalizedName.fromMap(map, prefix: 'description'),
      fields: sorted('report_type_fields').map(ModuleField.fromMap).toList(),
      columns: sorted('report_type_columns').map(ReportColumn.fromMap).toList(),
      isActive: (map['is_active'] as bool?) ?? true,
      oncePerSeason: (map['once_per_season'] as bool?) ?? false,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}
