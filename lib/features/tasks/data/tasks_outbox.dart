import '../../../core/offline/outbox.dart';
import '../../../core/offline/outbox_entry.dart';
import '../domain/personal_task.dart';
import 'tasks_repository.dart';

/// The writes of a personal task that happen in the field.
///
/// 0105 queued exactly one — moving the state — on the rule that the write made
/// standing in front of the thing is the one that must not be lost, and the
/// photograph cannot be retaken. That rule did not change; what changed is how
/// many writes now qualify.
///
/// Queued, because each is done on foot with a thing in front of the person:
///
///   state      moving it, with the note and evidence that came with it.
///   comment    saying what happened, which since 0117 is where the words go.
///   step       ticking one box of a checklist — the one-thumb write.
///   create     a reminder written to oneself, standing somewhere.
///
/// NOT queued, and the omission is the design: assigning to other people,
/// accepting, and returning. Those are decisions taken sitting at a desk on a
/// working connection, and an assignment that arrives six hours after it was
/// written is worse than one that visibly failed to send — the assigner has
/// moved on, and the man receiving it cannot tell whether it is still wanted.
abstract final class TasksOutbox {
  /// Named, never renamed: an entry written by last week's build must be read
  /// by this one.
  static const state = 'personal.task_state';
  static const comment = 'personal.task_comment';
  static const step = 'personal.task_step';
  static const create = 'personal.task_create';

  static void register(Outbox outbox) {
    outbox
      ..register(state, _sendState)
      ..register(comment, _sendComment)
      ..register(step, _sendStep)
      ..register(create, _sendCreate);
  }

  // ------------------------------------------------------------------ state

  static Map<String, dynamic> statePayload({
    required String taskId,
    required TaskState state,
    String? note,
    List<StoredAttachment> removed = const [],
  }) => {
    'task_id': taskId,
    'state': state.dbName,
    'note': note,
    'removed': [for (final attachment in removed) attachment.toMap()],
  };

  static Future<void> _sendState(OutboxEntry entry) async {
    final repo = TasksRepository();
    final payload = entry.payload;
    final taskId = payload['task_id'] as String;

    // Replayable: `set_personal_task_state` returns quietly when the task is
    // already in the state asked for (0117), so an entry sent twice by a flaky
    // network does not come back as `task_transition_not_allowed`.
    await repo.setState(
      taskId: taskId,
      state: TaskState.fromDb(payload['state'] as String?),
      note: payload['note'] as String?,
    );

    final removed = [
      for (final row in (payload['removed'] as List?) ?? const [])
        StoredAttachment.fromMap((row as Map).cast<String, dynamic>()),
    ];
    if (entry.files.isEmpty && removed.isEmpty) return;

    await repo.setAttachments(
      taskId: taskId,
      attachments: [for (final file in entry.files) file.pending],
      removed: removed,
    );
  }

  // ---------------------------------------------------------------- comment

  static Map<String, dynamic> commentPayload({
    required String taskId,
    required String body,
  }) => {'task_id': taskId, 'body': body};

  static Future<void> _sendComment(OutboxEntry entry) async {
    final repo = TasksRepository();
    final taskId = entry.payload['task_id'] as String;

    final commentId = await repo.addComment(
      taskId: taskId,
      body: entry.payload['body'] as String,
    );
    if (entry.files.isEmpty) return;

    // Filed under the comment rather than loose against the task, so that a
    // photograph sent three hours later still lands beside the sentence it was
    // taken to prove.
    await repo.setAttachments(
      taskId: taskId,
      commentId: commentId,
      attachments: [for (final file in entry.files) file.pending],
    );
  }

  // ------------------------------------------------------------------- step

  static Map<String, dynamic> stepPayload({
    required String stepId,
    required bool isDone,
  }) => {'step_id': stepId, 'is_done': isDone};

  static Future<void> _sendStep(OutboxEntry entry) async {
    // Idempotent by nature: setting a box to the value it already holds is the
    // same write, which is why this one needs no guard.
    await TasksRepository().setStepDone(
      stepId: entry.payload['step_id'] as String,
      isDone: entry.payload['is_done'] as bool,
    );
  }

  // ----------------------------------------------------------------- create

  static Map<String, dynamic> createPayload({
    required String title,
    String? description,
    DateTime? dueOn,
    TaskPriority priority = TaskPriority.normal,
    TaskKind kind = TaskKind.task,
    List<String> steps = const [],
  }) => {
    'title': title,
    'description': description,
    'due_on': dueOn?.toIso8601String(),
    'priority': priority.dbName,
    'kind': kind.dbName,
    'steps': steps,
  };

  static Future<void> _sendCreate(OutboxEntry entry) async {
    final payload = entry.payload;
    final due = payload['due_on'] as String?;

    // No profile ids: only a note to ONESELF queues. See the class comment for
    // why assignment does not.
    await TasksRepository().create(
      title: payload['title'] as String,
      description: payload['description'] as String?,
      dueOn: due == null ? null : DateTime.tryParse(due),
      priority: TaskPriority.fromDb(payload['priority'] as String?),
      kind: TaskKind.fromDb(payload['kind'] as String?),
      steps: [
        for (final label in (payload['steps'] as List?) ?? const [])
          label as String,
      ],
    );
  }
}
