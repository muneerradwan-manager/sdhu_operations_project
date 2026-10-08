import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/localized_name.dart';
import '../../complaints/data/complaints_repository.dart';
import '../../complaints/domain/complaint.dart';
import '../../complaints/presentation/widgets/complaint_labels.dart';
import '../../employees/data/employees_repository.dart';
import '../../evaluations/data/evaluations_repository.dart';
import '../../evaluations/domain/evaluation.dart';
import '../../evaluations/presentation/widgets/evaluation_labels.dart';
import '../../modules/data/modules_repository.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/profile_enums.dart';
import '../../seasons/data/seasons_repository.dart';
import '../domain/export_dataset.dart';
import 'decision_export.dart';
import 'export_values.dart';
import 'module_export.dart';

LocalizedName _n(String ar, String en) => LocalizedName(ar: ar, en: en);

/// Every kind of thing this app can hand over as a file.
///
/// One catalogue rather than an export button per screen, and the difference is
/// not tidiness. A button on a screen exports WHAT THAT SCREEN HAPPENS TO BE
/// SHOWING — the filter someone left on, the hundred rows that had loaded — and
/// the person receiving the file cannot tell which of those it was. A dataset
/// says what it fetches, is asked for its rows directly, and can be read.
///
/// Every fetch goes through the same repository the screen uses, so row
/// security narrows an export exactly as it narrows a page. That used to mean
/// this screen could not widen anything at all.
///
/// **It can now.** 0100 made `export.data` a senior read: the row policies
/// themselves accept it, so a holder exports the employees whether or not he
/// may open the employees screen. The widening had to happen there rather than
/// here — offering a dataset the reader's policies refuse produces an EMPTY
/// FILE and no error, and an empty export is worse than a refusal because he
/// carries it away believing it is the data.
///
/// Two things it still does not open: the complaints and the evaluations filed
/// about the holder HIMSELF. 0079 and 0084 fence a manager off his own case so
/// that a read permission cannot become the way to find out who accused you,
/// and 0100 widens the helper INSIDE that fence rather than around it.
///
/// **Two kinds of dataset live here.** Most are tables — a row per thing, and
/// the person picks which of its columns he wants, which is what this screen
/// was built around. Two are [ExportRecordDataset]s: the operational files and
/// the decisions hand over WHOLE RECORDS rather than a line about one. They are
/// written out in `module_export.dart` and `decision_export.dart`, which is
/// also where the case for the difference is made — including why the files
/// still offer columns and the decisions cannot.
///
/// **And every one of them asks the same shape of question**, in the same
/// order: the SEASON first, because it is the widest, then what within it, then
/// which one in particular — «الكل» or one by name. A person who has run one
/// export has run them all.
abstract final class ExportCatalog {
  static final List<ExportDataset> all = [
    _PeopleDataset(),
    ModuleExportDataset(),
    _ReferenceItemsDataset(),
    DecisionExportDataset(),
    _ComplaintsDataset(),
    _EvaluationsDataset(),
  ];

  /// What this reader may be offered.
  ///
  /// `export.data` offers everything, and that is the point of it (0100).
  /// Whoever may take data out may take any of it — so the per-dataset
  /// permissions below decide nothing for a holder, and the row policies were
  /// widened to match. Without that widening this list would be a lie: the
  /// employees would be offered and the file would come back empty, because
  /// `profiles_select` would return him nothing and no error would be raised.
  ///
  /// The per-dataset check is kept for the admin case and for a future grant
  /// that is narrower than this one. Nothing today reaches it except an admin,
  /// who passes the first clause anyway.
  ///
  /// ANY of a dataset's codes opens it, not all of them: «الموظفون والمشاركون»
  /// is a merge of two things that two grants opened separately, and a reader
  /// holding either should meet the chip — and then be offered only the half he
  /// holds. See [ExportViewer].
  static List<ExportDataset> visibleTo({
    required bool isAdmin,
    required Set<String> permissions,
  }) => [
    for (final dataset in all)
      if (isAdmin ||
          permissions.contains(PermissionCodes.exportData) ||
          dataset.permissions.isEmpty ||
          dataset.permissions.any(permissions.contains))
        dataset,
  ];

  static ExportDataset? byId(String id) {
    for (final dataset in all) {
      if (dataset.id == id) return dataset;
    }
    return null;
  }
}

// ---------------------------------------------------------------- the people

/// The columns a person has, shared by the two datasets that list people.
///
/// Written once because they must not drift: an export of the permanent staff
/// and an export of a season's participants that disagree about what "المهنة"
/// means are two files nobody can put side by side.
List<ExportColumn> _profileColumns() => [
  ExportColumn(key: 'full_name', label: _n('الاسم الكامل', 'Full name')),
  ExportColumn(key: 'first_name', label: _n('الاسم', 'First name'), byDefault: false),
  ExportColumn(key: 'father_name', label: _n('اسم الأب', 'Father name'), byDefault: false),
  ExportColumn(key: 'surname', label: _n('الكنية', 'Surname'), byDefault: false),
  ExportColumn(key: 'job_title', label: _n('المهنة', 'Job title')),
  ExportColumn(key: 'mission_type', label: _n('نوع البعثة', 'Mission type')),
  ExportColumn(key: 'email', label: _n('البريد الإلكتروني', 'Email')),
  ExportColumn(key: 'phone_sy', label: _n('الهاتف (سوريا)', 'Phone (SY)')),
  ExportColumn(key: 'phone_sa', label: _n('الهاتف (السعودية)', 'Phone (SA)')),
  ExportColumn(key: 'city', label: _n('المدينة', 'City'), byDefault: false),
  ExportColumn(key: 'gender', label: _n('الجنس', 'Gender'), byDefault: false),
  ExportColumn(key: 'date_of_birth', label: _n('تاريخ الميلاد', 'Date of birth'), byDefault: false),
  ExportColumn(key: 'is_external', label: _n('خارجي', 'External'), byDefault: false),
  ExportColumn(key: 'external_organization', label: _n('الجهة', 'Organization'), byDefault: false),
  ExportColumn(key: 'account_status', label: _n('حالة الحساب', 'Account status'), byDefault: false),
  ExportColumn(key: 'is_suspended', label: _n('موقوف', 'Suspended'), byDefault: false),
  // Marked sensitive, and it is the only column in the app that is. On the
  // screen it is a row nobody reads; in a sheet on somebody else's desk it is
  // the key that joins this man to every other table he appears in. The screen
  // says so once and lets him take it — see [ExportColumn.isSensitive].
  ExportColumn(
    key: 'id',
    label: _n('المعرّف', 'Id'),
    byDefault: false,
    isSensitive: true,
  ),
];

Map<String, String> _profileRow(Profile profile, ExportRequest request) {
  final l = request.l;
  return {
    'full_name': profile.fullName,
    'first_name': ExportValues.text(profile.firstName),
    'father_name': ExportValues.text(profile.fatherName),
    'surname': ExportValues.text(profile.surname),
    'job_title': request.text(profile.jobTitleName),
    'mission_type': request.text(profile.missionTypeName),
    'email': ExportValues.text(profile.email),
    'phone_sy': ExportValues.text(profile.phoneSy),
    'phone_sa': ExportValues.text(profile.phoneSa),
    'city': request.text(profile.cityName),
    'gender': switch (profile.gender) {
      Gender.male => l.genderMale,
      Gender.female => l.genderFemale,
      null => '',
    },
    'date_of_birth': ExportValues.date(profile.dateOfBirth),
    'is_external': ExportValues.yesNo(l, profile.isExternal),
    'external_organization': ExportValues.text(profile.externalOrganization),
    'account_status': switch (profile.accountStatus) {
      AccountStatus.incomplete => l.accountStatusIncomplete,
      AccountStatus.pending => l.accountStatusPending,
      AccountStatus.approved => l.accountStatusApproved,
      AccountStatus.rejected => l.accountStatusRejected,
    },
    'is_suspended': ExportValues.yesNo(l, profile.isSuspended),
    'id': profile.id,
  };
}

/// The people of the mission — the permanent staff, this season's
/// participants, the externals — under one chip.
///
/// These were two datasets, «الموظفون» and «مشاركو الموسم», and the split was a
/// distinction the person exporting does not have. He is after a list of
/// PEOPLE, with their trades and their telephones, and «مشاركو الموسم» is not a
/// different kind of thing from «الملاك الدائم» — it is the same thing asked of
/// a season. Two chips carrying identical columns and near-identical questions
/// made him choose between them before he was told what the difference was, and
/// there was no answer on either chip that spanned both.
///
/// So it is one chip and the difference is an ANSWER: the season first, because
/// it is the wider question, then who within it. The columns are what they
/// always were, shared by every answer, which is what makes them comparable —
/// two sheets of people that disagree about what «المهنة» means are two sheets
/// nobody can put side by side.
///
/// **The two grants survive the merge.** They open different halves and always
/// did, so the chip appears for whoever holds EITHER, and «من يُصدَّر» offers
/// only the halves this reader may actually read — see [ExportViewer]. Offering
/// him the rest would hand him an empty file and no error.
class _PeopleDataset extends ExportDataset {
  @override
  String get id => 'people';

  @override
  LocalizedName get name =>
      _n('الموظفون والمشاركون', 'Employees and participants');

  @override
  Set<String> get permissions => {
    PermissionCodes.employeesView,
    PermissionCodes.seasonsParticipantsView,
  };

  @override
  List<ExportColumn> get columns => _profileColumns();

  @override
  List<ExportOption> get options => [
    _seasonOption(),
    ExportOption(
      key: 'kind',
      label: _n('من يُصدَّر', 'Who'),
      initial: 'permanent',
      choices: (chosen, viewer) async {
        final season = chosen['season'];
        final hasSeason = season != null && season != ExportOption.anyId;
        return [
          if (viewer.can(PermissionCodes.employeesView)) ...[
            ExportChoice(
              id: 'permanent',
              label: _n('الملاك الدائم', 'Permanent staff'),
            ),
            ExportChoice(id: 'external', label: _n('الخارجيون', 'External')),
            ExportChoice(id: 'both', label: _n('الملاك والخارجيون', 'Staff and external')),
          ],
          // Only under a season, because it is not a question otherwise:
          // participation IS in a season, and `fetchParticipants` has no shape
          // that spans all of them. Offering it under «كل المواسم» would be
          // offering a question with no answer.
          if (hasSeason && viewer.can(PermissionCodes.seasonsParticipantsView))
            ExportChoice(
              id: 'participants',
              label: _n('مشاركو الموسم', "The season's participants"),
            ),
        ];
      },
    ),
    ExportOption(
      key: 'person',
      label: _n('الشخص', 'Person'),
      initial: ExportOption.anyId,
      // Narrowed by the two above it, so that the names offered are the names
      // the file would contain. A picker listing the whole directory under a
      // question already narrowed to one season's externals would offer people
      // the export cannot return.
      choices: (chosen, viewer) async {
        final people = await _people(
          kind: chosen['kind'] ?? 'permanent',
          seasonId: _narrow(chosen['season']),
        );
        return [
          ExportChoice(id: ExportOption.anyId, label: _n('الكل', 'All')),
          // Two men sharing a name is not an edge case in a mission of four
          // hundred, so the trade goes on the line and the id breaks whatever
          // that does not.
          ...ExportChoice.distinct([
            for (final person in people)
              ExportChoice(
                id: person.id,
                label: LocalizedName(
                  ar: [
                    person.fullName,
                    person.jobTitleName?.ar ?? '',
                  ].where((part) => part.isNotEmpty).join(' — '),
                  en: [
                    person.fullName,
                    person.jobTitleName?.en ?? person.jobTitleName?.ar ?? '',
                  ].where((part) => part.isNotEmpty).join(' — '),
                ),
              ),
          ]),
        ];
      },
    ),
  ];

  @override
  Future<List<Map<String, String>>> fetch(ExportRequest request) async {
    final people = await _people(
      kind: request.option('kind') ?? 'permanent',
      seasonId: request.narrowing('season'),
    );

    final one = request.narrowing('person');
    final chosen = one == null
        ? people
        : people.where((person) => person.id == one).toList();

    return [for (final person in chosen) _profileRow(person, request)];
  }

  /// The people a set of answers names, resolved the same way for the picker
  /// and for the fetch.
  ///
  /// One method for both on purpose: a picker offering a name that the export
  /// then does not return is the worst failure this screen has, because it
  /// produces an empty file and looks like the data is gone.
  static Future<List<Profile>> _people({
    required String kind,
    String? seasonId,
  }) async {
    if (kind == 'participants') {
      if (seasonId == null) return const [];
      return SeasonsRepository().fetchParticipants(seasonId);
    }

    final repo = EmployeesRepository();
    return [
      // `.data` because the read may have come off disk. An export IS allowed
      // to be built from a saved copy — the alternative is refusing to produce
      // a file at all with no signal — and the ordinary case here is a desk
      // with a network, where it is live anyway.
      if (kind != 'external') ...(await repo.fetchPermanent()).data,
      // An external belongs to a season rather than to the mission, which is
      // why the season narrows this and why «كل المواسم» lists everyone who has
      // ever been one.
      if (kind != 'permanent') ...await repo.fetchExternal(seasonId: seasonId),
    ];
  }

  static String? _narrow(String? value) =>
      (value == null || value.isEmpty || value == ExportOption.anyId)
      ? null
      : value;
}

// ------------------------------------------------------- the master data

/// The master-data lists — التكتلات, the hotels, the camps, the groups.
///
/// One dataset with the list as an option rather than one dataset per list:
/// the sets are content, added by the Administration during a season, and a
/// catalogue that had to be edited to export a new one would be a catalogue
/// that is always one list behind.
class _ReferenceItemsDataset extends ExportDataset {
  @override
  String get id => 'reference_items';

  @override
  LocalizedName get name => _n('البيانات المرجعية', 'Master data');

  @override
  Set<String> get permissions => {PermissionCodes.referenceView};

  @override
  List<ExportColumn> get columns => [
    ExportColumn(key: 'name', label: _n('الاسم', 'Name')),
    ExportColumn(key: 'is_active', label: _n('مُفعَّل', 'Active')),
    ExportColumn(key: 'sort_order', label: _n('الترتيب', 'Order'), byDefault: false),
    ExportColumn(key: 'id', label: _n('المعرّف', 'Id'), byDefault: false),
  ];

  @override
  List<ExportOption> get options => [
    // The season first, then the list. It is the wider question — every
    // narrowing on this screen reads from the widest down — even though here it
    // narrows the ENTRIES rather than which lists exist.
    _seasonOption(),
    ExportOption(
      key: 'set',
      label: _n('القائمة', 'List'),
      choices: (_, _) async {
        final sets = await ModulesRepository().fetchReferenceSets();
        return [
          for (final set in sets) ExportChoice(id: set.id, label: set.name),
        ];
      },
    ),
  ];

  @override
  Future<List<ExportColumn>> extraColumns(Map<String, String> options) async {
    final setId = options['set'];
    if (setId == null) return const [];
    final sets = await ModulesRepository().fetchReferenceSets(activeOnly: false);
    final set = sets.where((candidate) => candidate.id == setId).firstOrNull;
    if (set == null) return const [];
    return [
      for (final field in set.fields)
        ExportColumn(
          key: 'field_${field.key}',
          label: field.label,
          byDefault: false,
        ),
    ];
  }

  @override
  Future<List<Map<String, String>>> fetch(ExportRequest request) async {
    final setId = request.option('set');
    if (setId == null) return [];

    // `activeOnly: false`: an export carries what is there and SAYS which
    // entries are switched off, in its own column. Silently dropping them would
    // make a list of forty hotels read as a list of thirty-one.
    final sets = await ModulesRepository().fetchReferenceSets(activeOnly: false);
    final set = sets.where((candidate) => candidate.id == setId).firstOrNull;
    if (set == null) return [];
    final l = request.l;

    // The season is a property of each ENTRY, not of the query: a set that is
    // season-scoped holds a separate row per season, and one that is not holds
    // rows belonging to no season at all. Filtering the second kind by season
    // would return nothing and look like an empty list.
    final seasonId = request.narrowing('season');
    final items = (set.isSeasonScoped && seasonId != null)
        ? set.items.where((item) => item.seasonId == seasonId).toList()
        : set.items;

    // A set carries its own extra fields — a hotel has a capacity, a camp has a
    // location — and they are exported as their own columns rather than
    // flattened into one. See [dynamicColumns].
    return [
      for (final item in items)
        {
          'name': request.text(item.name),
          'is_active': ExportValues.yesNo(l, item.isActive),
          'sort_order': ExportValues.number(item.sortOrder),
          'id': item.id,
          for (final field in set.fields)
            'field_${field.key}': _fieldValue(item.data[field.key]),
        },
    ];
  }

  static String _fieldValue(Object? value) => switch (value) {
    null => '',
    final Map<String, dynamic> map =>
      // A location, a stored file — the label is what a reader wants, not the
      // JSON it is kept as.
      (map['name'] ?? map['label'] ?? map['address'] ?? '').toString(),
    final List<dynamic> list => list.join(' / '),
    _ => value.toString(),
  };
}

// --------------------------------------------------------------- the records

class _ComplaintsDataset extends ExportDataset {
  @override
  String get id => 'complaints';

  @override
  LocalizedName get name => _n('الشكاوى', 'Complaints');

  @override
  Set<String> get permissions => {PermissionCodes.complaintsView};

  @override
  List<ExportColumn> get columns => [
    ExportColumn(key: 'created_at', label: _n('تاريخ التقديم', 'Filed at')),
    ExportColumn(key: 'target', label: _n('الشكوى على', 'Complaint about')),
    ExportColumn(key: 'target_label', label: _n('الجهة', 'Subject')),
    ExportColumn(key: 'body', label: _n('النص', 'Body')),
    ExportColumn(key: 'complainant', label: _n('المشتكي', 'Complainant')),
    ExportColumn(key: 'is_locked', label: _n('مغلقة', 'Locked')),
    ExportColumn(key: 'is_dismissed', label: _n('غير مُحقّة', 'Dismissed')),
    ExportColumn(key: 'reply_count', label: _n('عدد الردود', 'Replies'), byDefault: false),
    ExportColumn(key: 'id', label: _n('المعرّف', 'Id'), byDefault: false),
  ];

  @override
  List<ExportOption> get options => [
    ExportOption(
      key: 'complaint',
      label: _n('الشكوى', 'Complaint'),
      initial: ExportOption.anyId,
      choices: (_, _) async {
        final complaints = await ComplaintsRepository().fetchList(all: true);
        return [
          ExportChoice(id: ExportOption.anyId, label: _n('الكل', 'All')),
          ...ExportChoice.distinct([
            for (final complaint in complaints)
              ExportChoice(id: complaint.id, label: _complaintTitle(complaint)),
          ]),
        ];
      },
    ),
  ];

  @override
  Future<List<Map<String, String>>> fetch(ExportRequest request) async {
    // `all` is the register, and it is what `complaints.view` grants. The
    // complainant's name comes back only where the caller is entitled to it —
    // the RPC redacts it otherwise, and this exports what it is given.
    final all = await ComplaintsRepository().fetchList(all: true);
    final one = request.narrowing('complaint');
    final complaints = one == null
        ? all
        : all.where((complaint) => complaint.id == one).toList();
    final l = request.l;
    return [
      for (final complaint in complaints)
        {
          'created_at': ExportValues.moment(complaint.createdAt),
          'target': complaintTargetLabel(l, complaint.target),
          'target_label': ExportValues.text(complaint.targetLabel),
          'body': complaint.body,
          'complainant': ExportValues.text(complaint.complainantName),
          'is_locked': ExportValues.yesNo(l, complaint.isLocked),
          'is_dismissed': ExportValues.yesNo(l, complaint.isDismissed),
          'reply_count': ExportValues.number(complaint.replyCount),
          'id': complaint.id,
        },
    ];
  }
}

class _EvaluationsDataset extends ExportDataset {
  @override
  String get id => 'evaluations';

  @override
  LocalizedName get name => _n('التقييمات', 'Evaluations');

  @override
  Set<String> get permissions => {PermissionCodes.evaluationsView};

  @override
  List<ExportColumn> get columns => [
    ExportColumn(key: 'created_at', label: _n('تاريخ الفتح', 'Opened at')),
    ExportColumn(key: 'template', label: _n('النموذج', 'Form')),
    ExportColumn(key: 'target', label: _n('نوع الجهة', 'Subject kind')),
    ExportColumn(key: 'target_label', label: _n('الجهة', 'Subject')),
    ExportColumn(key: 'evaluator', label: _n('المُقيِّم', 'Evaluator')),
    ExportColumn(key: 'status', label: _n('الحالة', 'Status')),
    ExportColumn(key: 'score', label: _n('العلامة', 'Score')),
    ExportColumn(key: 'max_score', label: _n('العلامة القصوى', 'Out of')),
    ExportColumn(key: 'percent', label: _n('النسبة %', 'Percent')),
    ExportColumn(key: 'submitted_at', label: _n('تاريخ الاعتماد', 'Submitted at'), byDefault: false),
    ExportColumn(key: 'due_on', label: _n('تاريخ الاستحقاق', 'Due on'), byDefault: false),
    ExportColumn(key: 'id', label: _n('المعرّف', 'Id'), byDefault: false),
  ];

  @override
  List<ExportOption> get options => [
    ExportOption(
      key: 'evaluation',
      label: _n('التقييم', 'Evaluation'),
      initial: ExportOption.anyId,
      choices: (_, _) async {
        final evaluations = await EvaluationsRepository().fetchList(all: true);
        return [
          ExportChoice(id: ExportOption.anyId, label: _n('الكل', 'All')),
          ...ExportChoice.distinct([
            for (final evaluation in evaluations)
              ExportChoice(
                id: evaluation.id,
                label: _evaluationTitle(evaluation),
              ),
          ]),
        ];
      },
    ),
  ];

  @override
  Future<List<Map<String, String>>> fetch(ExportRequest request) async {
    final all = await EvaluationsRepository().fetchList(all: true);
    final one = request.narrowing('evaluation');
    final evaluations = one == null
        ? all
        : all.where((evaluation) => evaluation.id == one).toList();
    final l = request.l;
    return [
      for (final evaluation in evaluations)
        {
          'created_at': ExportValues.moment(evaluation.createdAt),
          'template': evaluation.templateTitle,
          'target': evaluationTargetLabel(l, evaluation.target),
          'target_label': ExportValues.text(evaluation.targetLabel),
          'evaluator': ExportValues.text(evaluation.evaluatorName),
          'status': evaluation.isSubmitted
              ? l.evaluationStatusSubmitted
              : l.evaluationStatusDraft,
          'score': ExportValues.decimal(evaluation.score),
          'max_score': ExportValues.decimal(evaluation.maxScore),
          'percent': ExportValues.decimal(evaluation.percent),
          'submitted_at': ExportValues.moment(evaluation.submittedAt),
          'due_on': ExportValues.date(evaluation.dueOn),
          'id': evaluation.id,
        },
    ];
  }
}

/// How one complaint is named in a picker.
///
/// Its date and what it is ABOUT, and the first words of it when there is no
/// subject to name — a shelf of «شكوى» repeated forty times is not a list of
/// anything. Built from content strings rather than from the ARB on purpose:
/// the choices are resolved while the form is being answered, and there is no
/// [AppLocalizations] there — the file's own language is settled later, when it
/// is written.
LocalizedName _complaintTitle(Complaint complaint) {
  final said = complaint.body.replaceAll(RegExp(r'\s+'), ' ').trim();
  return LocalizedName(
    ar: [
      ExportValues.date(complaint.createdAt),
      (complaint.targetLabel ?? '').trim(),
      // The opening words STAY even when there is a subject to name. Two
      // complaints about one hotel on one day are ordinary — that is what a bad
      // week at a tower looks like — and «2026-08-20 — فندق الصفوة» twice over
      // is a list a person cannot choose from.
      said.length <= 40 ? said : '${said.substring(0, 40)}…',
    ].where((part) => part.isNotEmpty).join(' — '),
  );
}

/// And one evaluation: the form, whom it is about, WHO IS JUDGING, and when it
/// was opened.
///
/// The evaluator is the whole point of the line, and leaving him off is what
/// made this list unreadable. `assign_evaluations` writes the cartesian product
/// (0084) — one form put to a committee before twenty judges is twenty separate
/// evaluations — so the template, the subject and the date are IDENTICAL across
/// all twenty and the only thing that differs is the name of the man holding
/// the pen. That is exactly the thing a person is choosing between.
///
/// Null where the reader may not know it: 0084 fences the subject off from the
/// names of his judges, and the RPC does not send them at all rather than
/// sending them empty. The line simply stands without it — and
/// [ExportChoice.distinct] then tells the twins apart by id, since nothing
/// readable can.
LocalizedName _evaluationTitle(Evaluation evaluation) => LocalizedName(
  ar: [
    evaluation.templateTitle,
    (evaluation.targetLabel ?? '').trim(),
    (evaluation.evaluatorName ?? '').trim(),
    ExportValues.date(evaluation.createdAt),
  ].where((part) => part.isNotEmpty).join(' — '),
);

// ----------------------------------------------------------- shared options

/// Which season, and it is asked FIRST wherever it is asked.
///
/// Offered by nearly everything, because nearly everything in this app is
/// scoped to one and an export that silently spanned all of them would be read
/// as this year's.
///
/// «كل المواسم» is a real answer with an id rather than an empty dropdown. The
/// two are the same query — do not filter — and they read completely
/// differently: an unanswered field says «لم يُختر بعد» and a person leaves it
/// alone wondering what he missed.
ExportOption _seasonOption({LocalizedName? label}) => ExportOption(
  key: 'season',
  label: label ?? _n('الموسم', 'Season'),
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
);

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
