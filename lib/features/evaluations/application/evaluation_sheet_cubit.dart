import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/evaluations_repository.dart';
import '../domain/evaluation.dart';

enum EvaluationSheetStatus { loading, ready, saving, error }

class EvaluationSheetState extends Equatable {
  const EvaluationSheetState({
    this.status = EvaluationSheetStatus.loading,
    this.sheet,
    this.stageIndex = 0,
    this.isDirty = false,
    this.showMissing = false,
    this.error,
  });

  final EvaluationSheetStatus status;
  final EvaluationSheet? sheet;

  /// Which stage the reader is standing in. Kept here rather than in a
  /// PageController so that "jump to the first stage that is still missing
  /// something" is a state change and not a gesture the screen has to fake.
  final int stageIndex;

  /// There are answers in hand that the server has not been told about.
  final bool isDirty;

  /// Whether unanswered required questions are being pointed at. False until
  /// somebody tries to finish: marking a form red before it has been filled in
  /// is scolding a person for not having done the thing they just opened.
  final bool showMissing;

  final String? error;

  bool get canFill =>
      (sheet?.canFill ?? false) && status != EvaluationSheetStatus.saving;

  bool get canSubmit => canFill && (sheet?.isComplete ?? false);

  EvaluationSheetState copyWith({
    EvaluationSheetStatus? status,
    EvaluationSheet? sheet,
    int? stageIndex,
    bool? isDirty,
    bool? showMissing,
    String? error,
  }) => EvaluationSheetState(
    status: status ?? this.status,
    sheet: sheet ?? this.sheet,
    stageIndex: stageIndex ?? this.stageIndex,
    isDirty: isDirty ?? this.isDirty,
    showMissing: showMissing ?? this.showMissing,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    sheet,
    stageIndex,
    isDirty,
    showMissing,
    error,
  ];
}

/// Filling one sheet, and reading a finished one.
///
/// One cubit for both, because the server answers both with the same call: a
/// draft comes back drawn from the form it is being filled against, a submitted
/// one from its own answers with the wording they were given under. Which of
/// the two arrived is [EvaluationSheet.canFill], and it is the server's answer
/// rather than this class's.
class EvaluationSheetCubit extends SafeCubit<EvaluationSheetState> {
  EvaluationSheetCubit(this._repo, this.evaluationId)
    : super(const EvaluationSheetState()) {
    load();
  }

  final EvaluationsRepository _repo;
  final String evaluationId;

  Future<void> load() async {
    emit(state.copyWith(status: EvaluationSheetStatus.loading, error: null));
    try {
      final sheet = await _repo.fetchSheet(evaluationId);
      emit(
        state.copyWith(
          status: EvaluationSheetStatus.ready,
          sheet: sheet,
          isDirty: false,
          showMissing: false,
          // Reopened past its end, or opened at a stage that no longer exists.
          stageIndex: state.stageIndex.clamp(
            0,
            sheet.stages.isEmpty ? 0 : sheet.stages.length - 1,
          ),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: EvaluationSheetStatus.error, error: e.toString()),
      );
    }
  }

  void goToStage(int index) {
    final sheet = state.sheet;
    if (sheet == null || index < 0 || index >= sheet.stages.length) return;
    emit(state.copyWith(stageIndex: index));
  }

  /// Choosing an answer. Tapping the chosen one again clears it — which is the
  /// only way to un-answer an optional question, and there is no other gesture
  /// a radio row offers.
  void choose(int stageIndex, int questionIndex, String? optionId) {
    _mutate(stageIndex, questionIndex, (q) {
      final clearing = optionId == null || q.optionId == optionId;
      if (clearing) return q.copyWith(clearOption: true, points: 0);
      final chosen = q.options.where((o) => o.id == optionId).firstOrNull;
      return q.copyWith(optionId: optionId, points: chosen?.points ?? 0);
    });
  }

  void write(int stageIndex, int questionIndex, String value) {
    _mutate(stageIndex, questionIndex, (q) => q.copyWith(textAnswer: value));
  }

  void _mutate(
    int stageIndex,
    int questionIndex,
    EvaluationSheetQuestion Function(EvaluationSheetQuestion) change,
  ) {
    final sheet = state.sheet;
    if (sheet == null || !state.canFill) return;
    if (stageIndex < 0 || stageIndex >= sheet.stages.length) return;

    final stage = sheet.stages[stageIndex];
    if (questionIndex < 0 || questionIndex >= stage.questions.length) return;

    final questions = [...stage.questions];
    questions[questionIndex] = change(questions[questionIndex]);

    final stages = [...sheet.stages];
    stages[stageIndex] = stage.copyWith(questions: questions);

    emit(
      state.copyWith(sheet: sheet.copyWith(stages: stages), isDirty: true),
    );
  }

  /// Keeps the work without finishing it. Returns an error string, or null.
  Future<String?> saveDraft() => _save(submit: false);

  /// Finishes it. Refuses locally first — every required question, in every
  /// stage — and moves the reader to the first stage that is short, because
  /// "something is missing" without saying where is a form somebody scrolls
  /// twice and then abandons.
  Future<String?> submit() async {
    final sheet = state.sheet;
    if (sheet == null) return null;

    if (!sheet.isComplete) {
      final short = sheet.firstIncompleteStage;
      emit(
        state.copyWith(
          showMissing: true,
          stageIndex: short < 0 ? state.stageIndex : short,
        ),
      );
      return 'evaluation_incomplete';
    }
    return _save(submit: true);
  }

  Future<String?> _save({required bool submit}) async {
    final sheet = state.sheet;
    if (sheet == null || !state.canFill) return null;

    emit(state.copyWith(status: EvaluationSheetStatus.saving, error: null));
    try {
      await _repo.save(
        evaluationId: evaluationId,
        answers: [for (final s in sheet.stages) ...s.questions],
        submit: submit,
      );
      // Re-read rather than patch the state by hand. Submitting changes the
      // shape of what comes back — a finished sheet is drawn from its own
      // answers — and guessing at that shape locally is how the two drift.
      await load();
      return null;
    } catch (e) {
      emit(
        state.copyWith(status: EvaluationSheetStatus.ready, error: e.toString()),
      );
      return e.toString();
    }
  }

  /// The office sending a finished sheet back. Keeps the answers: what is
  /// undone is the finishing, not the work.
  Future<String?> reopen() async {
    emit(state.copyWith(status: EvaluationSheetStatus.saving, error: null));
    try {
      await _repo.reopen(evaluationId);
      await load();
      return null;
    } catch (e) {
      emit(
        state.copyWith(status: EvaluationSheetStatus.ready, error: e.toString()),
      );
      return e.toString();
    }
  }
}
