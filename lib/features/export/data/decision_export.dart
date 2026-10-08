import '../../../core/l10n/localized_name.dart';
import '../../modules/data/modules_repository.dart';
import '../../modules/domain/module_type.dart';
import '../../modules/domain/reference_item.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/domain/report.dart';
import '../../reports/domain/report_type.dart';
import '../../reports/domain/table_cells.dart';
import '../../seasons/data/seasons_repository.dart';
import '../domain/export_dataset.dart';
import 'export_sections.dart';
import 'export_values.dart';

LocalizedName _n(String ar, String en) => LocalizedName(ar: ar, en: en);

String _label(ExportRequest request, String ar, String en) =>
    request.text(_n(ar, en));

/// The mission's decisions and circulars, each handed over WHOLE.
///
/// Three questions, widest first, which is the order every dataset on this
/// screen asks in: WHICH SEASON — «عام» for what is true in every one of them,
/// or 1448هـ — then WHICH ACT, a قرار or a تعميم, and then WHICH DOCUMENT, or
/// all of them.
///
/// **The middle one is not a formality.** A قرار DECIDES and binds somebody; a
/// تعميم TELLS and everybody is meant to know it (see [DecisionKind]). They
/// share a section and a shape, and a man asked to produce «قرارات الموسم» does
/// not mean the meal timetable — so the export can be asked for one and not the
/// other, exactly as the section itself distinguishes them.
///
/// The season one is a real narrowing here and is not the same as the reports
/// list's. `ReportsRepository.fetchReports(seasonId:)` returns a season's
/// documents AND the general ones, deliberately: a general decision is in force
/// during 1448 and hiding it from a man reading 1448 would hide something that
/// binds him. An EXPORT is a different act — «تابعين لموسم 1448» is what was
/// asked for — so the general ones are filtered back out here, and reached
/// through their own «عام» scope instead. A person who wants both takes «الكل».
///
/// What comes out for each is the document, not a line about it: its header
/// fields, its written content block by block, the table under it with its
/// columns expanded to this season's entries, and what was attached.
class DecisionExportDataset extends ExportRecordDataset {
  /// The scope that means "true in every season" — `reports.season_id is null`.
  ///
  /// A sentinel beside [ExportOption.anyId] rather than an empty answer,
  /// because «عام» is a POSITIVE choice: it is what the reports screen calls
  /// that shelf, and «الكل» already means the other thing.
  static const generalId = 'general';

  @override
  String get id => 'reports';

  @override
  // القرارات والتعميمات, not التقارير. The identifiers in this feature all say
  // `report` — see the note on the `Report` class for why they were left alone
  // — but what the reader is choosing to export is the mission's decisions and
  // its circulars, and the chip names both because the section holds both.
  LocalizedName get name =>
      _n('القرارات والتعميمات', 'Decisions and circulars');

  @override
  Set<String> get permissions => const {};

  /// None, and this is the one dataset where that is not a shortcut.
  ///
  /// A published قرار is PROSE in the order somebody wrote it — a heading, two
  /// paragraphs, a numbered list, a table typed inside it — and there is no
  /// column list to offer over that. What the operational files can do (see
  /// `module_export.dart`) rests on their blocks being tables of a known shape;
  /// a written document has no such shape, so it is printed whole.
  @override
  List<ExportColumn> get columns => const [];

  @override
  List<ExportOption> get options => [
    ExportOption(
      key: 'season',
      label: _n('الموسم', 'Season'),
      initial: ExportOption.anyId,
      choices: (_, _) async {
        final seasons = await SeasonsRepository().fetchSeasons();
        return [
          ExportChoice(id: ExportOption.anyId, label: _n('الكل', 'All')),
          ExportChoice(id: generalId, label: _n('عام', 'General')),
          for (final season in seasons)
            ExportChoice(
              id: season.id,
              label: LocalizedName(ar: '${season.hijriYear}هـ'),
            ),
        ];
      },
    ),
    ExportOption(
      key: 'kind',
      label: _n('نوع المستند', 'Kind of document'),
      initial: ExportOption.anyId,
      choices: (_, _) async => [
        ExportChoice(id: ExportOption.anyId, label: _n('الكل', 'All')),
        ExportChoice(
          id: DecisionKind.decision.dbName,
          label: _n('قرارات', 'Decisions'),
        ),
        ExportChoice(
          id: DecisionKind.circular.dbName,
          label: _n('تعميمات', 'Circulars'),
        ),
      ],
    ),
    ExportOption(
      key: 'report',
      label: _n('المستند', 'Document'),
      initial: ExportOption.anyId,
      // Offered from within the two above, which is the whole point of the
      // order: under 1448هـ and «تعميمات» the list is 1448's circulars, and
      // «الكل» beneath it means all of those rather than all of everything.
      choices: (chosen, _) async {
        final documents = await _fetchList(chosen['season'], chosen['kind']);
        return [
          ExportChoice(id: ExportOption.anyId, label: _n('الكل', 'All')),
          // A meal timetable is published without a number (see `Report.number`)
          // and there is one of them per meal, so two documents of one scope
          // can read alike.
          ...ExportChoice.distinct([
            for (final document in documents)
              ExportChoice(id: document.id, label: _title(document)),
          ]),
        ];
      },
    ),
  ];

  @override
  Future<List<ExportTable>> sections(ExportRequest request) async {
    final listed = await _fetchList(
      request.option('season'),
      request.option('kind'),
    );

    final wanted = request.narrowing('report');
    final chosen = wanted == null
        ? listed
        : listed.where((document) => document.id == wanted).toList();
    if (chosen.isEmpty) return const [];

    final repo = ReportsRepository();
    final types = await repo.fetchTypes();
    // The master-data lists, for the two things in a document that are stored
    // as ids: a reference cell's value, and the columns a table expands into.
    final sets = await ModulesRepository().fetchReferenceSets(activeOnly: false);

    final out = <ExportTable>[];
    for (final listedDocument in chosen) {
      // The list's projection carries neither `data` nor the blocks, the rows
      // or the attachments — see `ReportsRepository._listColumns`, which leaves
      // them out because a card never draws them. So each document is read
      // again in full. One round trip per document, which is the price of «الكل»
      // and the reason a single document is also a choice.
      final document = await repo.fetchReport(listedDocument.id) ?? listedDocument;
      final type = types
          .where((candidate) => candidate.id == document.reportTypeId)
          .firstOrNull;

      out
        ..add(_about(document, type, request))
        ..addAll(_content(document, sets, request))
        ..addAll(_table(document, type, sets, request))
        ..addAll(_attachments(document, request));
    }
    return out;
  }

  /// The documents of one scope and one act, newest first.
  static Future<List<Report>> _fetchList(String? scope, String? kind) async {
    final repo = ReportsRepository();
    final isSeason = scope != null &&
        scope.isNotEmpty &&
        scope != ExportOption.anyId &&
        scope != generalId;

    // Narrowed at the server where there is a season to narrow by — the query
    // still brings the general ones back with it, and they are dropped below.
    final documents = await repo.fetchReports(seasonId: isSeason ? scope : null);

    final inScope = scope == generalId
        ? [for (final d in documents) if (!d.isSeasonal) d]
        : isSeason
        ? [for (final d in documents) if (d.seasonId == scope) d]
        : documents;

    if (kind == null || kind.isEmpty || kind == ExportOption.anyId) {
      return inScope;
    }
    return [for (final d in inScope) if (d.kind.dbName == kind) d];
  }

  /// What the document says about itself.
  ExportTable _about(
    Report document,
    ReportType? type,
    ExportRequest request,
  ) {
    final l = request.l;

    final facts = ExportFacts()
      ..add(_label(request, 'العنوان', 'Title'), document.title)
      ..add(_label(request, 'العنوان الفرعي', 'Subtitle'), document.subtitle)
      ..add(_label(request, 'النوع', 'Kind'), _kindName(request, document.kind))
      ..addName(
        _label(request, 'النموذج', 'Form'),
        document.typeName ?? type?.name,
        request.languageCode,
      )
      ..addName(
        _label(request, 'عن هذا النموذج', 'About this form'),
        type?.description,
        request.languageCode,
      )
      ..add(_label(request, 'الرقم', 'Number'), document.number)
      // A general document is not "missing a season" — it is true in all of
      // them, and says so, exactly as the detail screen does.
      ..add(_label(request, 'النطاق', 'Scope'), _scopeName(request, document))
      ..add(
        _label(request, 'منشور', 'Published'),
        ExportValues.yesNo(l, document.isPublished),
      )
      ..add(
        _label(request, 'آخر تحديث', 'Last updated'),
        ExportValues.moment(document.updatedAt),
      )
      ..add(_label(request, 'المعرّف', 'Id'), document.id);

    // The header fields the form declares — what a document of this kind states
    // above its table.
    for (final field in type?.fields ?? const <ModuleField>[]) {
      facts.add(
        request.text(field.label),
        (document.data[field.key]?.toString() ?? ''),
      );
    }

    return facts.toTable(
      title: request.text(name),
      caption: request.text(_title(document)),
      opensRecord: true,
    );
  }

  /// A written document's content, block by block, in the order it was written.
  ///
  /// Two columns — what the line IS, and what it says — rather than one column
  /// of prose. A heading and the paragraph under it look identical once they
  /// are cells in a spreadsheet, and a document whose structure has been
  /// flattened away is a document somebody will quote the wrong line from.
  ///
  /// A table block is not a line and does not go in here: it becomes its own
  /// section, below.
  List<ExportTable> _content(
    Report document,
    List<ReferenceSet> sets,
    ExportRequest request,
  ) {
    if (!document.isWritten) return const [];

    final lines = <List<String>>[];
    final tables = <ExportTable>[];

    for (final block in document.blocks) {
      if (block.isEmpty) continue;
      switch (block.kind) {
        case ReportBlockKind.heading:
        case ReportBlockKind.subheading:
        case ReportBlockKind.paragraph:
        case ReportBlockKind.note:
          lines.add([_blockName(request, block.kind), block.text]);
        case ReportBlockKind.bullets:
        case ReportBlockKind.numbers:
          for (final item in block.items) {
            lines.add([_blockName(request, block.kind), item]);
          }
        case ReportBlockKind.url:
          lines.add([
            _blockName(request, block.kind),
            [block.label, block.url].where((s) => s.isNotEmpty).join(' — '),
          ]);
        case ReportBlockKind.qr:
          lines.add([
            _blockName(request, block.kind),
            [block.label, block.value].where((s) => s.isNotEmpty).join(' — '),
          ]);
        case ReportBlockKind.divider:
          break;
        case ReportBlockKind.table:
          tables.add(_blockTable(document, block, sets, request));
      }
    }

    return [
      if (lines.isNotEmpty)
        ExportTable(
          title: request.text(name),
          caption: _label(request, 'المحتوى', 'Content'),
          headers: [
            _label(request, 'النوع', 'Kind'),
            _label(request, 'النص', 'Text'),
          ],
          rows: lines,
        ),
      ...tables,
    ];
  }

  /// One table written inside a document.
  ///
  /// Its `expand` list becomes one column per entry of the master-data list it
  /// names, scoped to the DOCUMENT's season — the same resolution
  /// `ReportDetailState.expansionOf` makes, and it has to be the same or the
  /// exported sheet and the screen disagree about what the document says.
  ExportTable _blockTable(
    Report document,
    ReportBlock block,
    List<ReferenceSet> sets,
    ExportRequest request,
  ) {
    final set = sets
        .where((candidate) => candidate.code == block.expandSetCode)
        .firstOrNull;
    final expansion = set == null
        ? const <ReferenceItem>[]
        : set.itemsForSeason(document.seasonId);
    final columns = block.effectiveTableColumns(expansion);

    final text = TableText(
      // Across ALL of a set's entries, not this season's: a document written
      // last season still has to render.
      referenceName: (code, id) =>
          request.text(
            sets
                .where((candidate) => candidate.code == code)
                .firstOrNull
                ?.items
                .where((item) => item.id == id)
                .firstOrNull
                ?.name,
          ),
      timeRange: request.l.reportTimeRange,
      date: (iso) => ExportValues.date(DateTime.tryParse(iso)),
    );

    return ExportTable(
      title: request.text(name),
      caption: _label(request, 'جدول', 'Table'),
      headers: [for (final column in columns) column.label],
      rows: [
        for (final row in block.rows)
          [
            for (var i = 0; i < columns.length; i++)
              drawCell(columns[i], i < row.length ? row[i] : '', text),
          ],
      ],
    );
  }

  /// A typed document's content, which is its table.
  List<ExportTable> _table(
    Report document,
    ReportType? type,
    List<ReferenceSet> sets,
    ExportRequest request,
  ) {
    if (type == null || !type.hasTable || document.rows.isEmpty) {
      return const [];
    }

    // A declaration over a master-data list stands for one column per entry of
    // it, in the document's own season.
    final drawn = <({String key, String label, ReportColumn column})>[];
    for (final column in type.columns) {
      if (!column.isExpanded) {
        drawn.add((
          key: column.key,
          label: request.text(column.label),
          column: column,
        ));
        continue;
      }
      final set = sets
          .where((candidate) => candidate.id == column.sourceSetId)
          .firstOrNull;
      if (set == null) continue;
      for (final item in set.itemsForSeason(document.seasonId)) {
        drawn.add((
          key: item.id,
          label: request.text(item.name),
          column: column,
        ));
      }
    }
    if (drawn.isEmpty) return const [];

    // Resolved once, with a spanning column's blank cell filled from the row
    // above it: the date of all three meal documents is written once and read
    // down the page, and a sheet that carried the blank would read as three
    // documents of which two have no date.
    final carried = <String, String>{};
    final resolved = <Map<String, String>>[
      for (final row in document.rows)
        {
          for (final column in drawn)
            column.key: _typedCell(row, column, sets, carried, request),
        },
    ];

    // A column the season declared and this document never filled is dropped,
    // exactly as the detail screen drops it: توزيع الوجبات allots meals to the
    // thirteen تكتلات camped at المشاعر out of the season's twenty-five, and
    // twelve columns blank from top to bottom are twelve columns of nothing.
    // Only EXPANDED columns go — a declared column standing empty is the form
    // saying something, and stays.
    final columns = [
      for (final column in drawn)
        if (!column.column.isExpanded ||
            resolved.any((row) => (row[column.key] ?? '').isNotEmpty))
          column,
    ];
    if (columns.isEmpty) return const [];

    return [
      ExportTable(
        title: request.text(name),
        caption: _label(request, 'الجدول', 'Table'),
        headers: [for (final column in columns) column.label],
        rows: [
          for (final row in resolved)
            [for (final column in columns) row[column.key] ?? ''],
        ],
      ),
    ];
  }

  String _typedCell(
    ReportRow row,
    ({String key, String label, ReportColumn column}) column,
    List<ReferenceSet> sets,
    Map<String, String> carried,
    ExportRequest request,
  ) {
    var raw = row.value(column.key);
    if (column.column.isChoice && raw.isNotEmpty) {
      // A reference cell holds an id and the reader wants the name; a name
      // looked up in a set that no longer has it reads as blank rather than as
      // a uuid nobody can use.
      raw = request.text(
        sets
            .where((set) => set.id == column.column.referenceSetId)
            .firstOrNull
            ?.items
            .where((item) => item.id == raw)
            .firstOrNull
            ?.name,
      );
    }
    if (!column.column.spansRows) return raw;
    if (raw.isNotEmpty) {
      carried[column.key] = raw;
      return raw;
    }
    return carried[column.key] ?? '';
  }

  /// The papers a document was typed from.
  ///
  /// Their names and sizes, not the files themselves: this produces one sheet,
  /// and the bucket they live in is private — nothing in it is readable without
  /// a signed URL minted for one reader at one moment. Naming them is what lets
  /// somebody holding the export ask for them.
  List<ExportTable> _attachments(Report document, ExportRequest request) {
    if (document.attachments.isEmpty) return const [];
    return [
      ExportTable(
        title: request.text(name),
        caption: _label(request, 'المرفقات', 'Attachments'),
        headers: [
          _label(request, 'الاسم', 'Name'),
          _label(request, 'النوع', 'Kind'),
          _label(request, 'الحجم', 'Size'),
        ],
        rows: [
          for (final attachment in document.attachments)
            [
              attachment.name,
              attachment.kind.name,
              attachment.readableSize ?? '',
            ],
        ],
      ),
    ];
  }

  String _kindName(ExportRequest request, DecisionKind kind) =>
      switch (kind) {
        DecisionKind.decision => request.l.reportKindDecision,
        DecisionKind.circular => request.l.reportKindCircular,
      };

  String _scopeName(ExportRequest request, Report document) =>
      document.isSeasonal
      ? request.l.seasonHijriYear(document.seasonHijriYear ?? 0)
      : request.l.reportsScopeGeneral;

  String _blockName(ExportRequest request, ReportBlockKind kind) =>
      switch (kind) {
        ReportBlockKind.heading => _label(request, 'عنوان', 'Heading'),
        ReportBlockKind.subheading => _label(request, 'عنوان فرعي', 'Subheading'),
        ReportBlockKind.paragraph => _label(request, 'فقرة', 'Paragraph'),
        ReportBlockKind.note => _label(request, 'ملاحظة', 'Note'),
        ReportBlockKind.bullets => _label(request, 'نقطة', 'Bullet'),
        ReportBlockKind.numbers => _label(request, 'بند', 'Item'),
        ReportBlockKind.url => _label(request, 'رابط', 'Link'),
        ReportBlockKind.qr => _label(request, 'رمز', 'Code'),
        ReportBlockKind.table => _label(request, 'جدول', 'Table'),
        ReportBlockKind.divider => '',
      };

  /// «3190 — تشكيل لجنة الطوافة». What a document is called when it has to be
  /// named among others: its number, where it has one, and its title.
  static LocalizedName _title(Report document) {
    final number = document.number ?? '';
    return LocalizedName(
      ar: [
        number,
        document.title,
      ].where((part) => part.isNotEmpty).join(' — '),
    );
  }
}
