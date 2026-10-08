import '../../../core/attachments/attachment.dart';

export '../../../core/attachments/attachment.dart';

/// A photo, a video, a voice note or a document sent with a notification.
///
/// The same shape everything attached in this app has: [path] points into the
/// private `notifications` bucket, and nothing is readable from it without a
/// signed URL, minted on demand for the recipient.
typedef NotificationAttachment = StoredAttachment;

/// What a notification is about, as far as the inbox is concerned.
///
/// Three, and not one per database `type`: the reader is not sorting by trigger
/// name, they are answering "is this something on fire, something about a file
/// I am on, or an announcement". Every new `type` the database learns falls
/// into one of the three without this list changing.
enum NotificationKind {
  /// An urgent report from the field. The one kind drawn in the error colour,
  /// and the reason the inbox can be filtered at all.
  incident,

  /// About an operational file — an assignment, a broadcast to its members, a
  /// reminder that a report on it is late.
  module,

  /// A message to everybody, about nothing in particular. Points nowhere, and
  /// must not pretend otherwise.
  broadcast,
}

/// Where a tap lands.
///
/// Named apart from [NotificationKind] because they are not the same question
/// and will not stay in step: a future kind may be worth drawing differently
/// and still have nowhere to go.
enum NotificationDestination { none, module, incident }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.readAt,
    required this.createdAt,
    required this.groupId,
    this.attachments = const [],
    this.data = const {},
  });

  final String id;

  /// The send this row belongs to. One id shared by every recipient of a
  /// broadcast, and what its attachments hang off.
  final String groupId;

  final String title;
  final String? body;
  final DateTime? readAt;
  final DateTime createdAt;

  /// What came with it. Fetched alongside rather than embedded: the inbox is a
  /// realtime stream, and a stream cannot carry a joined table.
  final List<NotificationAttachment> attachments;

  /// What the notification was ABOUT, as the trigger that raised it wrote it:
  /// a `type` and whatever identifies the thing — `module_id`, `node_id`,
  /// `role_id`. Carried through so a tap can open it. Empty for a notification
  /// that points nowhere, which a plain broadcast does.
  final Map<String, dynamic> data;

  /// The file this notification is about, when it is about one.
  ///
  /// An assignment ('you were put into this file'), a broadcast to a file's
  /// members and an overdue-report reminder are all about the same place, so
  /// all three open it. A general broadcast names nothing and returns null.
  String? get moduleId => moduleIdIn(data);

  /// The kinds that carry a file to open.
  ///
  /// An allow-list rather than "any `data` with a `module_id` in it": the key
  /// appears on notifications that are about something else in the file, and a
  /// tap that opens the wrong screen is worse than a tap that does nothing.
  static const _typesWithModule = {
    'module_assigned',
    'module_broadcast',
    // Written by the scheduled pass in migration 0086. The reminder is only
    // useful if it opens the file it is about — the whole point is to be one
    // tap from filing the thing that is late.
    'report_overdue',
  };

  /// The same rule, asked of a bare map.
  ///
  /// A push carries these two keys as well, and a notification tapped in the
  /// phone's own tray has to reach the same file as the identical row tapped in
  /// the inbox. Two copies of this rule would be two answers the first time one
  /// of them was extended.
  static String? moduleIdIn(Map<String, dynamic> data) {
    if (!_typesWithModule.contains(data['type'])) return null;
    final id = data['module_id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// The urgent report this notification announces, when it announces one.
  ///
  /// An emergency's photographs are part of the REPORT rather than part of the
  /// message about it: `raise_incident` files them under `incident_attachments`
  /// in the `incidents` bucket, and writes these inbox rows with no attachments
  /// of their own. So a "بلاغ عاجل" whose group holds nothing is not a report
  /// without a photograph — it is a photograph kept somewhere else, and this is
  /// what says where to go and look for it.
  String? get incidentId => incidentIdIn(data);

  /// The same rule, asked of a bare map — see [moduleIdIn] for why it has to
  /// exist twice over.
  ///
  /// An alarm arrives twice: as an inbox row, and as a push in the phone's own
  /// tray. Tapping either is the same act and must reach the same register.
  static String? incidentIdIn(Map<String, dynamic> data) {
    if (data['type'] != 'incident') return null;
    final id = data['incident_id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// What this notification IS, which is the first thing a reader wants from
  /// it and the last thing the old card said.
  ///
  /// Every row in the inbox was drawn with the same bell in the same colour: a
  /// bus that has overturned in منى looked exactly like a message announcing
  /// that a form had been published. The kind is what lets the card stop
  /// pretending those are the same event.
  NotificationKind get kind {
    if (incidentId != null) return NotificationKind.incident;
    if (moduleId != null) return NotificationKind.module;
    return NotificationKind.broadcast;
  }

  /// Where tapping this goes.
  ///
  /// The report comes FIRST when a row is both — an alarm carries `module_id`
  /// as well, and the file is the place the emergency happened rather than the
  /// emergency. Somebody woken by "بلاغ عاجل" is going to the register to
  /// telephone the man, not to the file to read its fields.
  NotificationDestination get destination => switch (kind) {
    NotificationKind.incident => NotificationDestination.incident,
    NotificationKind.module => NotificationDestination.module,
    NotificationKind.broadcast => NotificationDestination.none,
  };

  /// Whether tapping this has anywhere to go.
  bool get hasTarget => destination != NotificationDestination.none;

  /// The one kind the inbox can be filtered down to.
  bool get isIncident => kind == NotificationKind.incident;

  bool get isRead => readAt != null;

  List<NotificationAttachment> get images =>
      attachments.where((a) => a.kind == AttachmentKind.image).toList();

  List<NotificationAttachment> get others =>
      attachments.where((a) => a.kind != AttachmentKind.image).toList();

  /// The same notification, read now. Used to show the change before the write
  /// comes back: the server is the truth, but a tap should not look ignored for
  /// three seconds while it says so.
  AppNotification markedRead() => AppNotification(
    id: id,
    groupId: groupId,
    title: title,
    body: body,
    readAt: readAt ?? DateTime.now(),
    createdAt: createdAt,
    attachments: attachments,
    data: data,
  );

  AppNotification withAttachments(List<NotificationAttachment> attachments) =>
      AppNotification(
        id: id,
        groupId: groupId,
        title: title,
        body: body,
        readAt: readAt,
        createdAt: createdAt,
        attachments: attachments,
        data: data,
      );

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
    id: map['id'] as String,
    groupId: (map['group_id'] as String?) ?? map['id'] as String,
    title: map['title'] as String,
    body: map['body'] as String?,
    // `.toLocal()` because the server speaks UTC and these are shown to a
    // person: without it every inbox time was three hours out in Saudi Arabia.
    readAt: map['read_at'] == null
        ? null
        : DateTime.parse(map['read_at'] as String).toLocal(),
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    attachments: ((map['notification_attachments'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(NotificationAttachment.fromMap)
        .toList(),
    data: Map<String, dynamic>.from(
      (map['data'] as Map?) ?? const <String, dynamic>{},
    ),
  );
}

/// One day of the inbox: the day itself, and what arrived on it.
class NotificationDay {
  const NotificationDay({required this.day, required this.items});

  /// Midnight of the day these arrived on, in the reader's own time zone —
  /// which is the only place the question means anything. A notification sent
  /// at 01:30 in Mecca belongs to that morning for the man who was woken by it,
  /// whatever date UTC was on at the time.
  final DateTime day;

  final List<AppNotification> items;

  /// The inbox cut into days.
  ///
  /// A hundred rows of "21/08 09:14, 21/08 09:02, 20/08 22:40" is a wall of
  /// numbers to be read one line at a time; the eye cannot see where yesterday
  /// started without doing the arithmetic itself. Cutting it into days moves
  /// that work into the headings, where it is done once.
  ///
  /// Order follows [items], which arrives newest first — so the days come out
  /// newest first too, and a row that lands out of order joins the day it
  /// belongs to rather than opening a second copy of it further down.
  static List<NotificationDay> byDay(List<AppNotification> items) {
    final byDay = <DateTime, List<AppNotification>>{};
    for (final n in items) {
      final at = n.createdAt;
      (byDay[DateTime(at.year, at.month, at.day)] ??= []).add(n);
    }
    return [
      for (final entry in byDay.entries)
        NotificationDay(day: entry.key, items: entry.value),
    ];
  }
}
