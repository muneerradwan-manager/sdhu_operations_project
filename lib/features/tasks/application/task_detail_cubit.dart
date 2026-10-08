import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/offline/outbox.dart';
import '../../../core/offline/save_outcome.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/tasks_outbox.dart';
import '../data/tasks_repository.dart';
import '../domain/personal_task.dart';
import '../domain/task_thread.dart';

enum TaskDetailStatus { loading, ready, error, gone }

class TaskDetailState extends Equatable {
  const TaskDetailState({
    this.status = TaskDetailStatus.loading,
    this.task,
    this.thread = const [],
    this.error,
    this.busy = false,
  });

  final TaskDetailStatus status;
  final PersonalTask? task;

  /// Said and happened, oldest first, as the server merged them.
  final List<TaskThreadEntry> thread;

  final String? error;
  final bool busy;

  TaskDetailState copyWith({
    TaskDetailStatus? status,
    PersonalTask? task,
    List<TaskThreadEntry>? thread,
    String? error,
    bool? busy,
  }) => TaskDetailState(
    status: status ?? this.status,
    task: task ?? this.task,
    thread: thread ?? this.thread,
    error: error,
    busy: busy ?? this.busy,
  );

  @override
  List<Object?> get props => [status, task, thread, error, busy];
}

/// One task, open.
///
/// This is where every move that needs WORDS happens — «متعثّرة» and «مُعادة»
/// cannot be made anywhere else, because both are assertions that are worthless
/// without the sentence, and the server refuses them empty
/// (`task_comment_required`, 0117).
///
/// The cubit never decides what may be pressed. [PersonalTask.actions] arrives
/// from `personal_task_actions`, computed by the same function that will be
/// asked again when the write lands, so the buttons on screen and the answer
/// the database gives cannot disagree.
class TaskDetailCubit extends SafeCubit<TaskDetailState> {
  TaskDetailCubit(this._repo, this.taskId) : super(const TaskDetailState()) {
    TaskThreadEntry.viewer = supabase.auth.currentUser?.id;
    load();
  }

  final TasksRepository _repo;
  final String taskId;

  Future<void> load() async {
    try {
      // Together: a thread without its task draws no header, and a task
      // without its thread would flicker one in a moment later.
      final results = await Future.wait([
        _repo.fetchOne(taskId),
        _repo.fetchThread(taskId),
      ]);
      emit(
        state.copyWith(
          status: TaskDetailStatus.ready,
          task: results[0] as PersonalTask,
          thread: results[1] as List<TaskThreadEntry>,
          busy: false,
        ),
      );
    } catch (e) {
      // A task that was withdrawn or deleted while this page was open. Its own
      // status, because "not found" wants "this is gone" and a retry button
      // would keep asking a question that has been answered.
      final gone = e.toString().contains('not allowed to read this task') ||
          e.toString().contains('task_not_found');
      emit(
        state.copyWith(
          status: gone ? TaskDetailStatus.gone : TaskDetailStatus.error,
          error: e.toString(),
          busy: false,
        ),
      );
    }
  }

  /// Moving the task, with whatever was said and attached.
  ///
  /// Kept for sending later if the network is what stopped it — this is the
  /// write made standing in front of the thing, and the photograph cannot be
  /// retaken (see [TasksOutbox]).
  Future<SaveOutcome> move(
    TaskState next, {
    String? note,
    List<PendingAttachment> attachments = const [],
    List<StoredAttachment> removed = const [],
  }) async {
    final task = state.task;
    if (task == null) return const SaveOutcome.failed('no task');

    final body = note?.trim();
    if (next.needsComment && (body == null || body.isEmpty)) {
      return const SaveOutcome.failed('task_comment_required');
    }

    emit(state.copyWith(busy: true));
    try {
      final sent = await sendOrQueue(
        send: () async {
          await _repo.setState(
            taskId: task.id,
            state: next,
            note: (body == null || body.isEmpty) ? null : body,
          );
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
          note: (body == null || body.isEmpty) ? null : body,
          removed: removed,
        ),
        label: task.title,
        attachments: attachments,
      );

      if (sent) {
        await load();
      } else {
        // Queued: the screen shows the move as made, because from the person's
        // side it IS made — the app has taken responsibility for the rest. The
        // permitted actions are dropped rather than guessed at: what he may do
        // next is the server's answer, and there is no server right now.
        emit(
          state.copyWith(
            task: task.copyWith(state: next, actions: const {}),
            busy: false,
          ),
        );
      }
      return sent ? const SaveOutcome.sent() : const SaveOutcome.queued();
    } catch (e) {
      emit(state.copyWith(busy: false));
      return SaveOutcome.failed(e.toString());
    }
  }

  /// Saying something without moving anything.
  Future<SaveOutcome> comment(
    String body, {
    List<PendingAttachment> attachments = const [],
  }) async {
    final task = state.task;
    final text = body.trim();
    if (task == null || text.isEmpty) {
      return const SaveOutcome.failed('task_comment_required');
    }

    emit(state.copyWith(busy: true));
    try {
      final sent = await sendOrQueue(
        send: () async {
          final commentId = await _repo.addComment(
            taskId: task.id,
            body: text,
          );
          if (attachments.isNotEmpty) {
            await _repo.setAttachments(
              taskId: task.id,
              commentId: commentId,
              attachments: attachments,
            );
          }
        },
        kind: TasksOutbox.comment,
        payload: TasksOutbox.commentPayload(taskId: task.id, body: text),
        label: task.title,
        attachments: attachments,
      );
      if (sent) await load();
      if (!sent) emit(state.copyWith(busy: false));
      return sent ? const SaveOutcome.sent() : const SaveOutcome.queued();
    } catch (e) {
      emit(state.copyWith(busy: false));
      return SaveOutcome.failed(e.toString());
    }
  }

  /// Ticking one box. Optimistic and queued, for the reason [TasksCubit] gives.
  Future<SaveOutcome> toggleStep(TaskStep step, bool isDone) async {
    final task = state.task;
    if (task == null) return const SaveOutcome.failed('no task');

    emit(
      state.copyWith(
        task: task.copyWith(
          steps: [
            for (final s in task.steps) s.id == step.id ? s.toggled(isDone) : s,
          ],
        ),
      ),
    );

    try {
      final sent = await sendOrQueue(
        send: () => _repo.setStepDone(stepId: step.id, isDone: isDone),
        kind: TasksOutbox.step,
        payload: TasksOutbox.stepPayload(stepId: step.id, isDone: isDone),
        label: step.label,
      );
      return sent ? const SaveOutcome.sent() : const SaveOutcome.queued();
    } catch (e) {
      await load();
      return SaveOutcome.failed(e.toString());
    }
  }

  /// Correcting the task itself — its wording, its date, how urgent it is.
  ///
  /// The full pen only, and not queued: this is a desk edit. Changing what a
  /// task SAYS six hours after somebody read the old wording and acted on it is
  /// worse than an edit that visibly failed to save.
  Future<String?> update({
    required String title,
    String? description,
    DateTime? dueOn,
    TaskPriority? priority,
    TaskKind? kind,
    List<String>? steps,
  }) async {
    emit(state.copyWith(busy: true));
    try {
      await _repo.update(
        id: taskId,
        title: title,
        description: description,
        dueOn: dueOn,
        priority: priority,
        kind: kind,
      );
      // Second call, and only when the caller says they changed: rewriting the
      // list sends every label back, and doing that for the sake of a corrected
      // spelling in the title would touch somebody's ticks for nothing.
      if (steps != null) {
        await _repo.setSteps(taskId: taskId, labels: steps);
      }
      await load();
      return null;
    } catch (e) {
      emit(state.copyWith(busy: false));
      return e.toString();
    }
  }

  /// Rewriting the checklist alone. The full pen only — a man may not add
  /// duties to a duty he was given — which the database enforces and the
  /// screen mirrors.
  Future<String?> setSteps(List<String> labels) async {
    try {
      await _repo.setSteps(taskId: taskId, labels: labels);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Handing it to somebody else. Not queued: this is a desk decision, and one
  /// that arrives hours late would move work to a man who has since been asked
  /// to do something else.
  Future<String?> reassign(String profileId) async {
    emit(state.copyWith(busy: true));
    try {
      await _repo.reassign(taskId: taskId, profileId: profileId);
      await load();
      return null;
    } catch (e) {
      emit(state.copyWith(busy: false));
      return e.toString();
    }
  }

  Future<String?> delete() async {
    final task = state.task;
    if (task == null) return null;
    try {
      await _repo.delete(task);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> signAttachment(
    String path, {
    bool download = false,
    String? downloadName,
  }) => _repo.signedUrl(path, download: download, downloadName: downloadName);
}
