import 'personal_task.dart';

/// What kind of line this is in the record.
///
/// The set is the `kind` column of `personal_task_events` (0117) plus the one
/// value that table does not carry — a comment somebody wrote on its own,
/// which is a row of `personal_task_comments`. Both come back from
/// `personal_task_thread` in one list, because that is what a person
/// remembers: not "the comments" and separately "the history", but what went
/// on.
enum TaskEntryKind {
  created,
  state,
  comment,
  reassigned,
  due,
  priority,
  escalated;

  static TaskEntryKind fromDb(String? value) => switch (value) {
    'created' => TaskEntryKind.created,
    'state' => TaskEntryKind.state,
    'reassigned' => TaskEntryKind.reassigned,
    'due' => TaskEntryKind.due,
    'priority' => TaskEntryKind.priority,
    'escalated' => TaskEntryKind.escalated,
    _ => TaskEntryKind.comment,
  };
}

/// One line in a task's thread.
///
/// A transition that carried a sentence is ONE entry, not two: [toState] says
/// what happened and [body] says what was said about it. Splitting them would
/// read as the man having said it and then, separately, done it — and the
/// commonest pair in this system, «أعادها وقال: الكشف ناقص», is exactly one act.
class TaskThreadEntry {
  const TaskThreadEntry({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.actorId,
    this.actorName,
    this.body,
    this.fromState,
    this.toState,
    this.payload = const {},
    this.attachments = const [],
  });

  final String id;
  final TaskEntryKind kind;
  final DateTime createdAt;

  /// Null for the escalation lines, which nobody wrote — the system noticed
  /// (0119). The screen draws those without a name rather than inventing one.
  final String? actorId;
  final String? actorName;

  /// The words, where there were any.
  final String? body;

  final TaskState? fromState;
  final TaskState? toState;

  /// Whatever the kind needed and no column was worth carrying: the two
  /// profile ids of a reassignment, the two dates of a moved deadline.
  final Map<String, dynamic> payload;

  final List<StoredAttachment> attachments;

  bool get isMine => actorId != null && actorId == _viewerId;

  /// Whether this line is somebody talking, as against something happening.
  /// The screen gives these more room — they are the only lines with anything
  /// to read.
  bool get isSpeech => (body?.trim().isNotEmpty ?? false);

  static String? _viewerId;

  /// Told once, by the cubit, rather than threaded through every entry: who
  /// the reader is does not change inside a screen, and passing it into a
  /// hundred constructor calls would only give it a hundred chances to be
  /// wrong.
  static set viewer(String? id) => _viewerId = id;

  factory TaskThreadEntry.fromMap(Map<String, dynamic> map) => TaskThreadEntry(
    id: map['entry_id'] as String,
    kind: TaskEntryKind.fromDb(map['kind'] as String?),
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    actorId: map['actor_id'] as String?,
    actorName: map['actor_name'] as String?,
    body: map['body'] as String?,
    fromState: map['from_state'] == null
        ? null
        : TaskState.fromDb(map['from_state'] as String?),
    toState: map['to_state'] == null
        ? null
        : TaskState.fromDb(map['to_state'] as String?),
    payload: ((map['payload'] as Map?) ?? const {}).cast<String, dynamic>(),
    attachments: [
      for (final row in (map['attachments'] as List?) ?? const [])
        StoredAttachment.fromMap((row as Map).cast<String, dynamic>()),
    ],
  );
}
