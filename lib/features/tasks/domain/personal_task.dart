import '../../../core/attachments/attachment.dart';

export '../../../core/attachments/attachment.dart';

/// How a task is going. Mirrors the `task_state` enum (0083, renamed 0105,
/// widened to seven in 0117).
///
/// Three was too few for one reason: the three of them describe only the work,
/// and a task is an EXCHANGE between two people. [blocked] is the assignee
/// saying he cannot proceed and why; [submitted] is him saying he is finished,
/// which on assigned work is a CLAIM and not a conclusion; [returned] is the
/// assigner saying it is not; [cancelled] is the task being withdrawn without
/// the record of it being erased.
///
/// On a person's own list — `createdBy == profileId` — only three of these are
/// ever reachable, and they are 0105's original three. Nobody accepts his own
/// note to himself.
enum TaskState {
  notStarted,
  inProgress,
  blocked,
  submitted,
  done,
  returned,
  cancelled;

  static TaskState fromDb(String? value) => switch (value) {
    'in_progress' => TaskState.inProgress,
    'blocked' => TaskState.blocked,
    'submitted' => TaskState.submitted,
    'done' => TaskState.done,
    'returned' => TaskState.returned,
    'cancelled' => TaskState.cancelled,
    _ => TaskState.notStarted,
  };

  String get dbName => switch (this) {
    TaskState.notStarted => 'not_started',
    TaskState.inProgress => 'in_progress',
    TaskState.blocked => 'blocked',
    TaskState.submitted => 'submitted',
    TaskState.done => 'done',
    TaskState.returned => 'returned',
    TaskState.cancelled => 'cancelled',
  };

  bool get isDone => this == TaskState.done;

  /// Neither finished nor withdrawn — what «مهامي» counts as work.
  bool get isOpen => this != TaskState.done && this != TaskState.cancelled;

  /// Somebody is waiting on the OTHER party. Drawn quieter than open work: a
  /// task in this state is not the reader's move.
  bool get isWaitingOnOther => this == TaskState.submitted;

  /// The two states that assert something and are worthless without the
  /// sentence that comes with them. Mirrors the `task_comment_required` check
  /// in `set_personal_task_state` — the screen asks for the words rather than
  /// letting the server refuse after the fact.
  bool get needsComment =>
      this == TaskState.blocked || this == TaskState.returned;

  /// Where this sits in a list. The server sorts by the same function
  /// (`personal_task_bucket`, 0118); this exists so a list assembled on the
  /// device — an optimistic move, a queued write — sorts the same way rather
  /// than jumping when the next read lands.
  int get bucket => switch (this) {
    TaskState.returned || TaskState.blocked => 0,
    TaskState.inProgress || TaskState.notStarted => 1,
    TaskState.submitted => 2,
    TaskState.done => 3,
    TaskState.cancelled => 4,
  };
}

/// How much it matters. Three, not five (0118).
///
/// Declared high → low so that the enum's own order is the sort order, on both
/// sides: `order by priority asc` in Postgres and [Comparable] here mean the
/// same thing without either restating the rule.
enum TaskPriority {
  high,
  normal,
  low;

  static TaskPriority fromDb(String? value) => switch (value) {
    'high' => TaskPriority.high,
    'low' => TaskPriority.low,
    _ => TaskPriority.normal,
  };

  String get dbName => name;

  /// Whether it is worth drawing at all. The middle of three is the default and
  /// the majority, and a badge on nine rows out of ten labels nothing.
  bool get isNotable => this != TaskPriority.normal;
}

/// What shape of work it is (0118). Three fixed values and no catalog — 0105's
/// lesson, applied before it could be forgotten again.
enum TaskKind {
  task,
  followUp,
  request;

  static TaskKind fromDb(String? value) => switch (value) {
    'follow_up' => TaskKind.followUp,
    'request' => TaskKind.request,
    _ => TaskKind.task,
  };

  String get dbName => switch (this) {
    TaskKind.task => 'task',
    TaskKind.followUp => 'follow_up',
    TaskKind.request => 'request',
  };
}

/// Which slice of a list is being read. Named views rather than a query
/// language: the six things anybody actually asks a task list, and a phone is
/// not a place to compose the seventh.
enum TaskView {
  today,
  week,
  overdue,
  open,
  done,
  all;

  String get dbName => name;
}

/// One box inside a task (`personal_task_steps`, 0118).
class TaskStep {
  const TaskStep({
    required this.id,
    required this.label,
    required this.isDone,
    this.sortOrder = 0,
  });

  final String id;
  final String label;
  final bool isDone;
  final int sortOrder;

  TaskStep toggled(bool value) =>
      TaskStep(id: id, label: label, isDone: value, sortOrder: sortOrder);

  factory TaskStep.fromMap(Map<String, dynamic> map) => TaskStep(
    id: map['id'] as String,
    label: map['label'] as String,
    isDone: (map['is_done'] as bool?) ?? false,
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
  );
}

/// One task on one person's list (`personal_tasks`, 0105; widened 0117–0119).
///
/// The whole design is still one comparison: [createdBy] equal to [profileId]
/// is a task the person wrote for themselves — theirs entirely. Anything else
/// was ASSIGNED, and what its owner may do to it is bounded by [actions], which
/// the SERVER computes and this object only carries.
///
/// That last point is the one rule this class exists to enforce: the transition
/// matrix lives in `personal_task_transition_allowed` (0117) and nowhere else.
/// A second copy in Dart would be a second answer to a question that must have
/// exactly one, and the screen would eventually offer a button the database
/// refuses.
class PersonalTask {
  const PersonalTask({
    required this.id,
    required this.seq,
    required this.profileId,
    required this.createdBy,
    required this.title,
    required this.state,
    this.priority = TaskPriority.normal,
    this.kind = TaskKind.task,
    this.description,
    this.dueOn,
    this.note,
    this.ownerName,
    this.authorName,
    this.batchId,
    this.batchTitle,
    this.startedAt,
    this.submittedAt,
    this.completedAt,
    this.updatedAt,
    this.commentCount = 0,
    this.attachmentCount = 0,
    this.stepsTotal = 0,
    this.stepsDone = 0,
    this.actions = const {},
    this.steps = const [],
    this.attachments = const [],
  });

  final String id;

  /// The number a person says out loud — «م-١٤٢» (0118). Generated, never
  /// entered, and unique across the mission rather than per list, because two
  /// men comparing notes on a radio are not comparing lists.
  final int seq;

  /// Whose list it sits on.
  final String profileId;

  /// Who wrote it. Equal to [profileId] for the common case.
  final String createdBy;

  /// One language, whichever the writer was thinking in — this is a private
  /// list, not the Administration's paperwork.
  final String title;
  final String? description;

  final DateTime? dueOn;

  final TaskState state;
  final TaskPriority priority;
  final TaskKind kind;

  /// The last thing said about it, cached on the row so a list of thirty draws
  /// without joining the thread (0117). The MEMORY is [TaskThreadEntry]; this
  /// is a headline.
  final String? note;

  /// The owner's name, embedded when someone reads what they assigned.
  final String? ownerName;

  /// The author's name, embedded so an assignee can see who is asking.
  final String? authorName;

  /// The decision this came out of, when it came out of one (0118). Null for a
  /// task handed to one person — a batch of one is not a decision that needs a
  /// parent.
  final String? batchId;
  final String? batchTitle;

  final DateTime? startedAt;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  final int commentCount;
  final int attachmentCount;
  final int stepsTotal;
  final int stepsDone;

  /// The states the READER may move this to, right now, as the server worked it
  /// out. Empty is a legitimate answer — a finished task read by somebody with
  /// no pen over it — and the screen draws no buttons rather than grey ones.
  final Set<TaskState> actions;

  /// Filled by the detail read only; the list carries [stepsTotal]/[stepsDone].
  final List<TaskStep> steps;

  /// Evidence filed against the task itself. What was attached to a COMMENT
  /// travels with that comment, in the thread.
  final List<StoredAttachment> attachments;

  /// Whether this task was assigned rather than self-written.
  bool get isAssigned => createdBy != profileId;

  bool get hasSteps => stepsTotal > 0;

  /// Past its date and still owed. Computed against the DEVICE's today, which
  /// is the right clock for this one thing: the person reading is standing
  /// somewhere on that day, and a task that turns red an hour late because the
  /// server is on another calendar is a bug they cannot explain.
  bool get isOverdue {
    final due = dueOn;
    if (due == null || !state.isOpen) return false;
    final now = DateTime.now();
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// How many days late, for saying it in words. Zero when it is not.
  int get daysLate {
    final due = dueOn;
    if (due == null || !state.isOpen) return 0;
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(due).inDays;
    return days > 0 ? days : 0;
  }

  bool can(TaskState next) => actions.contains(next);

  PersonalTask copyWith({
    TaskState? state,
    List<TaskStep>? steps,
    List<StoredAttachment>? attachments,
    Set<TaskState>? actions,
  }) => PersonalTask(
    id: id,
    seq: seq,
    profileId: profileId,
    createdBy: createdBy,
    title: title,
    state: state ?? this.state,
    priority: priority,
    kind: kind,
    description: description,
    dueOn: dueOn,
    note: note,
    ownerName: ownerName,
    authorName: authorName,
    batchId: batchId,
    batchTitle: batchTitle,
    startedAt: startedAt,
    submittedAt: submittedAt,
    completedAt: completedAt,
    updatedAt: updatedAt,
    commentCount: commentCount,
    attachmentCount: attachmentCount,
    stepsTotal: steps?.length ?? stepsTotal,
    stepsDone: steps == null
        ? stepsDone
        : steps.where((s) => s.isDone).length,
    actions: actions ?? this.actions,
    steps: steps ?? this.steps,
    attachments: attachments ?? this.attachments,
  );

  /// One row of `personal_task_row_json` (0118) — the shape every read returns,
  /// list and detail alike, so there is one parser and not two.
  factory PersonalTask.fromMap(Map<String, dynamic> map) => PersonalTask(
    id: map['id'] as String,
    seq: (map['seq'] as num?)?.toInt() ?? 0,
    profileId: map['profile_id'] as String,
    createdBy: map['created_by'] as String,
    title: map['title'] as String,
    description: map['description'] as String?,
    dueOn: _date(map['due_on']),
    state: TaskState.fromDb(map['state'] as String?),
    priority: TaskPriority.fromDb(map['priority'] as String?),
    kind: TaskKind.fromDb(map['kind'] as String?),
    note: map['note'] as String?,
    ownerName: map['owner_name'] as String?,
    authorName: map['author_name'] as String?,
    batchId: map['batch_id'] as String?,
    batchTitle: map['batch_title'] as String?,
    startedAt: _stamp(map['started_at']),
    submittedAt: _stamp(map['submitted_at']),
    completedAt: _stamp(map['completed_at']),
    updatedAt: _stamp(map['updated_at']),
    commentCount: (map['comment_count'] as num?)?.toInt() ?? 0,
    attachmentCount: (map['attachment_count'] as num?)?.toInt() ?? 0,
    stepsTotal: (map['steps_total'] as num?)?.toInt() ?? 0,
    stepsDone: (map['steps_done'] as num?)?.toInt() ?? 0,
    actions: {
      for (final action in (map['actions'] as List?) ?? const [])
        TaskState.fromDb(action as String?),
    },
    steps: [
      for (final row in (map['steps'] as List?) ?? const [])
        TaskStep.fromMap((row as Map).cast<String, dynamic>()),
    ],
    attachments: [
      for (final row in (map['attachments'] as List?) ?? const [])
        StoredAttachment.fromMap((row as Map).cast<String, dynamic>()),
    ],
  );

  static (int done, int total) progressOf(List<PersonalTask> tasks) => (
    tasks.where((t) => t.state.isDone).length,
    tasks.where((t) => t.state != TaskState.cancelled).length,
  );
}

/// One decision that was handed to several people (`personal_task_batches`,
/// 0118), with what it adds up to.
///
/// The numbers arrive already counted (`my_task_batches`) rather than being
/// derived from a list of rows the screen would otherwise have to hold: the
/// follow-up page shows twenty decisions and opens one.
class TaskBatch {
  const TaskBatch({
    required this.id,
    required this.title,
    required this.total,
    required this.done,
    this.dueOn,
    this.createdAt,
    this.submitted = 0,
    this.blocked = 0,
    this.overdue = 0,
  });

  final String id;
  final String title;
  final DateTime? dueOn;
  final DateTime? createdAt;

  final int total;
  final int done;

  /// Waiting on the READER — these are the ones the follow-up screen exists
  /// for, and the only number on it that is a job rather than a fact.
  final int submitted;
  final int blocked;
  final int overdue;

  double get progress => total == 0 ? 0 : done / total;
  bool get isComplete => total > 0 && done == total;

  factory TaskBatch.fromMap(Map<String, dynamic> map) => TaskBatch(
    id: map['id'] as String,
    title: map['title'] as String,
    dueOn: _date(map['due_on']),
    createdAt: _stamp(map['created_at']),
    total: (map['total'] as num?)?.toInt() ?? 0,
    done: (map['done'] as num?)?.toInt() ?? 0,
    submitted: (map['submitted'] as num?)?.toInt() ?? 0,
    blocked: (map['blocked'] as num?)?.toInt() ?? 0,
    overdue: (map['overdue'] as num?)?.toInt() ?? 0,
  );
}

/// The four numbers on the home card (`my_task_stats`, 0119).
class TaskStats {
  const TaskStats({
    this.open = 0,
    this.overdue = 0,
    this.review = 0,
    this.done = 0,
  });

  final int open;
  final int overdue;

  /// Work the reader asked for that somebody says is finished. The only one of
  /// the four that is somebody else waiting on THEM.
  final int review;
  final int done;

  bool get isEmpty => open == 0 && overdue == 0 && review == 0 && done == 0;

  factory TaskStats.fromMap(Map<String, dynamic> map) => TaskStats(
    open: (map['open_count'] as num?)?.toInt() ?? 0,
    overdue: (map['overdue_count'] as num?)?.toInt() ?? 0,
    review: (map['review_count'] as num?)?.toInt() ?? 0,
    done: (map['done_count'] as num?)?.toInt() ?? 0,
  );
}

DateTime? _date(Object? raw) =>
    raw == null ? null : DateTime.tryParse(raw as String);

DateTime? _stamp(Object? raw) =>
    raw == null ? null : DateTime.tryParse(raw as String)?.toLocal();
