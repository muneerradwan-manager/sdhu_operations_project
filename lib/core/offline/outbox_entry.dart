import 'dart:io';

import '../attachments/attachment.dart';

/// How an entry is getting on. Not the same question as whether it succeeded —
/// a queue that only knows "sent" and "not sent" cannot tell a man whose photo
/// is waiting for a signal from a man whose photo is never going to arrive, and
/// those two need different things said to them.
enum OutboxStatus {
  /// Waiting for its turn, or for the network to come back.
  waiting,

  /// Being sent right now.
  sending,

  /// The server refused it for a reason that will not change by asking again —
  /// the permission was withdrawn, the file was deleted, the period closed. It
  /// stays in the queue, out of the retry loop, until somebody is told.
  blocked,
}

/// One attachment held on the device while its entry waits.
///
/// The file is a COPY, made inside the app's own queue directory at the moment
/// it was chosen. It has to be: the original is a camera-roll entry or a temp
/// file the system may clear, and an entry that survives a week of bad signal
/// but points at a photo Android has since swept up has kept the wrong half of
/// the thing.
/// A retry sends the WHOLE operation again rather than resuming where it
/// stopped, and the repositories make that safe without being asked to.
/// `submitReport` and `setTaskAttachments` both upload the files first and
/// insert their rows in one statement at the end, and both number the uploads
/// from what is already in the table. So a run that dies anywhere before that
/// last insert left no rows behind, the next run numbers from the same place,
/// lands on the same storage keys, and `upsert: true` writes over its own
/// half-finished work. Nothing accumulates.
///
/// The window this does NOT close is a run whose insert SUCCEEDED and whose
/// reply was lost on the way back — then the retry does find rows, numbers past
/// them, and the attachments arrive twice. It is narrow, it costs a duplicate
/// photograph rather than a wrong one, and closing it needs a uniqueness
/// constraint in the database that does not exist yet. Recorded rather than
/// papered over.
class OutboxFile {
  const OutboxFile({
    required this.path,
    required this.name,
    required this.kind,
    this.mimeType,
  });

  /// Where the copy lives on this device.
  final String path;

  /// What the person called it — the Arabic name, which is what the reader of
  /// the report will see and what a download is named after.
  final String name;

  final AttachmentKind kind;
  final String? mimeType;

  File get file => File(path);

  /// The shape a repository already knows how to upload.
  PendingAttachment get pending =>
      PendingAttachment(file: file, name: name, kind: kind, mimeType: mimeType);

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'kind': kind.name,
    if (mimeType != null) 'mime_type': mimeType,
  };

  static OutboxFile fromJson(Map<String, dynamic> json) => OutboxFile(
    path: json['path'] as String,
    name: json['name'] as String,
    kind: AttachmentKind.fromDb(json['kind'] as String?),
    mimeType: json['mime_type'] as String?,
  );
}

/// One thing a person did that has not reached the server yet.
///
/// The queue holds INTENTIONS, not HTTP requests: `kind` names an operation the
/// app knows how to perform and `payload` carries its arguments, and sending it
/// means calling the same repository method the online path calls. Queuing raw
/// requests would have frozen today's API into next season's saved entries;
/// this way an entry written by one build is replayed by whatever the current
/// build understands that operation to mean.
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.label,
    this.files = const [],
    this.status = OutboxStatus.waiting,
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastError,
  });

  /// Local and never seen by the server. Ordering is by [createdAt]; this only
  /// has to tell two entries apart.
  final String id;

  /// Which registered operation this is. See `OutboxHandlers`.
  final String kind;

  final Map<String, dynamic> payload;
  final List<OutboxFile> files;
  final DateTime createdAt;

  /// A sentence in the person's own terms — "تقرير مخيم ٧" — so the pending
  /// list says what is waiting rather than how many rows are waiting. Written
  /// at enqueue time, because the screen that could phrase it is the screen
  /// that is about to be closed.
  final String? label;

  final OutboxStatus status;
  final int attempts;

  /// The earliest this should be tried again. Backing off matters more here
  /// than in most queues: the phone is on a congested cell, and an entry
  /// retrying every second is one more thing making it congested.
  final DateTime? nextAttemptAt;

  final String? lastError;

  bool get isBlocked => status == OutboxStatus.blocked;

  /// Whether this is ready to go at [now]. A blocked entry never is — it is
  /// waiting on a person, not on a network.
  bool isDue(DateTime now) {
    if (isBlocked) return false;
    final next = nextAttemptAt;
    return next == null || !next.isAfter(now);
  }

  OutboxEntry copyWith({
    List<OutboxFile>? files,
    OutboxStatus? status,
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttempt = false,
    String? lastError,
    bool clearError = false,
  }) => OutboxEntry(
    id: id,
    kind: kind,
    payload: payload,
    createdAt: createdAt,
    label: label,
    files: files ?? this.files,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: clearNextAttempt ? null : (nextAttemptAt ?? this.nextAttemptAt),
    lastError: clearError ? null : (lastError ?? this.lastError),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'payload': payload,
    'created_at': createdAt.toIso8601String(),
    if (label != null) 'label': label,
    'files': [for (final file in files) file.toJson()],
    'status': status.name,
    'attempts': attempts,
    if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt!.toIso8601String(),
    if (lastError != null) 'last_error': lastError,
  };

  static OutboxEntry fromJson(Map<String, dynamic> json) => OutboxEntry(
    id: json['id'] as String,
    kind: json['kind'] as String,
    payload: ((json['payload'] as Map?) ?? const {}).cast<String, dynamic>(),
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    label: json['label'] as String?,
    files: [
      for (final file in (json['files'] as List?) ?? const [])
        OutboxFile.fromJson((file as Map).cast<String, dynamic>()),
    ],
    // Anything caught mid-send when the app died is waiting again, not sending:
    // nothing is in flight after a process ends, and an entry stuck on
    // `sending` forever would never be picked up again.
    status: switch (json['status'] as String?) {
      'blocked' => OutboxStatus.blocked,
      _ => OutboxStatus.waiting,
    },
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    nextAttemptAt: DateTime.tryParse(json['next_attempt_at'] as String? ?? ''),
    lastError: json['last_error'] as String?,
  );
}
