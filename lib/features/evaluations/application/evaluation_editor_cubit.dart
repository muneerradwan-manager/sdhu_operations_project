import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/evaluations_repository.dart';
import '../domain/evaluation.dart';

enum EvaluationEditorStatus { loading, ready, saving, error }

class EvaluationEditorState extends Equatable {
  const EvaluationEditorState({
    this.status = EvaluationEditorStatus.loading,
    this.form = const EvaluationForm(),
    this.stageIndex = 0,
    this.isDirty = false,
    this.isInUse = false,
    this.error,
  });

  final EvaluationEditorStatus status;
  final EvaluationForm form;

  /// Which stage is open. A form of six stages is six screens' worth of
  /// questions, and showing them all at once is the thing the stage exists to
  /// prevent.
  final int stageIndex;

  final bool isDirty;

  /// Sheets have been opened on this form. What that forbids is narrow — only
  /// changing what the form is FOR — but the editor has to know, because the
  /// database refuses it and an error at save is worse than a disabled control.
  final bool isInUse;

  final String? error;

  EvaluationStage? get stage =>
      stageIndex >= 0 && stageIndex < form.stages.length
      ? form.stages[stageIndex]
      : null;

  /// Whether there is anything to write.
  ///
  /// [isDirty] is half of it, and the half that was missing: a form that has
  /// just been saved is identical to the one on the server, and offering to
  /// save it again is offering to do nothing. Worse than useless on this
  /// screen — the editor is also where a form is READ, so a live Save button
  /// standing over an untouched form reads as work not yet done.
  bool get canSave =>
      status != EvaluationEditorStatus.saving &&
      isDirty &&
      form.title.trim().isNotEmpty;

  EvaluationEditorState copyWith({
    EvaluationEditorStatus? status,
    EvaluationForm? form,
    int? stageIndex,
    bool? isDirty,
    bool? isInUse,
    String? error,
  }) => EvaluationEditorState(
    status: status ?? this.status,
    form: form ?? this.form,
    stageIndex: stageIndex ?? this.stageIndex,
    isDirty: isDirty ?? this.isDirty,
    isInUse: isInUse ?? this.isInUse,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    form,
    stageIndex,
    isDirty,
    isInUse,
    error,
  ];
}

/// Building one form.
///
/// The whole tree is held in memory and written in one call, which is what the
/// server's `save_evaluation_form` is shaped for. Nothing here talks to the
/// database per keystroke: a form is edited for ten minutes and saved once, and
/// a stage that had been created by its first character would leave a trail of
/// empty stages behind every abandoned edit.
class EvaluationEditorCubit extends SafeCubit<EvaluationEditorState> {
  EvaluationEditorCubit(
    this._repo, {
    String? templateId,
    EvaluationTarget target = EvaluationTarget.module,
    bool isInUse = false,
  }) : _templateId = templateId,
       super(
         EvaluationEditorState(
           status: templateId == null
               ? EvaluationEditorStatus.ready
               : EvaluationEditorStatus.loading,
           isInUse: isInUse,
           // A new form starts with one stage rather than none. Every question
           // belongs to a stage, so a form with no stage has nowhere to put the
           // first question, and "add a stage" is not the thought anybody
           // arrives with.
           form: templateId == null
               ? EvaluationForm(
                   target: target,
                   stages: const [EvaluationStage(id: null, title: '')],
                 )
               : const EvaluationForm(),
         ),
       ) {
    if (templateId != null) load();
  }

  final EvaluationsRepository _repo;
  String? _templateId;

  String? get templateId => _templateId;

  Future<void> load() async {
    emit(state.copyWith(status: EvaluationEditorStatus.loading, error: null));
    try {
      final form = await _repo.fetchForm(_templateId!);
      emit(
        state.copyWith(
          status: EvaluationEditorStatus.ready,
          form: form,
          isDirty: false,
          stageIndex: 0,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: EvaluationEditorStatus.error,
          error: e.toString(),
        ),
      );
    }
  }

  void _set(EvaluationForm form) =>
      emit(state.copyWith(form: form, isDirty: true, error: null));

  // ------------------------------------------------------------ the header

  void setTitle(String value) => _set(state.form.copyWith(title: value));

  void setDescription(String value) =>
      _set(state.form.copyWith(description: value));

  /// What the form is for. Refused once anything has been opened on it — every
  /// sheet already out would be about a kind of thing the form no longer
  /// describes — and the database refuses it too, in `save_evaluation_form`.
  void setTarget(EvaluationTarget target) {
    if (state.isInUse) return;
    _set(state.form.copyWith(target: target));
  }

  void setActive(bool value) => _set(state.form.copyWith(isActive: value));

  // ------------------------------------------------------------ the stages

  void goToStage(int index) {
    if (index < 0 || index >= state.form.stages.length) return;
    emit(state.copyWith(stageIndex: index));
  }

  void addStage() {
    final stages = [
      ...state.form.stages,
      const EvaluationStage(id: null, title: ''),
    ];
    emit(
      state.copyWith(
        form: state.form.copyWith(stages: stages),
        stageIndex: stages.length - 1,
        isDirty: true,
      ),
    );
  }

  void setStageTitle(int index, String value) =>
      _editStage(index, (s) => s.copyWith(title: value));

  void setStageDescription(int index, String value) =>
      _editStage(index, (s) => s.copyWith(description: value));

  void removeStage(int index) {
    if (index < 0 || index >= state.form.stages.length) return;
    final stages = [...state.form.stages]..removeAt(index);
    emit(
      state.copyWith(
        // Never none. A form with no stage has nowhere to put a question.
        form: state.form.copyWith(
          stages: stages.isEmpty
              ? const [EvaluationStage(id: null, title: '')]
              : stages,
        ),
        stageIndex: index > 0 ? index - 1 : 0,
        isDirty: true,
      ),
    );
  }

  void moveStage(int from, int to) {
    final stages = [...state.form.stages];
    if (from < 0 || from >= stages.length) return;
    if (to < 0 || to >= stages.length) return;
    stages.insert(to, stages.removeAt(from));
    emit(
      state.copyWith(
        form: state.form.copyWith(stages: stages),
        stageIndex: to,
        isDirty: true,
      ),
    );
  }

  void _editStage(int index, EvaluationStage Function(EvaluationStage) change) {
    if (index < 0 || index >= state.form.stages.length) return;
    final stages = [...state.form.stages];
    stages[index] = change(stages[index]);
    _set(state.form.copyWith(stages: stages));
  }

  // --------------------------------------------------------- the questions

  void addQuestion(int stageIndex, EvaluationQuestionKind kind) {
    _editStage(stageIndex, (s) {
      return s.copyWith(
        questions: [
          ...s.questions,
          EvaluationQuestion(
            id: null,
            kind: kind,
            text: '',
            // A choice question arrives with two answers, because one answer is
            // not a choice and an empty list is a question nobody can answer.
            options: kind.isScored
                ? const [
                    EvaluationOption(id: null, text: ''),
                    EvaluationOption(id: null, text: ''),
                  ]
                : const [],
          ),
        ],
      );
    });
  }

  void editQuestion(
    int stageIndex,
    int questionIndex,
    EvaluationQuestion Function(EvaluationQuestion) change,
  ) {
    _editStage(stageIndex, (s) {
      if (questionIndex < 0 || questionIndex >= s.questions.length) return s;
      final questions = [...s.questions];
      questions[questionIndex] = change(questions[questionIndex]);
      return s.copyWith(questions: questions);
    });
  }

  void removeQuestion(int stageIndex, int questionIndex) {
    _editStage(stageIndex, (s) {
      if (questionIndex < 0 || questionIndex >= s.questions.length) return s;
      return s.copyWith(questions: [...s.questions]..removeAt(questionIndex));
    });
  }

  void moveQuestion(int stageIndex, int from, int to) {
    _editStage(stageIndex, (s) {
      if (from < 0 || from >= s.questions.length) return s;
      if (to < 0 || to >= s.questions.length) return s;
      final questions = [...s.questions];
      questions.insert(to, questions.removeAt(from));
      return s.copyWith(questions: questions);
    });
  }

  // ----------------------------------------------------------- the answers

  void addOption(int stageIndex, int questionIndex) {
    editQuestion(
      stageIndex,
      questionIndex,
      (q) => q.copyWith(
        options: [...q.options, const EvaluationOption(id: null, text: '')],
      ),
    );
  }

  void setOptionText(
    int stageIndex,
    int questionIndex,
    int optionIndex,
    String value,
  ) {
    _editOption(
      stageIndex,
      questionIndex,
      optionIndex,
      (o) => o.copyWith(text: value),
    );
  }

  void setOptionPoints(
    int stageIndex,
    int questionIndex,
    int optionIndex,
    double value,
  ) {
    _editOption(
      stageIndex,
      questionIndex,
      optionIndex,
      (o) => o.copyWith(points: value),
    );
  }

  void removeOption(int stageIndex, int questionIndex, int optionIndex) {
    editQuestion(stageIndex, questionIndex, (q) {
      if (optionIndex < 0 || optionIndex >= q.options.length) return q;
      return q.copyWith(options: [...q.options]..removeAt(optionIndex));
    });
  }

  void _editOption(
    int stageIndex,
    int questionIndex,
    int optionIndex,
    EvaluationOption Function(EvaluationOption) change,
  ) {
    editQuestion(stageIndex, questionIndex, (q) {
      if (optionIndex < 0 || optionIndex >= q.options.length) return q;
      final options = [...q.options];
      options[optionIndex] = change(options[optionIndex]);
      return q.copyWith(options: options);
    });
  }

  /// Removes the form outright. Returns null on success, the error otherwise.
  ///
  /// Here as well as on the list, because this screen is where a form is read
  /// in full — and deciding a form is not worth keeping is a thing you decide
  /// after reading its questions, not while looking at a card that shows three
  /// of them. Sending the reader back to the list to do it there is asking them
  /// to remember which of six similar titles they had just opened.
  ///
  /// The server refuses while a single sheet stands on it — `on delete
  /// restrict` — and that refusal is the truth; the check in the screen above
  /// only says it earlier and better.
  Future<String?> delete() async {
    final id = _templateId;
    if (id == null) return null;
    try {
      await _repo.deleteForm(id);
      // Clean, so the screen's PopScope lets it leave. The edits on it belonged
      // to a form that no longer exists — there is nothing left to discard, and
      // asking "keep your changes?" about a deleted form is asking about
      // nothing.
      emit(state.copyWith(isDirty: false, error: null));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Writes the whole tree in one call. Returns the form's id, or null with
  /// [EvaluationEditorState.error] set — the shape every editor in this app
  /// uses.
  Future<String?> save() async {
    if (!state.canSave) return null;
    emit(state.copyWith(status: EvaluationEditorStatus.saving, error: null));
    try {
      final id = await _repo.saveForm(
        state.form,
        templateId: _templateId ?? state.form.id,
      );
      _templateId = id;
      // Re-read: the server minted ids for everything that was new, and without
      // them a second save would insert the whole tree over again.
      await load();
      return id;
    } catch (e) {
      emit(
        state.copyWith(
          status: EvaluationEditorStatus.ready,
          error: e.toString(),
        ),
      );
      return null;
    }
  }
}
