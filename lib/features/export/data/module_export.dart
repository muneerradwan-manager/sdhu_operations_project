import '../../../core/l10n/localized_name.dart';
import '../../modules/data/modules_repository.dart';
import '../../modules/domain/module_task.dart';
import '../../modules/domain/module_type.dart';
import '../../modules/domain/operational_module.dart';
import '../../modules/domain/reference_item.dart';
import '../../modules/presentation/widgets/cadence_label.dart';
import '../../seasons/data/seasons_repository.dart';
import '../domain/export_dataset.dart';
import 'export_sections.dart';
import 'export_values.dart';

LocalizedName _n(String ar, String en) => LocalizedName(ar: ar, en: en);

/// A heading in the reader's language. The labels of a record export are the
/// app's own words rather than content out of a row, so they are written here
/// in both languages exactly as the column labels in `export_catalog.dart` are.
String _label(ExportRequest request, String ar, String en) =>
    request.text(_n(ar, en));

/// One cell of the roster, named by the column it belongs to.
typedef _MemberCell = String Function(_Post post);

/// The operational files, each handed over WHOLE.
///
/// This replaces three datasets — الملفات التشغيلية, أعضاء ملف تشغيلي and مهام
/// ملف تشغيلي — and the merge was asked for in as many words: «لا أريد الملفات
/// التشغيلية وأعضاء ملف تشغيلي ومهام ملف تشغيلي، وإنما فقط الملفات التشغيلية».
///
/// The three were a bad division, and it is worth saying why, because the shape
/// looked reasonable. Each exported one TABLE, so a person who wanted "the
/// الطوافة والنقل file" ran three exports, answered the same question three
/// times, and ended holding three files that nothing but his memory joined —
/// and the first of them, the one actually called «الملفات التشغيلية», gave him
/// a LINE about each file and none of its contents. Nobody wants a line about a
/// file. They want the file.
///
/// So there is one dataset, it is asked which file — or all of them — and what
/// comes back is the file: what it is and when it runs, the values of the fields
/// its type declares, everyone posted anywhere in it and where they stand, its
/// sectors and towers with their own fields, and the duties written on it.
///
/// **And it still offers columns**, unlike the decisions beside it. A file's
/// blocks are tables of a KNOWN SHAPE — a roster is a roster whichever file it
/// belongs to — so the ordinary question «which of these do you want» has an
/// answer here, and a man who needs a call sheet should be able to ask for the
/// names, the posts and the telephones without carrying eight columns he will
/// delete in Excel afterwards, which is where files get quietly wrong. A
/// published قرار has no such shape, which is why THAT one is printed whole.
///
/// The keys are namespaced by BLOCK — `file_`, `member_`, `node_`, `task_` —
/// and a block whose every column is unticked is not written, and its query is
/// not sent. So the checklist doubles as the choice of which parts of the file
/// to take, without a second control saying the same thing twice.
class ModuleExportDataset extends ExportRecordDataset {
  @override
  String get id => 'modules';

  @override
  LocalizedName get name => _n('الملفات التشغيلية', 'Operational files');

  /// None. Row security decides this one: a manager exports every file of the
  /// season and a member exports the files he is posted in, and each is exactly
  /// what his own screen shows him.
  @override
  Set<String> get permissions => const {};

  @override
  List<ExportColumn> get columns => [
    for (final fact in _facts) fact.column,
    _fileFields,
    for (final member in _members) member.column,
    ..._nodeColumns,
    for (final duty in _duties) duty.column,
  ];

  @override
  List<ExportOption> get options => [
    ExportOption(
      key: 'season',
      label: _n('الموسم', 'Season'),
      initial: ExportOption.anyId,
      choices: (_, _) async {
        final seasons = await SeasonsRepository().fetchSeasons();
        return [
          ExportChoice(
            id: ExportOption.anyId,
            label: _n('كل المواسم', 'All seasons'),
          ),
          for (final season in seasons)
            ExportChoice(
              id: season.id,
              label: LocalizedName(ar: '${season.hijriYear}هـ'),
            ),
        ];
      },
    ),
    ExportOption(
      key: 'module',
      label: _n('الملف التشغيلي', 'Operational file'),
      initial: ExportOption.anyId,
      // Narrowed by the season above it: offering every season's files under a
      // chosen season offers an answer that contradicts the question.
      choices: (chosen, _) async {
        final season = chosen['season'];
        final modules = await ModulesRepository().fetchModules(
          seasonId: (season == null || season == ExportOption.anyId)
              ? null
              : season,
        );
        return [
          ExportChoice(id: ExportOption.anyId, label: _n('الكل', 'All')),
          // A file of a kind exists at most once in a season, so its type and
          // its season already name it uniquely. Broken anyway, cheaply, so
          // that the rule holds everywhere rather than resting on an invariant
          // this picker cannot see.
          ...ExportChoice.distinct([
            for (final module in modules)
              ExportChoice(id: module.id, label: moduleTitle(module)),
          ]),
        ];
      },
    ),
  ];

  @override
  Future<List<ExportTable>> sections(ExportRequest request) async {
    final repo = ModulesRepository();
    final modules = await repo.fetchModules(
      seasonId: request.narrowing('season'),
    );

    final wanted = request.narrowing('module');
    final chosen = wanted == null
        ? modules
        : modules.where((module) => module.id == wanted).toList();
    if (chosen.isEmpty) return const [];

    // Both catalogues once, for however many files are written. The type is
    // what names a file's fields, its levels and its posts; the sets are what
    // turn the ids stored against them into hotels and clusters.
    //
    // `activeOnly: false` on both. A file of a retired type, or a tower
    // pointing at a hotel since taken off the list, still has to render — an
    // export that silently dropped its own columns would be the omission this
    // dataset exists to prevent.
    final types = await repo.fetchModuleTypes(activeOnly: false);
    final sets = await repo.fetchReferenceSets(activeOnly: false);

    // What was not asked for is not FETCHED either. A person taking the roster
    // of a whole season's files should not wait on a query per file for the
    // duty lists he unticked.
    final wantsPeople = _members.any((c) => request.wants(c.column.key));
    final wantsTree = _nodeColumns.any((c) => request.wants(c.key));
    final wantsDuties = _duties.any((c) => request.wants(c.column.key));

    final out = <ExportTable>[];
    for (final module in chosen) {
      final type = types
          .where((candidate) => candidate.id == module.moduleTypeId)
          .firstOrNull;

      // Up to three round trips per file. Deliberate, and the reason «الكل» is
      // a choice rather than the only behaviour: a season is ten or so files,
      // which is a few seconds, and no shape of this reads a file's tree
      // without asking for it.
      //
      // The roster needs the tree as well as the members — a man may hold a
      // post at a tower and none on the file itself — so the nodes are fetched
      // when EITHER block is wanted, and fetched once.
      final nodes = (wantsPeople || wantsTree)
          ? await repo.fetchNodes(module.id)
          : const <ModuleNode>[];
      final members = wantsPeople
          ? await repo.fetchMembers(module.id)
          : const <ModuleMember>[];
      final tasks = wantsDuties
          ? await repo.fetchModuleTasks(module.id)
          : ModuleTaskList.empty;

      out
        ..add(_about(module, type, sets, request))
        ..addAll(_people(type, nodes, members, sets, request))
        ..addAll(_tree(type, nodes, sets, request))
        ..addAll(_dutyBlock(type, tasks, request));
    }
    return out;
  }

  // ------------------------------------------------------------- what it is

  /// The facts a file has ONE of, each its own column.
  static final List<({ExportColumn column, String Function(_Facts f) value})>
  _facts = [
    (
      column: ExportColumn(
        key: 'file_type',
        label: _n('نوع الملف', 'File type'),
      ),
      value: (f) => f.request.text(f.module.moduleTypeName ?? f.type?.name),
    ),
    (
      column: ExportColumn(key: 'file_season', label: _n('الموسم', 'Season')),
      value: (f) => f.module.seasonHijriYear?.toString() ?? '',
    ),
    (
      column: ExportColumn(
        key: 'file_decision_number',
        label: _n('رقم القرار', 'Decision number'),
      ),
      value: (f) => ExportValues.text(f.module.decisionNumber),
    ),
    (
      column: ExportColumn(
        key: 'file_starts_on',
        label: _n('تاريخ البدء', 'Starts on'),
      ),
      value: (f) => ExportValues.date(f.module.startsOn),
    ),
    (
      column: ExportColumn(
        key: 'file_ends_on',
        label: _n('تاريخ الانتهاء', 'Ends on'),
      ),
      value: (f) => ExportValues.date(f.module.endsOn),
    ),
    (
      column: ExportColumn(
        key: 'file_is_active',
        label: _n('مُفعَّل', 'Active'),
      ),
      value: (f) => ExportValues.yesNo(f.request.l, f.module.isActive),
    ),
    (
      column: ExportColumn(
        key: 'file_is_running',
        label: _n('قائم', 'Running'),
        byDefault: false,
      ),
      value: (f) => ExportValues.yesNo(f.request.l, f.module.isRunning),
    ),
    (
      column: ExportColumn(
        key: 'file_cadence',
        label: _n('دورية التقرير', 'Report cadence'),
        byDefault: false,
      ),
      value: (f) => cadenceName(f.request.l, f.module.reportCadence),
    ),
    (
      column: ExportColumn(
        key: 'file_about',
        label: _n('عن نوع الملف', 'About the type'),
        byDefault: false,
      ),
      value: (f) => f.request.text(f.type?.description),
    ),
    (
      column: ExportColumn(
        key: 'file_start_condition',
        label: _n('شرط البدء', 'Start condition'),
        byDefault: false,
      ),
      value: (f) => f.request.text(f.type?.startCondition),
    ),
    (
      column: ExportColumn(
        key: 'file_start_note',
        label: _n('ملاحظة بداية العمل', 'Start note'),
        byDefault: false,
      ),
      value: (f) => ExportValues.text(f.module.startNote),
    ),
    (
      column: ExportColumn(
        key: 'file_end_condition',
        label: _n('شرط الانتهاء', 'End condition'),
        byDefault: false,
      ),
      value: (f) =>
          f.request.text(f.module.endCondition ?? f.type?.endCondition),
    ),
    (
      column: ExportColumn(
        key: 'file_end_note',
        label: _n('ملاحظة نهاية العمل', 'End note'),
        byDefault: false,
      ),
      value: (f) => ExportValues.text(f.module.endNote),
    ),
    (
      column: ExportColumn(
        key: 'file_created_at',
        label: _n('تاريخ الإنشاء', 'Created at'),
        byDefault: false,
      ),
      value: (f) => ExportValues.moment(f.module.createdAt),
    ),
    (
      column: ExportColumn(
        key: 'file_id',
        label: _n('المعرّف', 'Id'),
        byDefault: false,
      ),
      value: (f) => f.module.id,
    ),
  ];

  /// The values of the fields the file's TYPE declares — الشعار, مقر البعثة,
  /// القرار المصدَّق — as one tick rather than one each.
  ///
  /// One tick because these are not a fixed list: every type declares its own,
  /// so a checklist built from the union of all of them would offer المطار
  /// beside الشعار for a file that has neither, and would change under the
  /// reader's hand every time he changed the season. What is stable — and what
  /// he is actually deciding — is whether the file's own fields go in.
  static final _fileFields = ExportColumn(
    key: 'file_fields',
    label: _n('حقول نوع الملف', "The type's own fields"),
  );

  /// What the file IS — the block that opens each record.
  ExportTable _about(
    OperationalModule module,
    ModuleType? type,
    List<ReferenceSet> sets,
    ExportRequest request,
  ) {
    final facts = ExportFacts();
    final source = _Facts(module: module, type: type, request: request);

    for (final fact in _facts) {
      if (!request.wants(fact.column.key)) continue;
      facts.add(request.text(fact.column.label), fact.value(source));
    }

    if (request.wants(_fileFields.key)) {
      for (final field in type?.fields ?? const <ModuleField>[]) {
        facts.add(
          request.text(field.label),
          exportFieldValue(
            field,
            module.data[field.key],
            sets: sets,
            languageCode: request.languageCode,
          ),
        );
      }
    }

    return facts.toTable(
      title: request.text(name),
      caption: request.text(moduleTitle(module)),
      opensRecord: true,
    );
  }

  // ------------------------------------------------------------ who is in it

  static final List<({ExportColumn column, _MemberCell cell})> _members = [
    (
      column: ExportColumn(key: 'member_name', label: _n('الاسم', 'Name')),
      cell: (post) => post.member.profile?.fullName ?? '',
    ),
    (
      column: ExportColumn(key: 'member_role', label: _n('الدور', 'Role')),
      cell: (post) => post.role,
    ),
    (
      column: ExportColumn(key: 'member_place', label: _n('المكان', 'Place')),
      cell: (post) => post.place,
    ),
    (
      // The hotel he sleeps in. Empty on a برج post, and deliberately: there
      // the مكان column already says it, and a roster repeating one hotel in
      // two columns invites the reader to look for the difference (0139).
      column: ExportColumn(key: 'member_housing', label: _n('السكن', 'Housing')),
      cell: (post) => post.housing,
    ),
    (
      column: ExportColumn(
        key: 'member_job_title',
        label: _n('المهنة', 'Job title'),
      ),
      cell: (post) => post.request.text(post.member.profile?.jobTitleName),
    ),
    (
      column: ExportColumn(
        key: 'member_phone_sa',
        label: _n('الهاتف (السعودية)', 'Phone (SA)'),
      ),
      cell: (post) => ExportValues.text(post.member.profile?.phoneSa),
    ),
    (
      column: ExportColumn(
        key: 'member_phone_sy',
        label: _n('الهاتف (سوريا)', 'Phone (SY)'),
        byDefault: false,
      ),
      cell: (post) => ExportValues.text(post.member.profile?.phoneSy),
    ),
    (
      column: ExportColumn(
        key: 'member_email',
        label: _n('البريد الإلكتروني', 'Email'),
        byDefault: false,
      ),
      cell: (post) => ExportValues.text(post.member.profile?.email),
    ),
    (
      column: ExportColumn(
        key: 'member_id',
        label: _n('معرّف الموظف', 'Employee id'),
        byDefault: false,
      ),
      cell: (post) => post.member.profileId,
    ),
  ];

  /// Everyone posted anywhere in the file, and where.
  ///
  /// The file's own posts and the posts held at a tower in ONE block, in that
  /// order. They were two questions in the retired `module_members` dataset,
  /// whose own note said that either alone is a roster of half the file — and
  /// which then joined them without saying which was which. The place column
  /// says which.
  List<ExportTable> _people(
    ModuleType? type,
    List<ModuleNode> nodes,
    List<ModuleMember> members,
    List<ReferenceSet> sets,
    ExportRequest request,
  ) {
    final wanted = [
      for (final column in _members)
        if (request.wants(column.column.key)) column,
    ];
    if (wanted.isEmpty) return const [];

    String roleName(String roleId) => request.text(type?.roleById(roleId)?.name);

    String placeName(ModuleNode node) {
      final level = type?.levelById(node.levelId);
      return [
        request.text(level?.name),
        _nodeName(node, level, sets, request),
      ].where((part) => part.isNotEmpty).join(': ');
    }

    // Resolved against every season's entries, not this file's: a قطاع
    // supervisor housed last season still has to export his hotel's name.
    final hotels = {
      for (final set in sets)
        if (set.code == ReferenceSet.hotelsCode)
          for (final item in set.items) item.id: item.name,
    };

    List<String> row(ModuleMember member, String place) {
      final post = _Post(
        member: member,
        role: roleName(member.roleId),
        place: place,
        housing: request.text(hotels[member.housingItemId]),
        request: request,
      );
      return [for (final column in wanted) column.cell(post)];
    }

    final rows = <List<String>>[
      for (final member in members) row(member, ''),
      for (final node in nodes)
        for (final member in node.members) row(member, placeName(node)),
    ];

    if (rows.isEmpty) return const [];

    return [
      ExportTable(
        title: request.text(name),
        caption: _label(request, 'الأعضاء', 'Members'),
        headers: [
          for (final column in wanted) request.text(column.column.label),
        ],
        rows: rows,
      ),
    ];
  }

  // ------------------------------------------------------------- where it is

  /// The tree's columns.
  ///
  /// `node_linked` and `node_fields` are named generically because what they
  /// hold is named by the LEVEL: the تكتل a برج falls under, the طاقة
  /// استيعابية a مخيم carries. The heading PRINTED is the level's own word;
  /// only the tick is generic, for the same reason [_fileFields] is one tick.
  static final List<ExportColumn> _nodeColumns = [
    ExportColumn(key: 'node_name', label: _n('اسم الموقع', 'Place name')),
    ExportColumn(key: 'node_parent', label: _n('ضمن', 'Inside')),
    ExportColumn(key: 'node_linked', label: _n('الارتباط', 'Linked to')),
    ExportColumn(
      key: 'node_fields',
      label: _n('حقول المستوى', "The level's fields"),
    ),
  ];

  /// The file's tree — one block per level rather than one for all of them.
  ///
  /// A قطاع and a برج carry different fields: the tower has a طاقة استيعابية and
  /// a تكتل it falls under, the sector has neither. Laid out as one table their
  /// columns are the union of both, and every sector row carries four empty
  /// cells that a reader has to work out are not missing data.
  List<ExportTable> _tree(
    ModuleType? type,
    List<ModuleNode> nodes,
    List<ReferenceSet> sets,
    ExportRequest request,
  ) {
    if (type == null || nodes.isEmpty) return const [];
    if (!_nodeColumns.any((column) => request.wants(column.key))) {
      return const [];
    }

    final wantsName = request.wants('node_name');
    final wantsParent = request.wants('node_parent');
    final wantsLinked = request.wants('node_linked');
    final wantsFields = request.wants('node_fields');

    final out = <ExportTable>[];
    for (final level in type.levels) {
      final here = nodes.where((node) => node.levelId == level.id).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (here.isEmpty) continue;

      final parentLevel = wantsParent
          ? type.levels
                .where((candidate) => candidate.depth == level.depth - 1)
                .firstOrNull
          : null;
      final secondary = wantsLinked
          ? sets
                .where((set) => set.id == level.secondaryReferenceSetId)
                .firstOrNull
          : null;
      final fields = wantsFields ? level.fields : const <ModuleField>[];

      out.add(
        ExportTable(
          title: request.text(name),
          caption: request.text(level.name),
          headers: [
            if (wantsName) _label(request, 'الاسم', 'Name'),
            if (parentLevel != null) request.text(parentLevel.name),
            if (secondary != null) request.text(secondary.name),
            for (final field in fields) request.text(field.label),
          ],
          rows: [
            for (final node in here)
              [
                if (wantsName) _nodeName(node, level, sets, request),
                if (parentLevel != null)
                  _nodeName(
                    nodes
                        .where((candidate) => candidate.id == node.parentId)
                        .firstOrNull,
                    parentLevel,
                    sets,
                    request,
                  ),
                if (secondary != null)
                  request.text(
                    secondary.items
                        .where(
                          (item) => item.id == node.secondaryReferenceItemId,
                        )
                        .firstOrNull
                        ?.name,
                  ),
                for (final field in fields)
                  exportFieldValue(
                    field,
                    node.data[field.key],
                    sets: sets,
                    languageCode: request.languageCode,
                  ),
              ],
          ],
        ),
      );
    }
    return out;
  }

  // ----------------------------------------------------------- what it owes

  static final List<({ExportColumn column, String Function(_Duty d) value})>
  _duties = [
    (
      column: ExportColumn(key: 'task_scope', label: _n('النطاق', 'Scope')),
      value: (d) => switch (d.task.scope) {
        TaskScope.file => d.request.l.moduleTaskScopeFile,
        TaskScope.role => d.request.l.moduleTaskScopeRole,
      },
    ),
    (
      column: ExportColumn(key: 'task_role', label: _n('الجهة', 'Owed by')),
      value: (d) => d.task.roleId == null
          ? ''
          : d.request.text(d.type?.roleById(d.task.roleId!)?.name),
    ),
    (
      column: ExportColumn(key: 'task_title', label: _n('المهمة', 'Duty')),
      value: (d) => d.request.text(d.task.title),
    ),
    (
      column: ExportColumn(
        key: 'task_description',
        label: _n('الوصف', 'Description'),
      ),
      value: (d) => d.request.text(d.task.description),
    ),
    (
      column: ExportColumn(
        key: 'task_due_on',
        label: _n('تاريخ الاستحقاق', 'Due on'),
      ),
      value: (d) => ExportValues.date(d.task.dueOn),
    ),
  ];

  /// The duties written on the file (0105): a description of the work, with no
  /// state and nobody's name on it.
  List<ExportTable> _dutyBlock(
    ModuleType? type,
    ModuleTaskList list,
    ExportRequest request,
  ) {
    if (list.isEmpty) return const [];
    final wanted = [
      for (final column in _duties)
        if (request.wants(column.column.key)) column,
    ];
    if (wanted.isEmpty) return const [];

    return [
      ExportTable(
        title: request.text(name),
        caption: _label(request, 'المهام', 'Duties'),
        headers: [
          for (final column in wanted) request.text(column.column.label),
        ],
        rows: [
          for (final task in list.tasks)
            [
              for (final column in wanted)
                column.value(_Duty(task: task, type: type, request: request)),
            ],
        ],
      ),
    ];
  }

  /// What a node is called: the entry it IS, or the name it was given.
  ///
  /// Looked up across ALL of the set's entries rather than the season's, for
  /// the reason `reference_item.dart` states: last season's tower points at
  /// last season's hotel and still has to render.
  static String _nodeName(
    ModuleNode? node,
    ModuleLevel? level,
    List<ReferenceSet> sets,
    ExportRequest request,
  ) {
    if (node == null) return '';
    final set = sets
        .where((candidate) => candidate.id == level?.referenceSetId)
        .firstOrNull;
    final item = set?.items
        .where((candidate) => candidate.id == node.referenceItemId)
        .firstOrNull;
    final named = request.text(item?.name);
    return named.isNotEmpty ? named : (node.label ?? '');
  }

  /// «الطوافة والنقل — 1448هـ».
  ///
  /// What a file is called when it has to be named among others. A file carries
  /// no title of its own — it is created once per season and its type names it
  /// — so its type and its season together are its name.
  static LocalizedName moduleTitle(OperationalModule module) {
    final year = module.seasonHijriYear;
    String join(String kind, String season) =>
        [kind, season].where((part) => part.isNotEmpty).join(' — ');
    return LocalizedName(
      ar: join(module.moduleTypeName?.ar ?? '', year == null ? '' : '$yearهـ'),
      en: join(
        module.moduleTypeName?.en ?? module.moduleTypeName?.ar ?? '',
        year == null ? '' : '$year AH',
      ),
    );
  }
}

/// What a fact column is computed from.
class _Facts {
  const _Facts({
    required this.module,
    required this.type,
    required this.request,
  });

  final OperationalModule module;
  final ModuleType? type;
  final ExportRequest request;
}

/// One person's posting, which is what a roster column is computed from.
class _Post {
  const _Post({
    required this.member,
    required this.role,
    required this.place,
    required this.housing,
    required this.request,
  });

  final ModuleMember member;
  final String role;

  /// Where in the file — «البرج/الفندق: فندق الصفوة». Empty for a post held on
  /// the file itself, where the file IS the place.
  final String place;

  /// The hotel he sleeps in, where the post is somewhere he cannot be housed by
  /// standing — a قطاع (0139). Empty everywhere else.
  final String housing;

  final ExportRequest request;
}

/// …and what a duty column is.
class _Duty {
  const _Duty({required this.task, required this.type, required this.request});

  final ModuleTask task;
  final ModuleType? type;
  final ExportRequest request;
}
