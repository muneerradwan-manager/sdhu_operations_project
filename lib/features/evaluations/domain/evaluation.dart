/// What an evaluation is about.
///
/// Mirrors the `evaluation_target_type` enum (migration 0084), which is the
/// complaints' set value for value — it is the same question asked about a
/// different kind of statement. Two enums rather than one shared type, in Dart
/// for the reason the migration gives in SQL: the day one of them gains a kind
/// the other must not have, a shared type would hand it over anyway.
enum EvaluationTarget {
  employee,
  module,
  report,
  hotel,
  cluster,
  group,
  other;

  static EvaluationTarget fromDb(String? value) => switch (value) {
    'employee' => EvaluationTarget.employee,
    'module' => EvaluationTarget.module,
    'report' => EvaluationTarget.report,
    'hotel' => EvaluationTarget.hotel,
    'cluster' => EvaluationTarget.cluster,
    'group' => EvaluationTarget.group,
    _ => EvaluationTarget.other,
  };

  /// Whether opening one against this needs something picked. `other` is the
  /// one evaluation with nothing to point at.
  bool get needsTarget => this != EvaluationTarget.other;
}

/// What a question asks for.
///
/// [choice] carries a mark and a list of answers that each earn part of it;
/// [text] carries neither and never will — the migration's check constraint
/// says so, and this enum is the app half of the same sentence.
enum EvaluationQuestionKind {
  choice,
  text;

  static EvaluationQuestionKind fromDb(String? value) =>
      value == 'text' ? EvaluationQuestionKind.text : EvaluationQuestionKind.choice;

  bool get isScored => this == EvaluationQuestionKind.choice;
}

/// Where a sheet stands. There is no 'assigned' distinct from [draft]: the
/// difference is whether anything has been answered yet, which is a count.
enum EvaluationStatus {
  draft,
  submitted;

  static EvaluationStatus fromDb(String? value) =>
      value == 'submitted' ? EvaluationStatus.submitted : EvaluationStatus.draft;

  bool get isSubmitted => this == EvaluationStatus.submitted;
}

/// Who the reader is to one sheet, as the server worked it out.
///
/// The server decides this and not the app: the same three words also govern
/// what it redacts, and a second opinion computed on the client would be a
/// second answer to a question that must only have one.
enum EvaluationRole {
  evaluator,
  subject,
  manager;

  static EvaluationRole fromDb(String? value) => switch (value) {
    'subject' => EvaluationRole.subject,
    'manager' => EvaluationRole.manager,
    _ => EvaluationRole.evaluator,
  };
}

/// One thing an evaluation may be opened about, or one person it may be given
/// to, as the picker lists it.
typedef EvaluationPickerOption = ({
  String id,
  String name,
  String? photoUrl,
  String? subtitle,
});

// ============================================================== the form

/// One answer a choice question offers, and what choosing it earns.
class EvaluationOption {
  const EvaluationOption({
    required this.id,
    required this.text,
    this.points = 0,
  });

  /// Null for an answer the editor has added and not yet saved.
  final String? id;
  final String text;
  final double points;

  EvaluationOption copyWith({String? text, double? points}) => EvaluationOption(
    id: id,
    text: text ?? this.text,
    points: points ?? this.points,
  );

  factory EvaluationOption.fromMap(Map<String, dynamic> map) => EvaluationOption(
    id: map['id'] as String?,
    text: (map['text'] as String?) ?? '',
    points: _num(map['points']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'points': points,
  };
}

/// One question: what it asks, what it is worth, and — for a choice — the
/// answers it offers.
class EvaluationQuestion {
  const EvaluationQuestion({
    required this.id,
    required this.kind,
    required this.text,
    this.points = 0,
    this.isRequired = true,
    this.options = const [],
  });

  final String? id;
  final EvaluationQuestionKind kind;
  final String text;

  /// The question's full mark: what its best answer earns, and what no answer
  /// may exceed. Always zero for a written question.
  final double points;

  /// Whether it may be left empty. Asked of both kinds — a written question
  /// carries no mark and can still be the thing the sheet exists to collect.
  final bool isRequired;

  final List<EvaluationOption> options;

  /// What the office actually wrote, as opposed to what it declared. A question
  /// worth 10 whose best answer earns 6 is a form that has been half-edited,
  /// and the editor says so rather than waiting for the first sheet to come
  /// back four marks short.
  double get bestAnswerPoints =>
      options.isEmpty ? 0 : options.map((o) => o.points).reduce((a, b) => a > b ? a : b);

  bool get isUnreachable =>
      kind.isScored && options.isNotEmpty && bestAnswerPoints < points;

  EvaluationQuestion copyWith({
    EvaluationQuestionKind? kind,
    String? text,
    double? points,
    bool? isRequired,
    List<EvaluationOption>? options,
  }) => EvaluationQuestion(
    id: id,
    kind: kind ?? this.kind,
    text: text ?? this.text,
    // A written question carries no mark, here as in the database. Enforcing it
    // at the one place the editor mutates a question is what stops the screen
    // from showing a total the server will refuse.
    points: (kind ?? this.kind).isScored ? (points ?? this.points) : 0,
    isRequired: isRequired ?? this.isRequired,
    options: (kind ?? this.kind).isScored ? (options ?? this.options) : const [],
  );

  factory EvaluationQuestion.fromMap(Map<String, dynamic> map) =>
      EvaluationQuestion(
        id: map['id'] as String?,
        kind: EvaluationQuestionKind.fromDb(map['kind'] as String?),
        text: (map['text'] as String?) ?? '',
        points: _num(map['points']),
        isRequired: (map['is_required'] as bool?) ?? true,
        options: [
          for (final o in (map['options'] as List?) ?? const [])
            EvaluationOption.fromMap(Map<String, dynamic>.from(o as Map)),
        ],
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'text': text,
    'points': points,
    'is_required': isRequired,
    'options': [for (final o in options) o.toJson()],
  };
}

/// One stage — مرحلة — which is a SECTION of one sheet and not a round in time.
/// فريق التروية is stage 1 and الإعاشة is stage 2 of the same filling, by the
/// same person. The screen draws them as steps because sixty questions do not
/// read as one scroll, not because the steps are separately owned.
class EvaluationStage {
  const EvaluationStage({
    required this.id,
    required this.title,
    this.description,
    this.questions = const [],
  });

  final String? id;
  final String title;
  final String? description;
  final List<EvaluationQuestion> questions;

  /// The sum of its questions. Never a stored number — one kept in step by hand
  /// is one that stops being in step.
  double get totalPoints =>
      questions.fold(0, (sum, q) => sum + q.points);

  EvaluationStage copyWith({
    String? title,
    String? description,
    List<EvaluationQuestion>? questions,
  }) => EvaluationStage(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    questions: questions ?? this.questions,
  );

  factory EvaluationStage.fromMap(Map<String, dynamic> map) => EvaluationStage(
    id: map['id'] as String?,
    title: (map['title'] as String?) ?? '',
    description: map['description'] as String?,
    questions: [
      for (final q in (map['questions'] as List?) ?? const [])
        EvaluationQuestion.fromMap(Map<String, dynamic>.from(q as Map)),
    ],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'questions': [for (final q in questions) q.toJson()],
  };
}

/// A whole form, as the editor holds it and as the filler reads it.
class EvaluationForm {
  const EvaluationForm({
    this.id,
    this.title = '',
    this.description,
    this.target = EvaluationTarget.module,
    this.isActive = false,
    this.stages = const [],
  });

  final String? id;
  final String title;
  final String? description;
  final EvaluationTarget target;

  /// A form is a draft until somebody says it is finished. Only an active one
  /// may be assigned; deactivating stops NEW assignments and leaves the sheets
  /// already out in flight alone.
  final bool isActive;

  final List<EvaluationStage> stages;

  double get totalPoints => stages.fold(0, (sum, s) => sum + s.totalPoints);
  int get questionCount => stages.fold(0, (sum, s) => sum + s.questions.length);

  /// Whether it may be switched on. A form with no scored question is a
  /// questionnaire and is allowed; a form with no question at all is a title.
  bool get canPublish =>
      title.trim().isNotEmpty &&
      stages.isNotEmpty &&
      stages.every((s) => s.title.trim().isNotEmpty) &&
      questionCount > 0 &&
      stages.every(
        (s) => s.questions.every(
          (q) =>
              q.text.trim().isNotEmpty &&
              (!q.kind.isScored || q.options.length >= 2) &&
              q.options.every((o) => o.text.trim().isNotEmpty),
        ),
      );

  EvaluationForm copyWith({
    String? title,
    String? description,
    EvaluationTarget? target,
    bool? isActive,
    List<EvaluationStage>? stages,
  }) => EvaluationForm(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    target: target ?? this.target,
    isActive: isActive ?? this.isActive,
    stages: stages ?? this.stages,
  );

  factory EvaluationForm.fromMap(Map<String, dynamic> map) => EvaluationForm(
    id: map['id'] as String?,
    title: (map['title'] as String?) ?? '',
    description: map['description'] as String?,
    target: EvaluationTarget.fromDb(map['target_type'] as String?),
    isActive: (map['is_active'] as bool?) ?? false,
    stages: [
      for (final s in (map['stages'] as List?) ?? const [])
        EvaluationStage.fromMap(Map<String, dynamic>.from(s as Map)),
    ],
  );
}

/// One form as the catalog lists it — the shape `evaluation_forms_list` returns,
/// which carries the counts instead of the tree.
class EvaluationFormSummary {
  const EvaluationFormSummary({
    required this.id,
    required this.title,
    required this.target,
    this.description,
    this.isActive = false,
    this.stageCount = 0,
    this.questionCount = 0,
    this.totalPoints = 0,
    this.evaluationCount = 0,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final EvaluationTarget target;
  final bool isActive;
  final int stageCount;
  final int questionCount;
  final double totalPoints;

  /// How many sheets are out on it — which is why deleting one may fail, and
  /// why the editor refuses to change what the form is FOR once it is past zero.
  final int evaluationCount;

  final DateTime? updatedAt;

  bool get isInUse => evaluationCount > 0;

  factory EvaluationFormSummary.fromMap(Map<String, dynamic> map) =>
      EvaluationFormSummary(
        id: map['id'] as String,
        title: (map['title'] as String?) ?? '',
        description: map['description'] as String?,
        target: EvaluationTarget.fromDb(map['target_type'] as String?),
        isActive: (map['is_active'] as bool?) ?? false,
        stageCount: (map['stage_count'] as num?)?.toInt() ?? 0,
        questionCount: (map['question_count'] as num?)?.toInt() ?? 0,
        totalPoints: _num(map['total_points']),
        evaluationCount: (map['evaluation_count'] as num?)?.toInt() ?? 0,
        updatedAt: _date(map['updated_at']),
      );
}

// ========================================================== the evaluation

/// One sheet as the register lists it.
class Evaluation {
  const Evaluation({
    required this.id,
    required this.createdAt,
    required this.templateId,
    required this.templateTitle,
    required this.target,
    required this.status,
    this.targetId,
    this.targetLabel,
    this.evaluatorId,
    this.evaluatorName,
    this.evaluatorPhotoUrl,
    this.note,
    this.dueOn,
    this.submittedAt,
    this.score,
    this.maxScore,
    this.answeredCount = 0,
    this.questionCount = 0,
    this.myRole = EvaluationRole.evaluator,
  });

  final String id;
  final DateTime createdAt;
  final String templateId;
  final String templateTitle;
  final EvaluationTarget target;

  /// Null for [EvaluationTarget.other], and for a subject that has since been
  /// deleted — which is why [targetLabel] is a snapshot and not a lookup.
  final String? targetId;
  final String? targetLabel;

  /// Null when this reader may not know. The subject never learns these three,
  /// and they do not arrive over the wire at all rather than arriving empty.
  final String? evaluatorId;
  final String? evaluatorName;
  final String? evaluatorPhotoUrl;

  final String? note;
  final DateTime? dueOn;

  final EvaluationStatus status;
  final DateTime? submittedAt;
  final double? score;
  final double? maxScore;

  final int answeredCount;
  final int questionCount;
  final EvaluationRole myRole;

  bool get isSubmitted => status.isSubmitted;

  /// How far through the form it is, as a fraction. Only meaningful while a
  /// sheet is still a draft.
  double get progress =>
      questionCount == 0 ? 0 : (answeredCount / questionCount).clamp(0, 1);

  /// The mark as a percentage, or null when it has not been finished or the
  /// form is worth nothing at all — a questionnaire of written questions is a
  /// legitimate form and has no percentage.
  double? get percent => (score != null && (maxScore ?? 0) > 0)
      ? (score! * 100 / maxScore!)
      : null;

  /// Past its date and not finished. Nothing in the database enforces this — a
  /// due date that locks a form loses the appraisal instead of the deadline —
  /// so it is said on the card and nowhere else.
  bool get isOverdue {
    final due = dueOn;
    if (due == null || isSubmitted) return false;
    final today = DateTime.now();
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }

  factory Evaluation.fromMap(Map<String, dynamic> map) => Evaluation(
    id: map['id'] as String,
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    templateId: (map['template_id'] as String?) ?? '',
    templateTitle: (map['template_title'] as String?) ?? '',
    target: EvaluationTarget.fromDb(map['target_type'] as String?),
    targetId: map['target_id'] as String?,
    targetLabel: map['target_label'] as String?,
    evaluatorId: map['evaluator_id'] as String?,
    evaluatorName: map['evaluator_name'] as String?,
    evaluatorPhotoUrl: map['evaluator_photo_url'] as String?,
    note: map['note'] as String?,
    dueOn: _date(map['due_on']),
    status: EvaluationStatus.fromDb(map['status'] as String?),
    submittedAt: _date(map['submitted_at']),
    score: _nullableNum(map['score']),
    maxScore: _nullableNum(map['max_score']),
    answeredCount: (map['answered_count'] as num?)?.toInt() ?? 0,
    questionCount: (map['question_count'] as num?)?.toInt() ?? 0,
    myRole: EvaluationRole.fromDb(map['my_role'] as String?),
  );
}
/// One person who was asked to judge a subject, as it appears inside that
/// subject's card — enough to name them, say where they have gotten to, and
/// open their sheet.
///
/// [id] is the sheet's, not the person's: it is what the card leads into, and
/// the same person can hold two of these on two different papers.
class EvaluationSubjectMember {
  const EvaluationSubjectMember({
    required this.id,
    required this.status,
    this.evaluatorId,
    this.evaluatorName,
    this.evaluatorPhotoUrl,
    this.score,
    this.maxScore,
    this.percent,
    this.dueOn,
    this.submittedAt,
    this.answeredCount = 0,
    this.questionCount = 0,
  });

  final String id;
  final EvaluationStatus status;
  final String? evaluatorId;
  final String? evaluatorName;
  final String? evaluatorPhotoUrl;
  final double? score;
  final double? maxScore;

  /// Set only once the sheet is finished and the form was worth something — a
  /// questionnaire of written questions is a legitimate form with no
  /// percentage to give.
  final double? percent;

  final DateTime? dueOn;
  final DateTime? submittedAt;
  final int answeredCount;
  final int questionCount;

  bool get isSubmitted => status.isSubmitted;

  double get progress =>
      questionCount == 0 ? 0 : (answeredCount / questionCount).clamp(0, 1);

  /// Past its date and not finished — the same rule [Evaluation.isOverdue]
  /// uses, and enforced by nothing but the reading of it.
  bool get isOverdue {
    final due = dueOn;
    if (due == null || isSubmitted) return false;
    final today = DateTime.now();
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }

  factory EvaluationSubjectMember.fromMap(Map<String, dynamic> map) =>
      EvaluationSubjectMember(
        id: map['id'] as String,
        status: EvaluationStatus.fromDb(map['status'] as String?),
        evaluatorId: map['evaluator_id'] as String?,
        evaluatorName: map['evaluator_name'] as String?,
        evaluatorPhotoUrl: map['evaluator_photo_url'] as String?,
        score: _nullableNum(map['score']),
        maxScore: _nullableNum(map['max_score']),
        percent: _nullableNum(map['percent']),
        dueOn: _date(map['due_on']),
        submittedAt: _date(map['submitted_at']),
        answeredCount: (map['answered_count'] as num?)?.toInt() ?? 0,
        questionCount: (map['question_count'] as num?)?.toInt() ?? 0,
      );
}

/// One thing under judgement, on one form: what it is, everyone who was asked
/// to judge it, and what their marks have come to.
///
/// This is the register's unit rather than the sheet, because it is the unit
/// the question is asked in. Twenty people appraising one file is one thing
/// happening, not twenty — and the office reads it to learn how that one
/// thing is going.
///
/// The three marks are over FINISHED sheets only and are percentages, not
/// scores: a half-filled form adds up to a number nobody should quote, and
/// two sheets on a form that was re-marked in between are only comparable
/// once both are out of a hundred.
class EvaluationSubject {
  const EvaluationSubject({
    required this.templateId,
    required this.templateTitle,
    required this.target,
    required this.openedAt,
    this.targetId,
    this.targetLabel,
    this.dueOn,
    this.totalCount = 0,
    this.submittedCount = 0,
    this.overdueCount = 0,
    this.averagePercent,
    this.bestPercent,
    this.worstPercent,
    this.evaluators = const [],
  });

  final String templateId;
  final String templateTitle;
  final EvaluationTarget target;
  final DateTime openedAt;

  /// Null for [EvaluationTarget.other], which points at nothing.
  final String? targetId;
  final String? targetLabel;

  /// The earliest date asked for across this subject's sheets — they can have
  /// been opened in more than one act, with more than one deadline.
  final DateTime? dueOn;

  final int totalCount;
  final int submittedCount;
  final int overdueCount;

  final double? averagePercent;
  final double? bestPercent;
  final double? worstPercent;

  final List<EvaluationSubjectMember> evaluators;

  int get openCount => totalCount - submittedCount;

  /// How much of the judging is done — sheets finished out of sheets asked
  /// for. Never a mark.
  double get progress => totalCount == 0 ? 0 : submittedCount / totalCount;

  /// Whether there is any mark to show at all. False until somebody submits,
  /// and false forever on a form worth nothing.
  bool get hasMarks => averagePercent != null;

  /// A stable identity for the card, since the row has no id of its own —
  /// the group IS the pair it was grouped by.
  String get key => '$templateId/${targetId ?? 'other'}';

  factory EvaluationSubject.fromMap(Map<String, dynamic> map) =>
      EvaluationSubject(
        templateId: (map['template_id'] as String?) ?? '',
        templateTitle: (map['template_title'] as String?) ?? '',
        target: EvaluationTarget.fromDb(map['target_type'] as String?),
        openedAt: DateTime.parse(map['opened_at'] as String).toLocal(),
        targetId: map['target_id'] as String?,
        targetLabel: map['target_label'] as String?,
        dueOn: _date(map['due_on']),
        totalCount: (map['total_count'] as num?)?.toInt() ?? 0,
        submittedCount: (map['submitted_count'] as num?)?.toInt() ?? 0,
        overdueCount: (map['overdue_count'] as num?)?.toInt() ?? 0,
        averagePercent: _nullableNum(map['avg_percent']),
        bestPercent: _nullableNum(map['best_percent']),
        worstPercent: _nullableNum(map['worst_percent']),
        evaluators: [
          for (final row in (map['evaluators'] as List? ?? const []))
            EvaluationSubjectMember.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
        ],
      );
}

/// One question inside a sheet: what was asked, what may be answered, and what
/// was.
///
/// The same type serves a draft and a finished sheet, because the screen that
/// fills one and the screen that reads the other are the same screen. What
/// differs is where the server read it FROM — a draft from the form, a finished
/// one from its own answers, wording and all, so that editing the form does not
/// reword an appraisal somebody already signed.
class EvaluationSheetQuestion {
  const EvaluationSheetQuestion({
    required this.questionId,
    required this.kind,
    required this.text,
    this.totalPoints = 0,
    this.isRequired = true,
    this.options = const [],
    this.optionId,
    this.answer,
    this.textAnswer,
    this.points = 0,
  });

  /// Null on a finished sheet whose question has since been deleted from the
  /// form. The wording survives it; the pointer does not.
  final String? questionId;

  final EvaluationQuestionKind kind;
  final String text;
  final double totalPoints;
  final bool isRequired;

  /// Empty on a finished sheet: the answers offered are a fact about the form
  /// as it stands, and a signed one is read from what was chosen.
  final List<EvaluationOption> options;

  final String? optionId;

  /// The chosen answer's wording, as it read at the moment it was chosen.
  final String? answer;
  final String? textAnswer;
  final double points;

  bool get isAnswered => kind.isScored
      ? optionId != null
      : (textAnswer != null && textAnswer!.trim().isNotEmpty);

  EvaluationSheetQuestion copyWith({
    String? optionId,
    bool clearOption = false,
    String? textAnswer,
    double? points,
  }) => EvaluationSheetQuestion(
    questionId: questionId,
    kind: kind,
    text: text,
    totalPoints: totalPoints,
    isRequired: isRequired,
    options: options,
    optionId: clearOption ? null : (optionId ?? this.optionId),
    answer: answer,
    textAnswer: textAnswer ?? this.textAnswer,
    points: points ?? this.points,
  );

  factory EvaluationSheetQuestion.fromMap(Map<String, dynamic> map) =>
      EvaluationSheetQuestion(
        questionId: map['question_id'] as String?,
        kind: EvaluationQuestionKind.fromDb(map['kind'] as String?),
        text: (map['text'] as String?) ?? '',
        totalPoints: _num(map['total_points']),
        isRequired: (map['is_required'] as bool?) ?? true,
        options: [
          for (final o in (map['options'] as List?) ?? const [])
            EvaluationOption.fromMap(Map<String, dynamic>.from(o as Map)),
        ],
        optionId: map['option_id'] as String?,
        answer: map['answer'] as String?,
        textAnswer: map['text_answer'] as String?,
        points: _num(map['points']),
      );
}

/// One stage of a sheet, with its running mark.
class EvaluationSheetStage {
  const EvaluationSheetStage({
    required this.title,
    this.description,
    this.questions = const [],
    this.totalPoints = 0,
  });

  final String title;
  final String? description;
  final List<EvaluationSheetQuestion> questions;
  final double totalPoints;

  /// Computed here rather than read from the server's copy: while a draft is
  /// being filled the marks move with every tap, and a number that only
  /// refreshes on save is a number that is wrong most of the time.
  double get points => questions.fold(0, (sum, q) => sum + q.points);

  int get answeredCount => questions.where((q) => q.isAnswered).length;

  bool get isComplete =>
      questions.every((q) => !q.isRequired || q.isAnswered);

  EvaluationSheetStage copyWith({List<EvaluationSheetQuestion>? questions}) =>
      EvaluationSheetStage(
        title: title,
        description: description,
        questions: questions ?? this.questions,
        totalPoints: totalPoints,
      );

  factory EvaluationSheetStage.fromMap(Map<String, dynamic> map) =>
      EvaluationSheetStage(
        title: (map['title'] as String?) ?? '',
        description: map['description'] as String?,
        totalPoints: _num(map['total_points']),
        questions: [
          for (final q in (map['questions'] as List?) ?? const [])
            EvaluationSheetQuestion.fromMap(Map<String, dynamic>.from(q as Map)),
        ],
      );
}

/// A whole sheet: the errand, the form and the filling in one object.
class EvaluationSheet {
  const EvaluationSheet({
    required this.id,
    required this.templateTitle,
    required this.target,
    required this.status,
    required this.myRole,
    this.templateDescription,
    this.targetId,
    this.targetLabel,
    this.note,
    this.dueOn,
    this.createdAt,
    this.submittedAt,
    this.score,
    this.maxScore = 0,
    this.canFill = false,
    this.evaluatorId,
    this.evaluatorName,
    this.evaluatorPhotoUrl,
    this.stages = const [],
  });

  final String id;
  final String templateTitle;
  final String? templateDescription;
  final EvaluationTarget target;
  final String? targetId;
  final String? targetLabel;
  final String? note;
  final DateTime? dueOn;
  final DateTime? createdAt;

  final EvaluationStatus status;
  final DateTime? submittedAt;

  /// Null while it is a draft: there is no score until it is finished, and a
  /// running total shown as a score is a mark somebody would quote.
  final double? score;
  final double maxScore;

  /// Whether THIS reader may write into it, as the server decided. Not derived
  /// from [myRole] and [status] on the client — the server already answered it,
  /// and two answers is one too many.
  final bool canFill;

  final String? evaluatorId;
  final String? evaluatorName;
  final String? evaluatorPhotoUrl;
  final EvaluationRole myRole;

  final List<EvaluationSheetStage> stages;

  /// True when the evaluator's name did not come over the wire at all, which is
  /// the shape the subject reads it in.
  bool get isEvaluatorHidden => evaluatorId == null;

  double get points => stages.fold(0, (sum, s) => sum + s.points);
  int get questionCount => stages.fold(0, (sum, s) => sum + s.questions.length);
  int get answeredCount => stages.fold(0, (sum, s) => sum + s.answeredCount);

  /// Every required question, in every stage, has an answer.
  bool get isComplete => stages.every((s) => s.isComplete);

  /// The first stage that is still missing something, so the button that
  /// refuses to submit can say WHERE rather than merely no.
  int get firstIncompleteStage => stages.indexWhere((s) => !s.isComplete);

  double? get percent => maxScore > 0 ? (points * 100 / maxScore) : null;

  EvaluationSheet copyWith({List<EvaluationSheetStage>? stages}) =>
      EvaluationSheet(
        id: id,
        templateTitle: templateTitle,
        templateDescription: templateDescription,
        target: target,
        targetId: targetId,
        targetLabel: targetLabel,
        note: note,
        dueOn: dueOn,
        createdAt: createdAt,
        status: status,
        submittedAt: submittedAt,
        score: score,
        maxScore: maxScore,
        canFill: canFill,
        evaluatorId: evaluatorId,
        evaluatorName: evaluatorName,
        evaluatorPhotoUrl: evaluatorPhotoUrl,
        myRole: myRole,
        stages: stages ?? this.stages,
      );

  factory EvaluationSheet.fromMap(Map<String, dynamic> map) => EvaluationSheet(
    id: map['id'] as String,
    templateTitle: (map['template_title'] as String?) ?? '',
    templateDescription: map['template_description'] as String?,
    target: EvaluationTarget.fromDb(map['target_type'] as String?),
    targetId: map['target_id'] as String?,
    targetLabel: map['target_label'] as String?,
    note: map['note'] as String?,
    dueOn: _date(map['due_on']),
    createdAt: _date(map['created_at']),
    status: EvaluationStatus.fromDb(map['status'] as String?),
    submittedAt: _date(map['submitted_at']),
    score: _nullableNum(map['score']),
    maxScore: _num(map['max_score']),
    canFill: (map['can_fill'] as bool?) ?? false,
    evaluatorId: map['evaluator_id'] as String?,
    evaluatorName: map['evaluator_name'] as String?,
    evaluatorPhotoUrl: map['evaluator_photo_url'] as String?,
    myRole: EvaluationRole.fromDb(map['my_role'] as String?),
    stages: [
      for (final s in (map['stages'] as List?) ?? const [])
        EvaluationSheetStage.fromMap(Map<String, dynamic>.from(s as Map)),
    ],
  );
}

/// One finished appraisal as its own subject reads it: a title, a date and two
/// numbers. There is no evaluator here, and that is not a field left empty —
/// `evaluations_about_me` does not select the column.
class MyEvaluation {
  const MyEvaluation({
    required this.id,
    required this.templateTitle,
    this.submittedAt,
    this.score,
    this.maxScore,
    this.percent,
  });

  final String id;
  final String templateTitle;
  final DateTime? submittedAt;
  final double? score;
  final double? maxScore;
  final double? percent;

  factory MyEvaluation.fromMap(Map<String, dynamic> map) => MyEvaluation(
    id: map['id'] as String,
    templateTitle: (map['template_title'] as String?) ?? '',
    submittedAt: _date(map['submitted_at']),
    score: _nullableNum(map['score']),
    maxScore: _nullableNum(map['max_score']),
    percent: _nullableNum(map['percent']),
  );
}

/// The numbers at the foot of a subject's page — a person's, a file's, a
/// hotel's. Counts and an average, and never a name.
class EvaluationStanding {
  const EvaluationStanding({
    this.submittedCount = 0,
    this.pendingCount = 0,
    this.averageScore,
    this.averagePercent,
    this.lastSubmittedAt,
  });

  final int submittedCount;

  /// Sheets out and not yet finished. Shown to a manager as work in hand; never
  /// shown to the subject, who has no business watching an appraisal of himself
  /// being written.
  final int pendingCount;

  final double? averageScore;
  final double? averagePercent;
  final DateTime? lastSubmittedAt;

  bool get isEmpty => submittedCount == 0 && pendingCount == 0;

  factory EvaluationStanding.fromMap(Map<String, dynamic> map) =>
      EvaluationStanding(
        submittedCount: (map['submitted_count'] as num?)?.toInt() ?? 0,
        pendingCount: (map['pending_count'] as num?)?.toInt() ?? 0,
        averageScore: _nullableNum(map['average_score']),
        averagePercent: _nullableNum(map['average_percent']),
        lastSubmittedAt: _date(map['last_submitted_at']),
      );
}

/// Postgres `numeric` arrives as a String over PostgREST when it does not fit a
/// double cleanly, and as a num when it does. Both, every time, rather than a
/// cast that works until the first mark of 7.5.
double _num(Object? raw) => _nullableNum(raw) ?? 0;

double? _nullableNum(Object? raw) => switch (raw) {
  null => null,
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

DateTime? _date(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
