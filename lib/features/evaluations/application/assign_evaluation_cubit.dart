import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../modules/domain/assignable_employee.dart';
import '../../seasons/data/seasons_repository.dart';
import '../data/evaluations_repository.dart';
import '../domain/evaluation.dart';

enum AssignEvaluationStatus { loading, ready, sending }

class AssignEvaluationState extends Equatable {
  const AssignEvaluationState({
    this.status = AssignEvaluationStatus.loading,
    this.forms = const [],
    this.form,
    this.targets = const [],
    this.pickedTargets = const [],
    this.evaluators = const [],
    this.seasonId,
    this.note = '',
    this.dueOn,
    this.error,
    this.loadingTargets = false,
    this.targetsError,
  });

  final AssignEvaluationStatus status;

  /// Active forms only. A retired form may be finished and never started, and
  /// the database says so — offering one here would be an offer followed by a
  /// refusal, which is worse than neither.
  final List<EvaluationFormSummary> forms;

  final EvaluationFormSummary? form;

  /// What the picker offered on its last read. Kept only so the screen can say
  /// "there is nothing of this kind" without asking again.
  final List<EvaluationPickerOption> targets;

  /// The subjects that were chosen — several of them. An office names the
  /// eleven files to be appraised, not one.
  final List<EvaluationPickerOption> pickedTargets;

  /// Who was named to fill them, as the employee picker handed them over: the
  /// names, the posts, the faces, and every file each is already carrying this
  /// season. The whole people rather than ids, because there is nowhere here to
  /// look a name up again — and because what the office weighs when it hands
  /// out an appraisal is exactly that list of commitments.
  final List<AssignableEmployee> evaluators;

  /// The season the picker searches within. `assignable_employees` is
  /// season-scoped by nature — its whole value is showing what somebody already
  /// carries THIS season — so the screen cannot open its picker until this is
  /// known.
  final String? seasonId;

  final String note;
  final DateTime? dueOn;
  final String? error;

  /// The subject list is in flight. Its own flag rather than the screen-wide
  /// [status], which was the bug this pair fixes: a failed or empty subject
  /// read left `status` at `ready` and `targets` empty, and an empty dropdown
  /// is indistinguishable from one that has not been asked yet. The picker now
  /// has three states to draw instead of one.
  final bool loadingTargets;

  /// Why the subject list is empty, when it is empty because something failed.
  /// Kept apart from [error], which belongs to the submit button.
  final String? targetsError;

  /// What this form is for, which the form decides rather than the reader. An
  /// evaluation's subject kind is a property of the paper being filled, and
  /// letting somebody pick both is offering a combination the server refuses.
  EvaluationTarget? get target => form?.target;

  bool get needsTarget => target?.needsTarget ?? false;

  /// How many errands this will actually open: one per subject per evaluator.
  ///
  /// Said on the button rather than discovered afterwards. Three judges over
  /// eleven files is thirty-three sheets, and thirty-three is a number somebody
  /// should see before they press send, not after.
  int get plannedCount =>
      (needsTarget ? pickedTargets.length : 1) * evaluators.length;

  bool get canSubmit =>
      status != AssignEvaluationStatus.sending &&
      form != null &&
      plannedCount > 0;

  AssignEvaluationState copyWith({
    AssignEvaluationStatus? status,
    List<EvaluationFormSummary>? forms,
    EvaluationFormSummary? form,
    List<EvaluationPickerOption>? targets,
    List<EvaluationPickerOption>? pickedTargets,
    List<AssignableEmployee>? evaluators,
    bool clearTarget = false,
    String? seasonId,
    String? note,
    DateTime? dueOn,
    bool clearDueOn = false,
    String? error,
    bool? loadingTargets,
    String? targetsError,
  }) => AssignEvaluationState(
    status: status ?? this.status,
    forms: forms ?? this.forms,
    form: form ?? this.form,
    targets: targets ?? this.targets,
    pickedTargets: clearTarget ? const [] : (pickedTargets ?? this.pickedTargets),
    evaluators: evaluators ?? this.evaluators,
    seasonId: seasonId ?? this.seasonId,
    note: note ?? this.note,
    dueOn: clearDueOn ? null : (dueOn ?? this.dueOn),
    error: error,
    loadingTargets: loadingTargets ?? this.loadingTargets,
    targetsError: targetsError,
  );

  @override
  List<Object?> get props => [
    status,
    forms,
    form,
    targets,
    pickedTargets,
    evaluators,
    seasonId,
    note,
    dueOn,
    error,
    loadingTargets,
    targetsError,
  ];
}

/// Opening one: pick the paper, pick who it is about, pick who fills it.
///
/// Deliberately in that order. The form decides what kind of thing may be named
/// next, so asking for the subject first would mean either offering all seven
/// kinds and then discarding the answer, or guessing.
class AssignEvaluationCubit extends SafeCubit<AssignEvaluationState> {
  AssignEvaluationCubit(
    this._repo, {
    String? templateId,
    EvaluationTarget? target,
    String? targetId,
    String? targetName,
  }) : _formId = templateId,
       _lockedTarget = target,
       super(
         AssignEvaluationState(
           pickedTargets: targetId == null
               ? const []
               : [
                   (
                     id: targetId,
                     name: targetName ?? '',
                     photoUrl: null,
                     subtitle: null,
                   ),
                 ],
         ),
       ) {
    load();
  }

  final EvaluationsRepository _repo;
  final SeasonsRepository _seasons = SeasonsRepository();

  /// Opened standing on one form — which is the only way in now that إدارة
  /// التقييم owns this act. The paper is settled before the screen appears, so
  /// the first question it asks is about the subject rather than about which
  /// form, and the reader never picks a combination the server would refuse.
  final String? _formId;

  /// Opened from a page that already knows its subject — an employee's, a
  /// file's. Only forms for that kind are offered, and the subject is not asked
  /// for twice.
  final EvaluationTarget? _lockedTarget;

  bool get isFormLocked => _formId != null;
  bool get isTargetLocked => _lockedTarget != null;

  Future<void> load() async {
    emit(state.copyWith(status: AssignEvaluationStatus.loading, error: null));
    try {
      // The season is fetched beside the forms rather than by the picker, so
      // that opening the picker is instant and a season that cannot be read is
      // a failure this screen reports rather than one the picker discovers.
      final forms = await _repo.fetchForms(
        includeInactive: false,
        target: _lockedTarget,
      );
      final season = await _seasons.fetchCurrentSeason();
      emit(
        state.copyWith(
          status: AssignEvaluationStatus.ready,
          forms: forms,
          seasonId: season?.id,
        ),
      );
      // The form this screen was opened on, or — when it was opened cold and
      // there is exactly one form for the kind — the only one there is, since
      // picking it saves a tap that has no alternative.
      final settled = _formId == null
          ? (forms.length == 1 ? forms.first : null)
          : forms.where((f) => f.id == _formId).firstOrNull;
      if (settled != null) await pickForm(settled);
    } catch (e) {
      emit(
        state.copyWith(
          status: AssignEvaluationStatus.ready,
          error: e.toString(),
        ),
      );
    }
  }

  /// Choosing the paper, which settles what kind of subject comes next — and so
  /// clears whatever was picked under the previous form. A hotel id left
  /// standing while the form says "an employee" is exactly the mismatch the
  /// database refuses, and it should never get that far.
  Future<void> pickForm(EvaluationFormSummary form) async {
    final keepTarget = isTargetLocked && state.pickedTargets.isNotEmpty;
    emit(
      state.copyWith(
        form: form,
        clearTarget: !keepTarget,
        targets: const [],
        error: null,
      ),
    );
    if (form.target.needsTarget && !keepTarget) await _loadTargets(form.target);
  }

  Future<void> _loadTargets(EvaluationTarget target) async {
    emit(state.copyWith(loadingTargets: true, targetsError: null));
    try {
      final targets = await _repo.fetchTargets(target);
      emit(state.copyWith(loadingTargets: false, targets: targets));
    } catch (e) {
      // Recorded against the picker rather than swallowed into the screen-wide
      // error. A subject list that failed to load used to render as a dropdown
      // with nothing in it, which reads as "there is nobody" — the one answer
      // that was never true.
      emit(
        state.copyWith(
          loadingTargets: false,
          targets: const [],
          targetsError: e.toString(),
        ),
      );
    }
  }

  /// Asking for the subject list again, after it failed.
  Future<void> retryTargets() async {
    final target = state.target;
    if (target == null || !target.needsTarget) return;
    await _loadTargets(target);
  }

  void pickTargets(List<EvaluationPickerOption> picked) =>
      emit(state.copyWith(pickedTargets: picked));

  void pickEvaluators(List<AssignableEmployee> people) =>
      emit(state.copyWith(evaluators: people));

  void removeEvaluator(String profileId) => emit(
    state.copyWith(
      evaluators: [
        for (final p in state.evaluators)
          if (p.profile.id != profileId) p,
      ],
    ),
  );

  void setNote(String value) => emit(state.copyWith(note: value));

  void setDueOn(DateTime? value) => emit(
    value == null
        ? state.copyWith(clearDueOn: true)
        : state.copyWith(dueOn: value),
  );

  /// Returns every evaluation opened, or an empty list with the error set.
  Future<List<String>> submit() async {
    if (!state.canSubmit) return const [];
    emit(state.copyWith(status: AssignEvaluationStatus.sending, error: null));
    try {
      final ids = await _repo.assign(
        templateId: state.form!.id,
        target: state.form!.target,
        targetIds: [for (final t in state.pickedTargets) t.id],
        evaluatorIds: [for (final p in state.evaluators) p.profile.id],
        note: state.note.trim().isEmpty ? null : state.note.trim(),
        dueOn: state.dueOn,
      );
      emit(state.copyWith(status: AssignEvaluationStatus.ready));
      return ids;
    } catch (e) {
      emit(
        state.copyWith(
          status: AssignEvaluationStatus.ready,
          error: e.toString(),
        ),
      );
      return const [];
    }
  }
}
