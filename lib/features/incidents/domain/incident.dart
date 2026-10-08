import '../../../core/attachments/attachment.dart';

/// How far along an urgent report is. Mirrors `incident_state` (0088).
enum IncidentState {
  /// Nobody has picked it up.
  open,

  /// Somebody has, and is dealing with it. The middle state is the point: two
  /// states cannot tell "seen" from "somebody is on their way", and during the
  /// five days that is the difference the operations room is managing.
  inProgress,

  /// Dealt with.
  closed;

  static IncidentState fromDb(String? value) => switch (value) {
    'in_progress' => IncidentState.inProgress,
    'closed' => IncidentState.closed,
    _ => IncidentState.open,
  };

  String get dbName => switch (this) {
    IncidentState.open => 'open',
    IncidentState.inProgress => 'in_progress',
    IncidentState.closed => 'closed',
  };

  bool get isOpen => this == IncidentState.open;
  bool get isClosed => this == IncidentState.closed;
}

/// One urgent report, as the register reads it back.
class Incident {
  const Incident({
    required this.id,
    required this.body,
    required this.state,
    required this.createdAt,
    required this.reporterId,
    required this.reporterName,
    this.reporterPhone,
    this.moduleId,
    this.moduleName,
    this.nodeLabel,
    this.subjectId,
    this.subjectName,
    this.subjectPhone,
    this.appRoute,
    this.appLabel,
    this.latitude,
    this.longitude,
    this.handledByName,
    this.handledAt,
    this.resolution,
    this.attachmentCount = 0,
  });

  final String id;
  final String body;
  final IncidentState state;
  final DateTime createdAt;

  /// Named, and named first. The opposite of a complaint, and deliberately so:
  /// whoever receives this needs to telephone him back within the minute.
  final String reporterId;
  final String reporterName;
  final String? reporterPhone;

  final String? moduleId;
  final String? moduleName;
  final String? nodeLabel;

  /// Who the report is ABOUT, which is never who filed it — the database drops
  /// a subject that is the reporter himself rather than refusing the report
  /// (0120). Null on most reports, and that is the expected shape.
  final String? subjectId;
  final String? subjectName;

  /// The subject's number, for the second call. The room telephones the
  /// reporter to ask what happened and the subject to find out where he is.
  final String? subjectPhone;

  /// The screen the report is about, when it is about the app rather than about
  /// the mission — the route so the register can open it, and the words the
  /// reporter saw on it so a reader can tell what it was without following the
  /// link. See 0120 for why both are stored.
  final String? appRoute;
  final String? appLabel;

  final double? latitude;
  final double? longitude;

  final String? handledByName;
  final DateTime? handledAt;
  final String? resolution;

  final int attachmentCount;

  /// How long it has been waiting for somebody to pick it up.
  ///
  /// Stops counting once somebody has. The number that matters is how long it
  /// sat unanswered, and letting it keep climbing after a man was dispatched
  /// would report the wrong failure.
  Duration get waited => (handledAt ?? DateTime.now()).difference(createdAt);

  /// A map link for the reporter's position, when the phone gave one.
  String? get mapUrl {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return null;
    return 'https://www.google.com/maps?q=$lat,$lng';
  }

  bool get hasPlace => latitude != null && longitude != null;

  static Incident fromRow(Map<String, dynamic> map) => Incident(
    id: map['id'] as String,
    body: (map['body'] as String?) ?? '',
    state: IncidentState.fromDb(map['state'] as String?),
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    reporterId: (map['reporter_id'] as String?) ?? '',
    reporterName: (map['reporter_name'] as String?) ?? '',
    reporterPhone: map['reporter_phone'] as String?,
    moduleId: map['module_id'] as String?,
    moduleName: map['module_name'] as String?,
    nodeLabel: map['node_label'] as String?,
    subjectId: map['subject_id'] as String?,
    subjectName: map['subject_name'] as String?,
    subjectPhone: map['subject_phone'] as String?,
    appRoute: map['app_route'] as String?,
    appLabel: map['app_label'] as String?,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    handledByName: map['handled_by_name'] as String?,
    handledAt: DateTime.tryParse(
      map['handled_at'] as String? ?? '',
    )?.toLocal(),
    resolution: map['resolution'] as String?,
    attachmentCount: (map['attachment_count'] as num?)?.toInt() ?? 0,
  );
}

/// What happened when somebody pressed the button.
///
/// A THIRD outcome, and it exists because the other two are both lies here.
///
/// Everywhere else in this app, work that could not be sent is kept and the
/// person is told "saved — it will go when the network returns", and that is
/// the truth and the end of it. An emergency is the one case where it is not
/// enough. The report is still kept — losing it would be worse — but the man
/// pressed that button because he needs somebody to COME, and nobody has been
/// told. If the app answers him with a calm confirmation he will put the phone
/// in his pocket and wait for help that was never called.
///
/// So this case is reported loudly, and says what to do instead.
enum IncidentOutcome {
  /// It reached the operations room. They have been alerted.
  sent,

  /// Kept on the device. **Nobody has been told yet.**
  waitingForNetwork,

  /// It could not even be kept.
  failed,
}

/// A report on its way out, before it has an id.
class PendingIncident {
  const PendingIncident({
    required this.body,
    this.moduleId,
    this.nodeId,
    this.subjectProfileId,
    this.appRoute,
    this.appLabel,
    this.attachments = const [],
  });

  final String body;

  /// What it is about, and every one of these is optional — see 0120. At most
  /// one of the three kinds is ever set, because the form offers them as one
  /// choice rather than as three fields.
  final String? moduleId;
  final String? nodeId;
  final String? subjectProfileId;
  final String? appRoute;
  final String? appLabel;

  final List<PendingAttachment> attachments;
}
