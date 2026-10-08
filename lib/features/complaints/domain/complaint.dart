import '../../../core/attachments/attachment.dart';

export '../../../core/attachments/attachment.dart';

/// What a complaint is about.
///
/// Mirrors the `complaint_target_type` enum (migration 0079). Hotels, clusters
/// and groups are all rows of `reference_items` in the database and are told
/// apart by the set they belong to — but they are three different things to the
/// person filing, so they are three values here and three values there.
enum ComplaintTarget {
  employee,
  module,
  report,
  hotel,
  cluster,
  group,
  other;

  static ComplaintTarget fromDb(String? value) => switch (value) {
    'employee' => ComplaintTarget.employee,
    'module' => ComplaintTarget.module,
    'report' => ComplaintTarget.report,
    'hotel' => ComplaintTarget.hotel,
    'cluster' => ComplaintTarget.cluster,
    'group' => ComplaintTarget.group,
    _ => ComplaintTarget.other,
  };

  /// Whether filing against this needs something picked. `other` is the one
  /// complaint with nothing to point at — the form asks for nothing but words.
  bool get needsTarget => this != ComplaintTarget.other;

  /// The three that are rows of `reference_items`, which is the one thing the
  /// picker has to know: they are all read from the same table, filtered by the
  /// set whose code is this value's own name.
  bool get isReferenceItem =>
      this == ComplaintTarget.hotel ||
      this == ComplaintTarget.cluster ||
      this == ComplaintTarget.group;
}

/// One thing a complaint may be filed against, as the picker lists it: an id,
/// a name, and a face where the kind has one.
typedef ComplaintTargetOption = ({String id, String name, String? photoUrl});

/// Who the reader is to a complaint, as the server worked it out.
///
/// The server decides this, not the app: the same three words also govern what
/// it redacts, and a second opinion computed on the client would be a second
/// answer to a question that must only have one.
enum ComplaintRole {
  complainant,
  accused,
  manager;

  static ComplaintRole fromDb(String? value) => switch (value) {
    'accused' => ComplaintRole.accused,
    'manager' => ComplaintRole.manager,
    _ => ComplaintRole.complainant,
  };
}

/// One complaint as the register lists it.
class Complaint {
  const Complaint({
    required this.id,
    required this.createdAt,
    required this.target,
    required this.body,
    this.targetId,
    this.targetLabel,
    this.complainantId,
    this.complainantName,
    this.complainantPhotoUrl,
    this.isLocked = false,
    this.isDismissed = false,
    this.replyCount = 0,
    this.attachmentCount = 0,
    this.attachments = const [],
    this.myRole = ComplaintRole.complainant,
  });

  final String id;
  final DateTime createdAt;
  final ComplaintTarget target;
  final String body;

  /// Null for [ComplaintTarget.other], and for a target that has since been
  /// deleted — which is why [targetLabel] is a snapshot and not a lookup.
  final String? targetId;
  final String? targetLabel;

  /// Null when this reader may not know. The accused never learns these three,
  /// and they do not arrive over the wire at all rather than arriving empty.
  final String? complainantId;
  final String? complainantName;
  final String? complainantPhotoUrl;

  final bool isLocked;
  final bool isDismissed;
  final int replyCount;
  final int attachmentCount;
  final List<StoredAttachment> attachments;
  final ComplaintRole myRole;

  bool get isAnonymousToMe => complainantId == null;

  /// The register's shape (`complaints_list`).
  factory Complaint.fromListRow(Map<String, dynamic> map) => Complaint(
    id: map['id'] as String,
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    target: ComplaintTarget.fromDb(map['target_type'] as String?),
    targetId: map['target_id'] as String?,
    targetLabel: map['target_label'] as String?,
    complainantId: map['complainant_id'] as String?,
    complainantName: map['complainant_name'] as String?,
    complainantPhotoUrl: map['complainant_photo_url'] as String?,
    body: (map['body'] as String?) ?? '',
    isLocked: (map['is_locked'] as bool?) ?? false,
    isDismissed: (map['is_dismissed'] as bool?) ?? false,
    replyCount: (map['reply_count'] as num?)?.toInt() ?? 0,
    attachmentCount: (map['attachment_count'] as num?)?.toInt() ?? 0,
    myRole: ComplaintRole.fromDb(map['my_role'] as String?),
  );

  /// The accused's own list (`complaints_against_me`), which carries no
  /// identity columns at all and brings its attachments with it.
  factory Complaint.fromAgainstMeRow(Map<String, dynamic> map) => Complaint(
    id: map['id'] as String,
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    target: ComplaintTarget.employee,
    body: (map['body'] as String?) ?? '',
    isLocked: (map['is_locked'] as bool?) ?? false,
    isDismissed: (map['is_dismissed'] as bool?) ?? false,
    replyCount: (map['reply_count'] as num?)?.toInt() ?? 0,
    attachments: _attachments(map['attachments']),
    attachmentCount: _attachments(map['attachments']).length,
    myRole: ComplaintRole.accused,
  );
}

/// One bubble in a thread: the complaint itself, or a reply to it.
///
/// The head of the thread and its replies are one type because they are one
/// conversation — the screen draws them in a single list and the only thing
/// that tells them apart is that the head has no [replyId].
class ComplaintMessage {
  const ComplaintMessage({
    required this.createdAt,
    required this.body,
    required this.role,
    required this.isMine,
    this.replyId,
    this.authorId,
    this.authorName,
    this.authorPhotoUrl,
    this.attachments = const [],
  });

  /// Null on the head — the complaint's own words.
  final String? replyId;
  final DateTime createdAt;
  final String body;

  /// Null when this reader may not know who wrote it. [role] always arrives, so
  /// an unnamed bubble can still say what side it came from.
  final String? authorId;
  final String? authorName;
  final String? authorPhotoUrl;

  final ComplaintRole role;
  final bool isMine;
  final List<StoredAttachment> attachments;

  bool get isHead => replyId == null;
  bool get isAnonymous => authorId == null;

  factory ComplaintMessage.fromMap(Map<String, dynamic> map) =>
      ComplaintMessage(
        replyId: map['reply_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        body: (map['body'] as String?) ?? '',
        authorId: map['author_id'] as String?,
        authorName: map['author_name'] as String?,
        authorPhotoUrl: map['author_photo_url'] as String?,
        role: ComplaintRole.fromDb(map['author_role'] as String?),
        isMine: (map['is_mine'] as bool?) ?? false,
        attachments: _attachments(map['attachments']),
      );
}

/// The numbers at the foot of an employee's page (`complaints_against`).
class ComplaintStanding {
  const ComplaintStanding({
    this.distinctComplainants = 0,
    this.openComplaints = 0,
    this.dismissedComplaints = 0,
    this.isAutoSuspended = false,
    this.forgivenCount = 0,
  });

  /// The number the rule counts. Three of these suspends the account.
  final int distinctComplainants;
  final int openComplaints;
  final int dismissedComplaints;

  /// Whether the suspension in force was imposed by the rule rather than by a
  /// person — the difference between a switch that will move on its own and one
  /// that will not.
  final bool isAutoSuspended;

  /// How many distinct complainants a person already forgave by lifting an
  /// automatic suspension by hand. The rule fires again only past this.
  final int forgivenCount;

  static const threshold = 3;

  bool get isEmpty => openComplaints == 0 && dismissedComplaints == 0;

  /// One more accuser would suspend the account. Worth saying out loud on the
  /// page, because the next filing is not a warning — it is the suspension.
  bool get isOneShortOfSuspension =>
      !isAutoSuspended &&
      distinctComplainants == threshold - 1 &&
      forgivenCount < threshold - 1;

  factory ComplaintStanding.fromMap(Map<String, dynamic> map) =>
      ComplaintStanding(
        distinctComplainants:
            (map['distinct_complainants'] as num?)?.toInt() ?? 0,
        openComplaints: (map['open_complaints'] as num?)?.toInt() ?? 0,
        dismissedComplaints:
            (map['dismissed_complaints'] as num?)?.toInt() ?? 0,
        isAutoSuspended: (map['is_auto_suspended'] as bool?) ?? false,
        forgivenCount: (map['forgiven_count'] as num?)?.toInt() ?? 0,
      );
}

List<StoredAttachment> _attachments(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .cast<Map<String, dynamic>>()
      .map(StoredAttachment.fromMap)
      .toList();
}
