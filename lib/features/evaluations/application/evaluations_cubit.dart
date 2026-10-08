import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/utils/arabic_search.dart';
import '../data/evaluations_repository.dart';
import '../domain/evaluation.dart';

enum EvaluationsStatus { loading, ready, error }

/// Whose evaluations the screen is showing.
///
/// Two lists, two doors, and not one screen with a switch on it: [mine] is
/// everybody's and hangs under العام — it is the errands this person was given —
/// while [all] asks for `evaluations.view` and hangs under الإدارة. The same
/// screen answers both; what differs is which question it asked the server, and
/// the server refuses [all] to whoever may not ask it.
///
/// They are also drawn differently, and that follows from the same split. A
/// person's own list is a list of errands, one card each, because each one is
/// a separate thing HE must go and do. The register is not a list of rows at
/// all — it is a shelf of things under judgement, and twenty people appraising
/// one file is one entry on it. See [EvaluationsState.isGrouped].
enum EvaluationsScope { mine, all }

class EvaluationsState extends Equatable {
  const EvaluationsState({
    this.scope = EvaluationsScope.mine,
    this.status = EvaluationsStatus.loading,
    this.evaluations = const [],
    this.subjects = const [],
    this.query = '',
    this.target,
    this.filterStatus,
    this.error,
  });

  final EvaluationsScope scope;
  final EvaluationsStatus status;

  /// The flat errands, read only in [EvaluationsScope.mine].
  final List<Evaluation> evaluations;

  /// The register's own unit, read only in [EvaluationsScope.all].
  final List<EvaluationSubject> subjects;

  final String query;
  final EvaluationTarget? target;
  final EvaluationStatus? filterStatus;
  final String? error;

  /// Whether this screen is drawing subjects rather than sheets.
  bool get isGrouped => scope == EvaluationsScope.all;

  bool get isNarrowed =>
      query.trim().isNotEmpty || target != null || filterStatus != null;

  /// The errands after the reader's narrowing.
  ///
  /// The server can narrow too — `evaluations_list` takes the same three — but
  /// it is asked only on the first read. A hundred rows are already in hand and
  /// a round trip per keystroke would be slower and no more correct.
  List<Evaluation> get visible => evaluations.where((e) {
    if (target != null && e.target != target) return false;
    if (filterStatus != null && e.status != filterStatus) return false;
    return arabicMatchesAll([
      e.targetLabel,
      e.templateTitle,
      e.evaluatorName,
      e.note,
    ], query);
  }).toList();

  /// The same narrowing over the register's cards.
  ///
  /// The status chips mean one level up here, and the reading is the honest
  /// one: a subject is «قيد التعبئة» while anybody still owes a sheet on it,
  /// and «مكتمل» once nobody does. Asking whether a FILE is a draft would be
  /// asking nothing.
  List<EvaluationSubject> get visibleSubjects => subjects.where((s) {
    if (target != null && s.target != target) return false;
    if (filterStatus == EvaluationStatus.draft && s.openCount == 0) return false;
    if (filterStatus == EvaluationStatus.submitted && s.openCount > 0) {
      return false;
    }
    return arabicMatchesAll([
      s.targetLabel,
      s.templateTitle,
      for (final e in s.evaluators) e.evaluatorName,
    ], query);
  }).toList();

  /// Sheets still owed, for the badge above the filters. Counted over
  /// everything rather than over what is visible: a filter that hides the two
  /// outstanding sheets should not report that there are none.
  int get openCount => isGrouped
      ? subjects.fold(0, (sum, s) => sum + s.openCount)
      : evaluations.where((e) => !e.isSubmitted).length;

  int get overdueCount => isGrouped
      ? subjects.fold(0, (sum, s) => sum + s.overdueCount)
      : evaluations.where((e) => e.isOverdue).length;

  /// Which kinds are actually present, so the filter offers no dead ends.
  Set<EvaluationTarget> get kinds => isGrouped
      ? {for (final s in subjects) s.target}
      : {for (final e in evaluations) e.target};

  EvaluationsState copyWith({
    EvaluationsScope? scope,
    EvaluationsStatus? status,
    List<Evaluation>? evaluations,
    List<EvaluationSubject>? subjects,
    String? query,
    EvaluationTarget? target,
    bool clearTarget = false,
    EvaluationStatus? filterStatus,
    bool clearStatus = false,
    String? error,
  }) => EvaluationsState(
    scope: scope ?? this.scope,
    status: status ?? this.status,
    evaluations: evaluations ?? this.evaluations,
    subjects: subjects ?? this.subjects,
    query: query ?? this.query,
    target: clearTarget ? null : (target ?? this.target),
    filterStatus: clearStatus ? null : (filterStatus ?? this.filterStatus),
    error: error,
  );

  @override
  List<Object?> get props => [
    scope,
    status,
    evaluations,
    subjects,
    query,
    target,
    filterStatus,
    error,
  ];
}

class EvaluationsCubit extends SafeCubit<EvaluationsState> {
  EvaluationsCubit(
    this._repo, {
    EvaluationsScope scope = EvaluationsScope.mine,
    this.templateId,
  }) : super(EvaluationsState(scope: scope)) {
    load();
  }

  final EvaluationsRepository _repo;

  /// Narrowed to one form, when the register was opened FROM that form.
  ///
  /// Asked of the server rather than filtered here: the list is capped, and a
  /// form with four sheets among two hundred would come back with none of them
  /// if the cap fell first.
  final String? templateId;

  Future<void> load() async {
    emit(state.copyWith(status: EvaluationsStatus.loading, error: null));
    try {
      if (state.isGrouped) {
        final subjects = await _repo.fetchSubjects(templateId: templateId);
        emit(
          state.copyWith(
            status: EvaluationsStatus.ready,
            subjects: subjects,
          ),
        );
      } else {
        final evaluations = await _repo.fetchList(templateId: templateId);
        emit(
          state.copyWith(
            status: EvaluationsStatus.ready,
            evaluations: evaluations,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(status: EvaluationsStatus.error, error: e.toString()),
      );
    }
  }

  void search(String value) => emit(state.copyWith(query: value));

  void setTarget(EvaluationTarget? target) => emit(
    target == null
        ? state.copyWith(clearTarget: true)
        : state.copyWith(target: target),
  );

  void setStatus(EvaluationStatus? status) => emit(
    status == null
        ? state.copyWith(clearStatus: true)
        : state.copyWith(filterStatus: status),
  );

  void clearFilters() => emit(
    state.copyWith(query: '', clearTarget: true, clearStatus: true),
  );

  /// Deleting from the register, which is the office's act and never the
  /// evaluator's — except for an untouched errand he was given and the person
  /// who gave it wants back, which the database decides rather than this.
  ///
  /// The grouped view re-reads rather than pruning in place: removing one
  /// sheet changes its subject's counts and its average, and a card left
  /// holding the arithmetic of a row that is gone is worse than a moment's
  /// spinner.
  Future<String?> delete(String evaluationId) async {
    try {
      await _repo.delete(evaluationId);
      if (state.isGrouped) {
        await load();
      } else {
        emit(
          state.copyWith(
            evaluations: [
              for (final e in state.evaluations)
                if (e.id != evaluationId) e,
            ],
          ),
        );
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
