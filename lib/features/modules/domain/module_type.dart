import '../../../core/l10n/localized_name.dart';

/// Embedded PostgREST lists come back unordered; every catalog table carries a
/// `sort_order` that decides how the admin arranged it.
List<Map<String, dynamic>> _bySortOrder(Object? rows) {
  final list = ((rows as List?) ?? const [])
      .cast<Map<String, dynamic>>()
      .toList();
  list.sort(
    (a, b) =>
        ((a['sort_order'] as int?) ?? 0).compareTo((b['sort_order'] as int?) ?? 0),
  );
  return list;
}

/// The kinds of value a module field can hold. Mirrors the `module_field_kind`
/// enum in the database (0017_modules.sql).
enum ModuleFieldKind {
  text,
  textarea,
  number,
  date,
  reference,
  pdf,
  url,
  location,
  phone,

  /// A value shown AS a scannable code rather than as text. A link is opened;
  /// a code is held up. Reports declare these; nothing in the module catalog
  /// does yet, and nothing has to.
  qr;

  static ModuleFieldKind fromDb(String? value) => switch (value) {
    'textarea' => ModuleFieldKind.textarea,
    'number' => ModuleFieldKind.number,
    'date' => ModuleFieldKind.date,
    'reference' => ModuleFieldKind.reference,
    'pdf' => ModuleFieldKind.pdf,
    'url' => ModuleFieldKind.url,
    'location' => ModuleFieldKind.location,
    'phone' => ModuleFieldKind.phone,
    'qr' => ModuleFieldKind.qr,
    _ => ModuleFieldKind.text,
  };
}

/// One field in a module type's data schema. The value a module stores for it
/// lives under [key] in `modules.data`.
class ModuleField {
  const ModuleField({
    required this.id,
    required this.key,
    required this.label,
    required this.kind,
    this.levelId,
    this.referenceSetId,
    this.isRequired = false,
  });

  final String id;
  final String key;
  final LocalizedName label;
  final ModuleFieldKind kind;

  /// The tree level whose nodes carry this field — the الطاقة الاستيعابية of a
  /// مخيم. Null for a field of the file itself, which is what every field was
  /// until 0052.
  final String? levelId;

  /// Which master-data list backs the dropdown, for [ModuleFieldKind.reference].
  final String? referenceSetId;
  final bool isRequired;

  factory ModuleField.fromMap(Map<String, dynamic> map) => ModuleField(
    id: map['id'] as String,
    key: map['key'] as String,
    label: LocalizedName.fromMap(map, prefix: 'label'),
    kind: ModuleFieldKind.fromDb(map['kind'] as String?),
    levelId: map['level_id'] as String?,
    referenceSetId: map['reference_set_id'] as String?,
    isRequired: (map['is_required'] as bool?) ?? false,
  );
}

/// A named group of the roles a type holds on the FILE itself — فريق الكوسترات
/// and its manager, his deputy and its members.
///
/// Declared by the type (0115), never worked out from the role codes. The three
/// coasters posts do share a prefix and grouping on it would work today and be
/// wrong the first time a role merely starts the same way — the same argument
/// [ModuleLevel.isPlace] makes for itself.
///
/// Carries no sort order: teams appear in the order their roles do, so there is
/// no second ordering to disagree with the roles' own.
class ModuleTeam {
  const ModuleTeam({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final LocalizedName name;

  factory ModuleTeam.fromMap(Map<String, dynamic> map) => ModuleTeam(
    id: map['id'] as String,
    code: map['code'] as String,
    name: LocalizedName.fromMap(map),
  );
}

/// One card's worth of the file's own people: a team and its posts, or a single
/// post that belongs to no team.
///
/// Both are one thing on the page. What differs is only the name at the top —
/// the team's, or the lone role's — which is why this hands out a [name] rather
/// than making the two screens ask which case they are in.
class ModuleRoleGroup {
  const ModuleRoleGroup({required this.roles, this.team});

  /// The team these posts are in, or null for a post standing alone.
  final ModuleTeam? team;

  /// Never empty, and in the type's declared order.
  final List<ModuleRole> roles;

  /// Stable across rebuilds, which is what the folding state is keyed by.
  String get id => team?.id ?? roles.first.id;

  LocalizedName get name => team?.name ?? roles.first.name;

  /// Whether the posts inside need naming individually. A group of one is
  /// already named by its own heading, and repeating it on every tile beneath
  /// says the same word twenty times.
  bool get namesItsPosts => roles.length > 1;
}

/// A job role within a module type.
///
/// No task list since 0105: what a post owes is written on the season's file
/// (`module_tasks`), not on the type. The role's standing text is its job
/// description.
class ModuleRole {
  const ModuleRole({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.levelId,
    this.teamId,
    this.allowsMultiple = false,
    this.isRequired = false,
  });

  final String id;
  final String code;
  final LocalizedName name;

  /// The job description (الوصف الوظيفي): what the post is, stated once by the
  /// Administration.
  final LocalizedName? description;

  /// The tree level this role is held at — a sector supervisor is appointed per
  /// sector, a tower supervisor per tower. Null for a role held once for the
  /// whole file.
  final String? levelId;

  /// The [ModuleTeam] this post belongs to (0115). Null is the ordinary case
  /// and means the post stands alone.
  ///
  /// Meaningless alongside [levelId]: a role held at a level already groups
  /// under its node, and [ModuleType.roleGroups] only ever reads this for the
  /// roles held on the file.
  final String? teamId;

  /// Roles such as "mission members" hold several people; a supervisor holds one.
  final bool allowsMultiple;
  final bool isRequired;

  factory ModuleRole.fromMap(Map<String, dynamic> map) => ModuleRole(
    id: map['id'] as String,
    code: map['code'] as String,
    name: LocalizedName.fromMap(map),
    description: map['description_ar'] == null
        ? null
        : LocalizedName.fromMap(map, prefix: 'description'),
    levelId: map['level_id'] as String?,
    teamId: map['team_id'] as String?,
    allowsMultiple: (map['allows_multiple'] as bool?) ?? false,
    isRequired: (map['is_required'] as bool?) ?? false,
  );
}

/// One level of a module type's tree: القطاع, then البرج/الفندق inside it.
///
/// [referenceSetId] is what a node at this level *is*. A tower is a hotel taken
/// from the hotels list, a مخيم is an entry of the camps list. Since 0095 every
/// level of every type has one: nothing is authored inside a file.
class ModuleLevel {
  const ModuleLevel({
    required this.id,
    required this.code,
    required this.name,
    required this.depth,
    this.referenceSetId,
    this.referenceFilter,
    this.secondaryReferenceSetId,
    this.isPlace = false,
    this.fields = const [],
    this.roles = const [],
  });

  final String id;
  final String code;
  final LocalizedName name;

  /// 1 is the outermost level; each level nests inside the one before it.
  final int depth;
  final String? referenceSetId;

  /// The slice of [referenceSetId] this level may draw from, or null for all of
  /// it — which is every level but the camps and the centres.
  ///
  /// One مخيمات list serves both مشاعر, because a camp is a camp; but المخيم
  /// رقم 11 at منى and المخيم رقم 11 at عرفات are a kilometre apart, and
  /// offering the منى file both is offering it a mistake that no later rule can
  /// catch — the row would be perfectly well-formed and simply false.
  ///
  /// Matched by containment against the entry's own `data`, the same way the
  /// server's `@>` reads it: every key here must be present and equal.
  final Map<String, dynamic>? referenceFilter;

  /// A second list a node here is TIED to, as opposed to what it is: a برج is a
  /// فندق, and it belongs to a تكتل. Null for a level that ties to nothing,
  /// which is every level but the tower.
  final String? secondaryReferenceSetId;

  /// Whether a node here is somewhere a person can STAND — a tower, a camp —
  /// as opposed to an arrangement on paper, like a قطاع or a تكتل.
  ///
  /// Stated by the level rather than worked out, because every way of working
  /// it out is wrong somewhere: مكة nests القطاع → البرج → التكتل, so it is not
  /// the deepest; the تكتل draws from master data just as the tower does, so it
  /// is not "has a list"; and منى's المخيم is not the outermost. See 0089.
  ///
  /// Defaults to false when the column is absent — an app running against a
  /// database that has not had 0089 applied offers no codes at all, and says
  /// so, rather than offering the wrong ones.
  final bool isPlace;

  /// What every node at this level carries besides its name — the الطاقة
  /// الاستيعابية and the موقع of a مخيم. Empty for a level that asks for
  /// nothing further.
  final List<ModuleField> fields;

  /// The roles held at this level, in the order they are filled.
  final List<ModuleRole> roles;

  /// Whether a node here is picked from master data (a hotel) or named by hand.
  ///
  /// False everywhere since 0095. Kept because a type added later may still
  /// want a rung that is a division of one file and of nothing else.
  bool get isNamedByHand => referenceSetId == null;

  ModuleLevel withRolesAndFields(
    List<ModuleRole> roles,
    List<ModuleField> fields,
  ) => ModuleLevel(
    id: id,
    code: code,
    name: name,
    depth: depth,
    referenceSetId: referenceSetId,
    referenceFilter: referenceFilter,
    secondaryReferenceSetId: secondaryReferenceSetId,
    // Every level goes through here while a type is parsed, so anything left
    // out is not "defaulted" — it is ERASED, silently, on the way in.
    isPlace: isPlace,
    fields: fields,
    roles: roles,
  );

  factory ModuleLevel.fromMap(Map<String, dynamic> map) => ModuleLevel(
    id: map['id'] as String,
    code: map['code'] as String,
    name: LocalizedName.fromMap(map),
    depth: (map['depth'] as int?) ?? 1,
    referenceSetId: map['reference_set_id'] as String?,
    referenceFilter: (map['reference_filter'] as Map?)?.cast<String, dynamic>(),
    secondaryReferenceSetId: map['secondary_reference_set_id'] as String?,
    isPlace: (map['is_place'] as bool?) ?? false,
  );
}

/// A kind of operational file. Everything that makes one type differ from
/// another — its fields, its tree, its roles, tasks and attachments — hangs off
/// this row, so adding a type is data entry rather than a schema change.
///
/// A file of a given type exists at most once in a season: the type's name is
/// the file's name, which is why a file carries no title of its own.
class ModuleType {
  const ModuleType({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.startCondition,
    this.endCondition,
    this.fields = const [],
    this.roles = const [],
    this.levels = const [],
    this.teams = const [],
  });

  final String id;
  final String code;
  final LocalizedName name;
  final LocalizedName? description;

  /// What opens a file of this type — "من تاريخ اعتماد مجموعات الحج السوري".
  /// The file still carries the date somebody entered; this says what that date
  /// is the date OF. Null for a type whose start was never stated as an event.
  final LocalizedName? startCondition;

  /// What closes a file of this type — the same event every season, so it is
  /// stated here rather than entered as a date on each file.
  final LocalizedName? endCondition;

  final List<ModuleField> fields;

  /// Roles held once for the whole file. Roles held per sector or per tower
  /// live on their [ModuleLevel] instead.
  final List<ModuleRole> roles;

  /// The tree this type's files are built as, outermost level first. Empty for
  /// a type that has no tree: الطوافة والنقل is a roster, not a hierarchy, and
  /// its people sit on the file itself.
  final List<ModuleLevel> levels;

  /// The teams this type declares — groups of the roles held on the file
  /// itself. Empty for every type but the two of 0115.
  final List<ModuleTeam> teams;

  /// Whether files of this type are built as sectors and towers, or are simply
  /// the list of the people in them.
  bool get hasTree => levels.isNotEmpty;

  /// The file's own roles, gathered into what the page should draw as one card
  /// each: a team with its posts, or a post standing alone.
  ///
  /// The ORDER is the roles' own, and a team takes the place of its first post
  /// — which is why [ModuleTeam] carries no sort of its own. Two orderings
  /// would be two things to keep agreeing, and the roles already have one that
  /// an administrator set.
  ///
  /// Roles held at a level are not here at all: [roles] is already only the
  /// file's own, and a sector supervisor groups under his sector.
  List<ModuleRoleGroup> get roleGroups {
    final byId = {for (final team in teams) team.id: team};
    final groups = <ModuleRoleGroup>[];
    // Where each team's card has been placed, so the second and third posts
    // join the first rather than opening a card of their own.
    final placed = <String, int>{};

    for (final role in roles) {
      final team = byId[role.teamId];
      if (team == null) {
        groups.add(ModuleRoleGroup(roles: [role]));
        continue;
      }
      final at = placed[team.id];
      if (at == null) {
        placed[team.id] = groups.length;
        groups.add(ModuleRoleGroup(team: team, roles: [role]));
      } else {
        groups[at] = ModuleRoleGroup(
          team: team,
          roles: [...groups[at].roles, role],
        );
      }
    }
    return groups;
  }

  ModuleLevel? levelById(String? id) =>
      levels.where((l) => l.id == id).firstOrNull;

  ModuleLevel? get outermostLevel => levels.firstOrNull;

  /// The levels that are somewhere a person can stand.
  ///
  /// Read from the level, never worked out from the tree. Depth cannot answer
  /// it: مكة nests القطاع → البرج/الفندق → التكتل, and the تكتل — a bloc of
  /// pilgrims INSIDE a building — is the deepest of the three. See 0089.
  List<ModuleLevel> get placeLevels =>
      [for (final level in levels) if (level.isPlace) level];

  /// The level nested directly inside [level], if any.
  ModuleLevel? levelBelow(ModuleLevel level) =>
      levels.where((l) => l.depth == level.depth + 1).firstOrNull;

  ModuleRole? roleById(String id) =>
      allRoles.where((r) => r.id == id).firstOrNull;

  /// Every role of the type, file-level and level-scoped alike.
  List<ModuleRole> get allRoles => [
    ...roles,
    for (final level in levels) ...level.roles,
  ];

  factory ModuleType.fromMap(Map<String, dynamic> map) {
    // Roles arrive in one flat list and are sorted into the level that holds
    // them; whatever names no level is held for the file as a whole.
    final roles = _bySortOrder(
      map['module_type_roles'],
    ).map(ModuleRole.fromMap).toList();
    // Fields are sorted the same way: whatever names a level is carried by
    // every node at it, and whatever names none belongs to the file.
    final fields = _bySortOrder(
      map['module_type_fields'],
    ).map(ModuleField.fromMap).toList();
    final levels = (((map['module_type_levels'] as List?) ?? const [])
            .cast<Map<String, dynamic>>())
        .map(ModuleLevel.fromMap)
        .toList();
    levels.sort((a, b) => a.depth.compareTo(b.depth));

    return ModuleType(
      id: map['id'] as String,
      code: map['code'] as String,
      name: LocalizedName.fromMap(map),
      description: map['description_ar'] == null
          ? null
          : LocalizedName.fromMap(map, prefix: 'description'),
      startCondition: map['start_condition_ar'] == null
          ? null
          : LocalizedName.fromMap(map, prefix: 'start_condition'),
      endCondition: map['end_condition_ar'] == null
          ? null
          : LocalizedName.fromMap(map, prefix: 'end_condition'),
      fields: fields.where((f) => f.levelId == null).toList(),
      roles: roles.where((r) => r.levelId == null).toList(),
      teams: (((map['module_type_teams'] as List?) ?? const [])
              .cast<Map<String, dynamic>>())
          .map(ModuleTeam.fromMap)
          .toList(),
      levels: [
        for (final level in levels)
          level.withRolesAndFields(
            roles.where((r) => r.levelId == level.id).toList(),
            fields.where((f) => f.levelId == level.id).toList(),
          ),
      ],
    );
  }
}
