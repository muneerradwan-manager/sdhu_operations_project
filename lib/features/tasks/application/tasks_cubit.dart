import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/offline/outbox.dart';
import '../../../core/offline/save_outcome.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/tasks_outbox.dart';
import '../data/tasks_repository.dart';
import '../domain/personal_task.dart';

enum TasksStatus { loading, ready, error }

class TasksState extends Equatable {
  const TasksState({
    this.status = TasksStatus.loading,
    this.view = TaskView.open,
    this.tasks = const [],
    this.stats = const TaskStats(),
    this.query = '',
    this.priority,
    this.error,
    this.savedAt,
    this.busy = false,
  });

  final TasksStatus status;

  /// Which slice is being read. The screen's segmented bar and this field are
  /// the same fact; the SERVER does the slicing (`my_personal_tasks`, 0118),
  /// because "overdue" is a question about a clock and a state machine and not
  /// something a list already in memory can be filtered into.
  final TaskView view;

  /// The tasks of [view], already ordered — bucket, then deadline, then
  /// priority, then newest. Nothing here re-sorts them.
  final List<PersonalTask> tasks;

  /// The four numbers above the list. Read alongside rather than derived from
  /// [tasks]: the list is one view and the numbers are about all of them.
  final TaskStats stats;

  final String query;
  final TaskPriority? priority;

  final String? error;

  /// When this list was last true, if it is being shown from disk.
  ///
  /// Null on a live read. Carrying the TIME rather than a bare `isStale` flag
  /// is the point: "a saved copy" invites the reader to guess how old, and
  /// standing at a gate with no signal, how old it is is the only thing they
  /// need in order to decide whether to trust it.
  final DateTime? savedAt;

  /// A write is in flight from the list itself — ticking a step, moving a
  /// state from the row. The list stays on screen; only the affected row is
  /// held.
  final bool busy;

  /// The viewer's own notes to themselves — full control.
  List<PersonalTask> get own => [
    for (final t in tasks)
      if (!t.isAssigned) t,
  ];

  /// What somebody with the grant put on the viewer's list.
  List<PersonalTask> get assignedToMe => [
    for (final t in tasks)
      if (t.isAssigned) t,
  ];

  /// Whether any filter narrows what is on screen, for the "clear" affordance
  /// and for deciding whether an empty list means "nothing to do" or "nothing
  /// matches" — two sentences that must never be swapped.
  bool get isFiltered => query.isNotEmpty || priority != null;

  TasksState copyWith({
    TasksStatus? status,
    TaskView? view,
    List<PersonalTask>? tasks,
    TaskStats? stats,
    String? query,
    TaskPriority? priority,
    bool clearPriority = false,
    String? error,
    DateTime? savedAt,
    bool clearSavedAt = false,
    bool? busy,
  }) => TasksState(
    status: status ?? this.status,
    view: view ?? this.view,
    tasks: tasks ?? this.tasks,
    stats: stats ?? this.stats,
    query: query ?? this.query,
    priority: clearPriority ? null : (priority ?? this.priority),
    error: error,
    savedAt: clearSavedAt ? null : (savedAt ?? this.savedAt),
    busy: busy ?? this.busy,
  );

  @override
  List<Object?> get props => [
    status,
    view,
    tasks,
    stats,
    query,
    priority,
    error,
    savedAt,
    busy,
  ];
}

/// One person's own list — «مهامي».
///
/// Assigning and following up live in [TasksBoardCubit] behind their own door,
/// because that is authority and this page is work. The split 0105 made stands;
/// what this class lost since is everything to do with the OTHER screen, which
/// it was carrying in the same state object.
class TasksCubit extends SafeCubit<TasksState> {
  TasksCubit(this._repo) : super(const TasksState()) {
    load();
  }

  final TasksRepository _repo;

  Future<void> load() async {
    try {
      final read = await _repo.fetchMine(
        view: state.view,
        priority: state.priority,
        query: state.query.isEmpty ? null : state.query,
      );

      // The numbers are a nicety and the list is the page. A count that failed
      // must not take down the screen a man is standing somewhere to read, so
      // they are asked for separately and forgiven separately.
      var stats = state.stats;
      try {
        if (!read.isStale) stats = await _repo.fetchStats();
      } catch (_) {}

      emit(
        state.copyWith(
          status: TasksStatus.ready,
          tasks: read.data,
          stats: stats,
          savedAt: read.savedAt,
          clearSavedAt: read.savedAt == null,
          busy: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: TasksStatus.error, error: e.toString()));
    }
  }

  /// Switching the segmented bar. The list empties first rather than showing
  /// the previous view's rows under the new view's heading — briefly wrong is
  /// worse than briefly blank when the heading says «المتأخرة».
  Future<void> setView(TaskView view) async {
    if (view == state.view) return;
    emit(state.copyWith(view: view, tasks: const [], status: TasksStatus.loading));
    await load();
  }

  Future<void> setQuery(String query) async {
    if (query == state.query) return;
    emit(state.copyWith(query: query));
    await load();
  }

  Future<void> setPriority(TaskPriority? priority) async {
    if (priority == state.priority) return;
    emit(
      state.copyWith(priority: priority, clearPriority: priority == null),
    );
    await load();
  }

  Future<void> clearFilters() async {
    if (!state.isFiltered) return;
    emit(state.copyWith(query: '', clearPriority: true));
    await load();
  }

  /// Writes a task onto the caller's own list. Returns null on success, else
  /// the failure.
  ///
  /// Assignment does NOT come through here — see [TasksBoardCubit.assign].
  /// This one queues, because a reminder is written standing somewhere.
  Future<SaveOutcome> create({
    required String title,
    String? description,
    DateTime? dueOn,
    TaskPriority priority = TaskPriority.normal,
    TaskKind kind = TaskKind.task,
    List<String> steps = const [],
  }) async {
    try {
      final sent = await sendOrQueue(
        send: () => _repo.create(
          title: title,
          description: description,
          dueOn: dueOn,
          priority: priority,
          kind: kind,
          steps: steps,
        ),
        kind: TasksOutbox.create,
        payload: TasksOutbox.createPayload(
          title: title,
          description: description,
          dueOn: dueOn,
          priority: priority,
          kind: kind,
          steps: steps,
        ),
        label: title,
      );
      if (sent) await load();
      return sent ? const SaveOutcome.sent() : const SaveOutcome.queued();
    } catch (e) {
      return SaveOutcome.failed(e.toString());
    }
  }

  Future<String?> update({
    required String id,
    required String title,
    String? description,
    DateTime? dueOn,
    TaskPriority? priority,
    TaskKind? kind,
  }) async {
    try {
      await _repo.update(
        id: id,
        title: title,
        description: description,
        dueOn: dueOn,
        priority: priority,
        kind: kind,
      );
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Rewriting the checklist. The full pen only — a man may not add duties to
  /// a duty he was given — which the database enforces and the editor mirrors
  /// by never opening for a task he does not hold the pen over.
  ///
  /// Not queued: this is written sitting down beside the title it belongs to,
  /// and it goes with the edit that carries it.
  Future<String?> setSteps(String taskId, List<String> labels) async {
    try {
      await _repo.setSteps(taskId: taskId, labels: labels);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> delete(PersonalTask task) async {
    try {
      await _repo.delete(task);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Moving a task from the list itself, with no note and no evidence — the
  /// one-tap «بدأت» and «أرسلت للقبول» on the row.
  ///
  /// Anything that needs words goes through the detail screen: the two states
  /// that require a comment (0117) are not offered here at all, so this can
  /// never be the path that discovers `task_comment_required`.
  Future<SaveOutcome> move(PersonalTask task, TaskState next) async {
    if (next.needsComment) {
      return const SaveOutcome.failed('this move needs a comment');
    }
    emit(state.copyWith(busy: true));
    final outcome = await _setState(task, next);
    if (outcome.ok) {
      await load();
    } else {
      emit(state.copyWith(busy: false));
    }
    return outcome;
  }

  /// Ticking one box. Optimistic, and queued: this is the write made with one
  /// thumb in front of the thing, and it must not wait for a round trip to
  /// look as though it happened.
  Future<SaveOutcome> toggleStep(
    PersonalTask task,
    TaskStep step,
    bool isDone,
  ) async {
    final moved = [
      for (final t in state.tasks)
        if (t.id != task.id)
          t
        else
          t.copyWith(
            steps: [
              for (final s in t.steps) s.id == step.id ? s.toggled(isDone) : s,
            ],
          ),
    ];
    emit(state.copyWith(tasks: moved));

    try {
      final sent = await sendOrQueue(
        send: () => _repo.setStepDone(stepId: step.id, isDone: isDone),
        kind: TasksOutbox.step,
        payload: TasksOutbox.stepPayload(stepId: step.id, isDone: isDone),
        label: step.label,
      );
      return sent ? const SaveOutcome.sent() : const SaveOutcome.queued();
    } catch (e) {
      // Put it back. An optimistic tick that silently failed is the worst of
      // both — the box is ticked on his phone and not in the record.
      await load();
      return SaveOutcome.failed(e.toString());
    }
  }

  Future<SaveOutcome> _setState(
    PersonalTask task,
    TaskState next, {
    String? note,
    List<PendingAttachment> attachments = const [],
    List<StoredAttachment> removed = const [],
  }) async {
    try {
      final sent = await sendOrQueue(
        send: () async {
          await _repo.setState(taskId: task.id, state: next, note: note);
          if (attachments.isNotEmpty || removed.isNotEmpty) {
            await _repo.setAttachments(
              taskId: task.id,
              attachments: attachments,
              removed: removed,
            );
          }
        },
        kind: TasksOutbox.state,
        payload: TasksOutbox.statePayload(
          taskId: task.id,
          state: next,
          note: note,
          removed: removed,
        ),
        label: task.title,
        attachments: attachments,
      );
      return sent ? const SaveOutcome.sent() : const SaveOutcome.queued();
    } catch (e) {
      return SaveOutcome.failed(e.toString());
    }
  }

  /// The signed link the attachment views ask for.
  Future<String> signAttachment(
    String path, {
    bool download = false,
    String? downloadName,
  }) => _repo.signedUrl(path, download: download, downloadName: downloadName);

  /// The viewer, for telling "mine" from "assigned" without another read.
  static String? get viewerId => supabase.auth.currentUser?.id;
}
