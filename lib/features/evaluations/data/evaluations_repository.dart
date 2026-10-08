import '../../../core/supabase/supabase_client.dart';
import '../domain/evaluation.dart';

/// Everything this feature asks of the server.
///
/// All of it goes through RPCs rather than through `from('evaluations')`, and
/// that is the point rather than an accident. Two reasons, and they are
/// different reasons:
///
///   * The person an evaluation is ABOUT has no read on the table at all — row
///     security hides rows and not columns — and reaches his own results only
///     through functions that return the marks and no name.
///   * `evaluations` has no UPDATE policy whatsoever. A score is not something
///     a client may write; it is computed from the answers inside
///     `save_evaluation` and nowhere else.
///
/// See migration 0084.
class EvaluationsRepository {
  /// How much of the register one read carries. The table grows for as long as
  /// the mission does, and neither the list nor a person needs all of it.
  static const listLimit = 100;

  // ------------------------------------------------------------- the forms

  /// The catalog. Asks for one of the three evaluation permissions; the server
  /// refuses it to anyone holding none of them.
  Future<List<EvaluationFormSummary>> fetchForms({
    bool includeInactive = true,
    EvaluationTarget? target,
    String? query,
  }) async {
    final rows = await supabase.rpc(
      'evaluation_forms_list',
      params: {
        'p_include_inactive': includeInactive,
        'p_target_type': target?.name,
        'p_query': query,
      },
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(EvaluationFormSummary.fromMap)
        .toList();
  }

  /// One form, whole: stages, questions, answers, in order.
  ///
  /// Through a function rather than three selects because the man filling a
  /// sheet must be able to read the form it is on even after the office retired
  /// it — and the SELECT policy on the table would already have said no.
  Future<EvaluationForm> fetchForm(String templateId) async {
    final row = await supabase.rpc(
      'evaluation_form',
      params: {'p_template_id': templateId},
    );
    return EvaluationForm.fromMap(Map<String, dynamic>.from(row as Map));
  }

  /// Saves a form whole, and returns its id.
  ///
  /// One call because a form is one act — the argument of `save_report`, and
  /// here it is worth more: a form is a three-level tree, and an editor that
  /// wrote it level by level would leave a stage with no questions behind on
  /// any dropped connection. Ids sent back are kept, ids absent are deleted,
  /// and the order is the array's own — which is what makes drag-to-reorder a
  /// save rather than a call per row.
  ///
  /// [templateId] overrides the one on [form], for the single moment the two
  /// can disagree: an editor that has just created a form holds the new id
  /// while the object in its hand is still the one it was building.
  Future<String> saveForm(EvaluationForm form, {String? templateId}) async {
    final id = await supabase.rpc(
      'save_evaluation_form',
      params: {
        'p_template_id': templateId ?? form.id,
        'p_title': form.title.trim(),
        'p_description': form.description?.trim(),
        'p_target_type': form.target.name,
        'p_is_active': form.isActive,
        'p_stages': [for (final s in form.stages) s.toJson()],
      },
    );
    return id as String;
  }

  /// Deleting one. Refused by the database — `on delete restrict` — as soon as
  /// a single sheet has been opened on it, and that refusal is the feature:
  /// retiring a form is `isActive = false`, which keeps the appraisals written
  /// on it readable.
  Future<void> deleteForm(String templateId) async {
    await supabase.from('evaluation_templates').delete().eq('id', templateId);
  }

  // ------------------------------------------------------- the evaluations

  /// The register. [all] is everyone's and asks for `evaluations.view`; without
  /// it, this is what the caller was asked to fill.
  Future<List<Evaluation>> fetchList({
    bool all = false,
    EvaluationStatus? status,
    EvaluationTarget? target,
    String? targetId,
    String? templateId,
    String? query,
  }) async {
    final rows = await supabase.rpc(
      'evaluations_list',
      params: {
        'p_scope': all ? 'all' : 'mine',
        'p_status': status?.name,
        'p_target_type': target?.name,
        'p_target_id': targetId,
        'p_template_id': templateId,
        'p_query': query,
        'p_limit': listLimit,
      },
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Evaluation.fromMap)
        .toList();
  }

  /// The register as the office actually asks it: one row per thing under
  /// judgement, carrying its counts, its marks, and everyone who was asked —
  /// each with their own sheet's id inside it.
  ///
  /// One call rather than a list and then a read per card: twenty evaluators
  /// on a file is one fact about that file, and fetching them separately would
  /// be twenty round trips to draw one card. See `evaluation_subjects_list` in
  /// migration 0127.
  Future<List<EvaluationSubject>> fetchSubjects({
    bool all = true,
    EvaluationTarget? target,
    String? templateId,
    String? query,
  }) async {
    final rows = await supabase.rpc(
      'evaluation_subjects_list',
      params: {
        'p_scope': all ? 'all' : 'mine',
        'p_target_type': target?.name,
        'p_template_id': templateId,
        'p_query': query,
        'p_limit': listLimit,
      },
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(EvaluationSubject.fromMap)
        .toList();
  }

  /// One sheet: the errand, the form and the filling. The same call serves the
  /// screen that fills a draft and the screen that reads a finished one,
  /// because they are the same screen.
  Future<EvaluationSheet> fetchSheet(String evaluationId) async {
    final row = await supabase.rpc(
      'evaluation_sheet',
      params: {'p_evaluation_id': evaluationId},
    );
    return EvaluationSheet.fromMap(Map<String, dynamic>.from(row as Map));
  }

  /// What was written about the caller. Takes no id, because there is no other
  /// person it could be asked about — a stronger guarantee than a check that it
  /// is being asked about the right one. Finished sheets only.
  Future<List<MyEvaluation>> fetchAboutMe() async {
    final rows = await supabase.rpc(
      'evaluations_about_me',
      params: {'p_limit': listLimit},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MyEvaluation.fromMap)
        .toList();
  }

  /// Counts and an average about one subject — never a name. Answers for the
  /// caller himself too, which is what the panel on his own page reads.
  Future<EvaluationStanding> fetchStanding({
    required EvaluationTarget target,
    required String targetId,
  }) async {
    final rows = await supabase.rpc(
      'evaluations_about',
      params: {'p_target_type': target.name, 'p_target_id': targetId},
    );
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return const EvaluationStanding();
    return EvaluationStanding.fromMap(list.first);
  }

  // -------------------------------------------------------------- writing

  /// Opens one errand per subject per evaluator, and returns their ids.
  ///
  /// One call and one transaction: a batch that fails halfway would leave the
  /// office to work out by hand which of the thirty-three landed. The server
  /// writes the cross product — see `assign_evaluations` in 0084, and §26.8 for
  /// why several evaluators cannot share one sheet.
  Future<List<String>> assign({
    required String templateId,
    required EvaluationTarget target,
    List<String> targetIds = const [],
    required List<String> evaluatorIds,
    String? note,
    DateTime? dueOn,
  }) async {
    final rows = await supabase.rpc(
      'assign_evaluations',
      params: {
        'p_template_id': templateId,
        'p_target_type': target.name,
        'p_target_ids': target.needsTarget ? targetIds : const <String>[],
        'p_evaluator_ids': evaluatorIds,
        'p_note': note,
        'p_due_on': dueOn == null ? null : _day(dueOn),
      },
    );
    return (rows as List).map((r) => r.toString()).toList();
  }

  /// Saves the answers, and — when [submit] — finishes the sheet.
  ///
  /// The whole state of the sheet goes every time: answers absent from the list
  /// are deleted on the server, because clearing a question is saying nothing
  /// about it and a save is not a patch.
  ///
  /// Returns what the server computed. The score is never sent; it is derived
  /// from the answers by the one function in the schema that may write it.
  Future<({EvaluationStatus status, double? score, double maxScore})> save({
    required String evaluationId,
    required List<EvaluationSheetQuestion> answers,
    bool submit = false,
  }) async {
    final payload = [
      for (final a in answers)
        if (a.questionId != null && a.isAnswered)
          {
            'question_id': a.questionId,
            'option_id': a.kind.isScored ? a.optionId : null,
            'text': a.kind.isScored ? null : a.textAnswer,
          },
    ];

    final result = await supabase.rpc(
      'save_evaluation',
      params: {
        'p_evaluation_id': evaluationId,
        'p_answers': payload,
        'p_submit': submit,
      },
    );
    final map = Map<String, dynamic>.from(result as Map);
    return (
      status: EvaluationStatus.fromDb(map['status'] as String?),
      score: _nullableNum(map['score']),
      maxScore: _nullableNum(map['max_score']) ?? 0,
    );
  }

  /// Sends a finished sheet back for correction. Keeps the answers: what is
  /// undone is the finishing, not the work.
  Future<void> reopen(String evaluationId) async {
    await supabase.rpc(
      'reopen_evaluation',
      params: {'p_evaluation_id': evaluationId},
    );
  }

  /// The two things about an errand that are not the errand. The subject, the
  /// form and the evaluator are refused by a trigger whichever door is used.
  Future<void> updateAssignment({
    required String evaluationId,
    String? note,
    DateTime? dueOn,
  }) async {
    await supabase.rpc(
      'update_evaluation_assignment',
      params: {
        'p_evaluation_id': evaluationId,
        'p_note': note,
        'p_due_on': dueOn == null ? null : _day(dueOn),
      },
    );
  }

  Future<void> delete(String evaluationId) async {
    await supabase.from('evaluations').delete().eq('id', evaluationId);
  }

  // ------------------------------------------------------------- pickers

  /// What an evaluation of this kind may be opened about — an id, a name, and a
  /// face where the kind has one.
  ///
  /// Through an RPC for the reason the complaints picker is: the row security
  /// that hides these tables is right, and the answer to a question it cannot
  /// express is a function that returns less, not a policy that shows more.
  /// Three columns come back — never the directory behind them.
  Future<List<EvaluationPickerOption>> fetchTargets(
    EvaluationTarget target, {
    String? query,
  }) async {
    if (!target.needsTarget) return const [];
    final rows = await supabase.rpc(
      'evaluation_targets',
      params: {
        'p_target_type': target.name,
        'p_query': query,
        'p_limit': listLimit,
      },
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => (
            id: row['id'] as String,
            name: (row['name'] as String?) ?? '',
            photoUrl: row['photo_url'] as String?,
            subtitle: null as String?,
          ),
        )
        .toList();
  }

}

/// A `date` column, not a timestamp. Sending the whole instant would let a
/// deadline shift by a day for anybody east of the server.
String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

double? _nullableNum(Object? raw) => switch (raw) {
  null => null,
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};
