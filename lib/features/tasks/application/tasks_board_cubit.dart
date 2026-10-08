import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../seasons/data/seasons_repository.dart';
import '../data/tasks_repository.dart';
import '../domain/personal_task.dart';

enum BoardStatus { loading, ready, error }

/// The three ways the follow-up screen answers the same set of rows.
///
/// Not three screens: the difference between them is only which question the
/// reader has, and all three are asked about one list.
enum BoardView {
  /// By state — the columns. The one view that earns a board, because its
  /// reader is sitting down.
  board,

  /// By decision (`personal_task_batches`, 0118). The view 0105 could not
  /// draw: «استلام الكشوف — أنجزها ٤ من ٦».
  batches,

  /// By person. 0105's behaviour, kept, because "what is سعد carrying?" is
  /// still a real question.
  people,
}

class TasksBoardState extends Equatable {
  const TasksBoardState({
    this.status = BoardStatus.loading,
    this.view = BoardView.board,
    this.tasks = const [],
    this.batches = const [],
    this.seasonId,
    this.everyone = false,
    this.query = '',
    this.error,
  });

  final BoardStatus status;
  final BoardView view;

  /// Everything assigned that the reader may see — theirs, or the mission's
  /// with `tasks.view_all`.
  final List<PersonalTask> tasks;
  final List<TaskBatch> batches;

  /// The season in force, for the roster the assignment picker reads. A task
  /// itself has no season; the ROSTER does — «من في البعثة هذا الموسم» is the
  /// question that page answers, along with which files each of them serves in.
  final String? seasonId;

  /// Whether the wider read is switched on. Offered only to holders of
  /// `tasks.view_all`; false is «ما أسندتُه أنا».
  final bool everyone;

  final String query;
  final String? error;

  /// Work waiting on THIS reader's decision. The only number on the page that
  /// is a job rather than a fact, which is why it is counted out of the rows
  /// rather than left for the eye to find in a column.
  List<PersonalTask> get review => [
    for (final t in tasks)
      if (t.state == TaskState.submitted) t,
  ];

  List<PersonalTask> inState(TaskState state) => [
    for (final t in tasks)
      if (t.state == state) t,
  ];

  /// One card per person, in the order their newest task arrived — the same
  /// list merged would let one man's unfinished work hide behind another's
  /// ticks.
  Map<String, List<PersonalTask>> get byPerson {
    final grouped = <String, List<PersonalTask>>{};
    for (final task in tasks) {
      (grouped[task.profileId] ??= []).add(task);
    }
    return grouped;
  }

  int get overdueCount => tasks.where((t) => t.isOverdue).length;

  TasksBoardState copyWith({
    BoardStatus? status,
    BoardView? view,
    List<PersonalTask>? tasks,
    List<TaskBatch>? batches,
    String? seasonId,
    bool? everyone,
    String? query,
    String? error,
  }) => TasksBoardState(
    status: status ?? this.status,
    view: view ?? this.view,
    tasks: tasks ?? this.tasks,
    batches: batches ?? this.batches,
    seasonId: seasonId ?? this.seasonId,
    everyone: everyone ?? this.everyone,
    query: query ?? this.query,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    view,
    tasks,
    batches,
    seasonId,
    everyone,
    query,
    error,
  ];
}

/// Assigning tasks and following them up — the authority half of the system,
/// behind `tasks.assign` (the router guards the door).
class TasksBoardCubit extends SafeCubit<TasksBoardState> {
  TasksBoardCubit(this._repo) : super(const TasksBoardState()) {
    load();
  }

  final TasksRepository _repo;

  Future<void> load() async {
    try {
      // Everything, not one view's slice: the board draws five columns off one
      // read, and asking five times for what is at most a few hundred rows
      // would be five round trips to redraw the same screen.
      final tasks = await _repo.fetchAssigned(
        everyone: state.everyone,
        view: TaskView.all,
        query: state.query.isEmpty ? null : state.query,
      );

      // The batches are the reader's own decisions and never the mission's —
      // there is no such thing as following up somebody else's decision.
      var batches = state.batches;
      try {
        batches = await _repo.fetchBatches();
      } catch (_) {}

      // The season is only the roster the picker reads; failing to find one
      // must not take the list of assignments down with it.
      var seasonId = state.seasonId;
      if (seasonId == null) {
        try {
          seasonId = (await SeasonsRepository().fetchCurrentSeason())?.id;
        } catch (_) {}
      }

      emit(
        state.copyWith(
          status: BoardStatus.ready,
          tasks: tasks,
          batches: batches,
          seasonId: seasonId,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: BoardStatus.error, error: e.toString()));
    }
  }

  void setView(BoardView view) {
    if (view == state.view) return;
    emit(state.copyWith(view: view));
  }

  Future<void> setEveryone(bool everyone) async {
    if (everyone == state.everyone) return;
    emit(
      state.copyWith(
        everyone: everyone,
        tasks: const [],
        status: BoardStatus.loading,
      ),
    );
    await load();
  }

  Future<void> setQuery(String query) async {
    if (query == state.query) return;
    emit(state.copyWith(query: query));
    await load();
  }

  /// Writes a task onto everybody [profileIds] names. Never queued: assignment
  /// is a desk decision, and one arriving six hours later is worse than one
  /// that visibly failed to send.
  Future<String?> assign({
    required String title,
    String? description,
    DateTime? dueOn,
    required Set<String> profileIds,
    TaskPriority priority = TaskPriority.normal,
    TaskKind kind = TaskKind.task,
    List<String> steps = const [],
  }) async {
    try {
      await _repo.create(
        title: title,
        description: description,
        dueOn: dueOn,
        profileIds: profileIds,
        priority: priority,
        kind: kind,
        steps: steps,
      );
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Accepting everything in a batch that is claimed finished — the «اقبل
  /// الجاهز ٢» button.
  ///
  /// One by one rather than in bulk on the server, and deliberately: each
  /// acceptance is a separate decision that writes its own event and sends its
  /// own notification, and a bulk endpoint would be a way of making six of them
  /// without reading any. What this saves is six taps, not six judgements.
  ///
  /// Returns how many went through; a refusal on one does not stop the rest.
  Future<int> acceptAll(List<PersonalTask> tasks) async {
    var accepted = 0;
    for (final task in tasks) {
      if (!task.can(TaskState.done)) continue;
      try {
        await _repo.setState(taskId: task.id, state: TaskState.done);
        accepted++;
      } catch (_) {}
    }
    if (accepted > 0) await load();
    return accepted;
  }

  /// Nudging whoever has not finished. One notification each, and nothing is
  /// written to the tasks themselves: a reminder is not a state.
  Future<int> nudge(List<PersonalTask> tasks) async {
    var sent = 0;
    for (final task in tasks) {
      if (!task.state.isOpen) continue;
      try {
        await _repo.addComment(
          taskId: task.id,
          body: 'تذكير بالمهمة.',
        );
        sent++;
      } catch (_) {}
    }
    if (sent > 0) await load();
    return sent;
  }

  Future<List<PersonalTask>> batchTasks(String batchId) =>
      _repo.fetchBatchTasks(batchId);

  Future<String> signAttachment(
    String path, {
    bool download = false,
    String? downloadName,
  }) => _repo.signedUrl(path, download: download, downloadName: downloadName);
}
