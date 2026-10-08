import '../../../core/attachments/attachment.dart';
import '../../../core/l10n/localized_name.dart';
import '../../profile/domain/profile.dart';

export '../../../core/attachments/attachment.dart';

/// A PDF stored in the private `modules` bucket. The path is what lives in
/// `modules.data`; a signed URL is minted on demand when someone opens it.
class ModuleFile {
  const ModuleFile({required this.path, required this.name});

  final String path;
  final String name;

  Map<String, dynamic> toJson() => {'path': path, 'name': name};

  static ModuleFile? fromJson(Object? value) {
    if (value is! Map) return null;
    final path = value['path'] as String?;
    if (path == null || path.isEmpty) return null;
    return ModuleFile(path: path, name: (value['name'] as String?) ?? path);
  }
}

/// A person holding a role somewhere in a file: either on the file itself, or
/// on one of its nodes.
class ModuleMember {
  const ModuleMember({
    required this.id,
    required this.roleId,
    required this.profileId,
    this.moduleId,
    this.nodeId,
    this.housingItemId,
    this.profile,
  });

  final String id;
  final String roleId;
  final String profileId;

  /// Set for a file-level role; null for a role held on a node.
  final String? moduleId;

  /// Set for a role held on a sector or a tower; null for a file-level role.
  final String? nodeId;

  /// The hotel he sleeps in, written against this posting — asked for only
  /// where the node itself is not a place, which is where it cannot be worked
  /// out: a برج IS one hotel, a قطاع is four of them and says nothing about
  /// which holds his bed. Null everywhere else, and a tower member's مسكن stays
  /// derived from his tower (0136, 0139).
  final String? housingItemId;

  /// Joined when the query embeds `profiles(...)`.
  final Profile? profile;

  factory ModuleMember.fromMap(Map<String, dynamic> map) {
    final joined = map['profiles'];
    return ModuleMember(
      id: map['id'] as String,
      roleId: map['role_id'] as String,
      profileId: map['profile_id'] as String,
      moduleId: map['module_id'] as String?,
      nodeId: map['node_id'] as String?,
      housingItemId: map['housing_item_id'] as String?,
      profile: joined is Map<String, dynamic> ? Profile.fromMap(joined) : null,
    );
  }
}

/// One place inside a file: a sector, or a tower within it.
///
/// A node is either an entry from master data — a tower *is* a hotel — or, when
/// its level has no list, something named for this file alone ("القطاع الأول").
class ModuleNode {
  const ModuleNode({
    required this.id,
    required this.moduleId,
    required this.levelId,
    this.parentId,
    this.referenceItemId,
    this.secondaryReferenceItemId,
    this.label,
    this.data = const {},
    this.sortOrder = 0,
    this.members = const [],
  });

  final String id;
  final String moduleId;
  final String levelId;

  /// The node this one sits inside — a tower's sector. Null at the top level.
  final String? parentId;

  final String? referenceItemId;

  /// The entry chosen from the level's SECOND list — what this node is tied to
  /// rather than what it is: the تكتل a برج falls under. Null for a level that
  /// names no such list.
  final String? secondaryReferenceItemId;

  final String? label;

  /// The values of this node's level fields, keyed by field key — the same
  /// shape `modules.data` has for the file's own fields.
  final Map<String, dynamic> data;

  final int sortOrder;
  final List<ModuleMember> members;

  List<ModuleMember> membersOf(String roleId) =>
      members.where((m) => m.roleId == roleId).toList();

  Set<String> profileIdsOf(String roleId) =>
      members.where((m) => m.roleId == roleId).map((m) => m.profileId).toSet();

  /// The hotel written against each holder of [roleId], keyed by profile. An
  /// entry with a null value is a man on the posting whose bed has not been
  /// said yet, which is different from his not being on it.
  Map<String, String?> housingOf(String roleId) => {
    for (final m in members.where((m) => m.roleId == roleId))
      m.profileId: m.housingItemId,
  };

  ModuleNode withMembers(List<ModuleMember> members) => ModuleNode(
    id: id,
    moduleId: moduleId,
    levelId: levelId,
    parentId: parentId,
    referenceItemId: referenceItemId,
    secondaryReferenceItemId: secondaryReferenceItemId,
    label: label,
    data: data,
    sortOrder: sortOrder,
    members: members,
  );

  factory ModuleNode.fromMap(Map<String, dynamic> map) {
    final members = ((map['module_node_members'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ModuleMember.fromMap)
        .toList();
    return ModuleNode(
      id: map['id'] as String,
      moduleId: map['module_id'] as String,
      levelId: map['level_id'] as String,
      parentId: map['parent_id'] as String?,
      referenceItemId: map['reference_item_id'] as String?,
      secondaryReferenceItemId: map['secondary_reference_item_id'] as String?,
      label: map['label'] as String?,
      data: Map<String, dynamic>.from((map['data'] as Map?) ?? const {}),
      sortOrder: (map['sort_order'] as int?) ?? 0,
      members: members,
    );
  }
}

/// A file seen from the person's side: which file, where in it, and in what
/// capacity. One employee may hold roles in several files, and in several
/// places within one — a sector supervisor covers every tower under him.
class ModuleAssignment {
  const ModuleAssignment({
    required this.module,
    required this.roleName,
    this.placeName,
  });

  final OperationalModule module;
  final LocalizedName roleName;

  /// Where in the file — "البرج/الفندق: فندق الصفوة". Null for a role held on
  /// the file as a whole.
  final String? placeName;

  /// From `module_node_members`, which carries the node this role sits on.
  factory ModuleAssignment.fromNodeMap(Map<String, dynamic> map) {
    final node = (map['module_nodes'] as Map?)?.cast<String, dynamic>();
    final level = (node?['module_type_levels'] as Map?)?.cast<String, dynamic>();
    final item = (node?['reference_items'] as Map?)?.cast<String, dynamic>();

    // "البرج/الفندق: فندق الصفوة" — the level, then whichever of the two ways
    // of naming a node its level uses.
    final parts = [
      (level?['name_ar'] as String?) ?? '',
      (item?['name_ar'] as String?) ?? (node?['label'] as String?) ?? '',
    ].where((s) => s.isNotEmpty);

    return ModuleAssignment(
      module: OperationalModule.fromMap(
        (node?['modules'] as Map).cast<String, dynamic>(),
      ),
      roleName: LocalizedName.fromMap(
        (map['module_type_roles'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      placeName: parts.join(': '),
    );
  }

  /// From `module_members` — a role held on the file itself.
  factory ModuleAssignment.fromModuleMap(Map<String, dynamic> map) =>
      ModuleAssignment(
        module: OperationalModule.fromMap(
          (map['modules'] as Map).cast<String, dynamic>(),
        ),
        roleName: LocalizedName.fromMap(
          (map['module_type_roles'] as Map?)?.cast<String, dynamic>() ??
              const {},
        ),
      );
}

/// How often a file asks the people in it for a report. Mirrors the
/// `report_cadence` enum (0044).
///
/// [none] is a real answer, and the usual one — most files ask for nothing, and
/// a file that asks for a report nobody reads is worse than one that does not.
enum ReportCadence {
  none,
  daily,
  weekly,
  once;

  static ReportCadence fromDb(String? value) => switch (value) {
    'daily' => ReportCadence.daily,
    'weekly' => ReportCadence.weekly,
    'once' => ReportCadence.once,
    _ => ReportCadence.none,
  };

  bool get asksForReports => this != ReportCadence.none;
}

/// What the people in a finished file said about one of them: the average, and
/// how many said it.
///
/// Never who. A member reads only his own — the database returns two numbers
/// and no names, and the rows themselves are readable by nobody but the person
/// who wrote them.
class RatingSummary {
  const RatingSummary({required this.average, required this.ratings});

  static const none = RatingSummary(average: 0, ratings: 0);

  final double average;
  final int ratings;

  bool get isRated => ratings > 0;

  factory RatingSummary.fromMap(Map<String, dynamic> map) => RatingSummary(
    average: (map['average'] as num?)?.toDouble() ?? 0,
    ratings: (map['ratings'] as num?)?.toInt() ?? 0,
  );
}

/// One report filed against a file by one of its members.
///
/// The report is what was attached — the signed sheet, the photo of the tower,
/// the voice note recorded in the bus. [notes] is whatever the filer wanted to
/// say about them, and is usually nothing.
class ModuleReport {
  const ModuleReport({
    required this.id,
    required this.authorId,
    required this.createdAt,
    this.notes,
    this.attachments = const [],
    this.periodStart,
    this.author,
  });

  final String id;
  final String authorId;
  final String? notes;
  final List<StoredAttachment> attachments;
  final DateTime createdAt;

  /// The stretch it accounts for — the day, or the Monday of the week. Null for
  /// a file that asks once.
  final DateTime? periodStart;

  /// Joined when the query embeds `profiles(...)`.
  final Profile? author;

  factory ModuleReport.fromMap(Map<String, dynamic> map) {
    final joined = map['profiles'];
    final rows = ((map['module_report_attachments'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .toList()
      // Sorted here rather than in the query: an embedded resource comes back
      // in whatever order it comes back in, and the strip should read in the
      // order things were attached.
      ..sort(
        (a, b) => ((a['sort_order'] as num?) ?? 0).compareTo(
          (b['sort_order'] as num?) ?? 0,
        ),
      );
    final attachments = rows.map(StoredAttachment.fromMap).toList();
    return ModuleReport(
      id: map['id'] as String,
      authorId: map['author_id'] as String,
      notes: map['body'] as String?,
      attachments: attachments,
      // Local time for display; period_start is a plain date and stays as-is.
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      periodStart: map['period_start'] == null
          ? null
          : DateTime.tryParse(map['period_start'] as String),
      author: joined is Map<String, dynamic> ? Profile.fromMap(joined) : null,
    );
  }
}

/// An operational file: one unit of season work, shaped by its type.
///
/// It has no title — a file is created once per season and its type names it.
/// It has a start date; its end is not a date but an event fixed by the type
/// ("ترحيل آخر حاج إلى المدينة المنورة").
class OperationalModule {
  const OperationalModule({
    required this.id,
    required this.moduleTypeId,
    required this.seasonId,
    this.startsOn,
    this.endsOn,
    this.startNote,
    this.endNote,
    this.decisionNumber,
    this.data = const {},
    this.isActive = false,
    this.reportCadence = ReportCadence.none,
    this.seasonHijriYear,
    this.moduleTypeName,
    this.endCondition,
    this.createdAt,
  });

  final String id;
  final String moduleTypeId;
  final String seasonId;

  /// When work at the towers begins.
  final DateTime? startsOn;

  /// The day this file stops being live, inclusive — it is still running ON
  /// that date. Null for a file with no end set.
  ///
  /// Not the same thing as the type's [endCondition]: that says what EVENT
  /// closes a file of this kind, in prose, the same sentence every season. This
  /// is a date on one file. The condition says what will end it; the date says
  /// when it did.
  final DateTime? endsOn;

  /// ملاحظة بداية العمل — what this file's start was, in the words of whoever
  /// opened it. Optional, and usually empty.
  ///
  /// Not the type's [ModuleType.startCondition]: that is prose about every file
  /// of the kind, the same sentence every season. This is one file's own.
  final String? startNote;

  /// ملاحظة نهاية العمل. Optional in the same way, and emptier still — what
  /// there is to say about an end is usually not writable until it has happened.
  final String? endNote;

  /// رقم القرار. Optional: a file is often opened before the decision that
  /// authorises it is issued, and the number arrives afterwards.
  final String? decisionNumber;

  /// Field values keyed by [ModuleField.key].
  final Map<String, dynamic> data;

  /// The switch an administrator throws. Files stay invisible to their members
  /// until it is on — but it is not the whole answer to "is this file live":
  /// see [isRunning].
  final bool isActive;

  /// How often this file asks its members for a report. Chosen by whoever
  /// creates or edits it, per file rather than per type: الطوافة والنقل wants one
  /// every day and الإنشاءات wants one at the end.
  final ReportCadence reportCadence;

  /// Joined for list rendering, so a card can be drawn without a second query.
  final int? seasonHijriYear;
  final LocalizedName? moduleTypeName;
  final LocalizedName? endCondition;
  final DateTime? createdAt;

  /// Whether the end date has gone by. Inclusive: a file ending today is still
  /// running today.
  bool get hasEnded {
    final end = endsOn;
    if (end == null) return false;
    final today = DateTime.now();
    return DateTime(end.year, end.month, end.day).isBefore(
      DateTime(today.year, today.month, today.day),
    );
  }

  /// Whether this is a working file: switched on, and not yet out of time.
  ///
  /// This is what the app should ask nearly everywhere. [isActive] alone is the
  /// switch, and is what the button toggling it needs to read — the database
  /// draws the same distinction, and hides a file that has run out from its
  /// members exactly as it hides one that was switched off.
  bool get isRunning => isActive && !hasEnded;

  ModuleFile? fileAt(String key) => ModuleFile.fromJson(data[key]);

  factory OperationalModule.fromMap(Map<String, dynamic> map) {
    final season = map['seasons'];
    final type = (map['module_types'] as Map?)?.cast<String, dynamic>();
    return OperationalModule(
      id: map['id'] as String,
      moduleTypeId: map['module_type_id'] as String,
      seasonId: map['season_id'] as String,
      startsOn: map['starts_on'] == null
          ? null
          : DateTime.tryParse(map['starts_on'] as String),
      endsOn: map['ends_on'] == null
          ? null
          : DateTime.tryParse(map['ends_on'] as String),
      startNote: map['start_note'] as String?,
      endNote: map['end_note'] as String?,
      decisionNumber: map['decision_number'] as String?,
      data: Map<String, dynamic>.from(
        (map['data'] as Map?) ?? const <String, dynamic>{},
      ),
      isActive: (map['is_active'] as bool?) ?? false,
      reportCadence: ReportCadence.fromDb(map['report_cadence'] as String?),
      seasonHijriYear: season is Map ? season['hijri_year'] as int? : null,
      moduleTypeName: type == null ? null : LocalizedName.fromMap(type),
      endCondition: type == null || type['end_condition_ar'] == null
          ? null
          : LocalizedName.fromMap(type, prefix: 'end_condition'),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}
