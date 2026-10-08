import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/overflow_menu.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../application/evaluation_editor_cubit.dart';
import '../application/evaluations_cubit.dart';
import '../data/evaluations_repository.dart';
import '../domain/evaluation.dart';
import 'assign_evaluation_screen.dart';
import 'evaluation_sheet_screen.dart';
import 'evaluations_screen.dart';
import 'widgets/evaluation_labels.dart';

/// Building a form: stages, questions, answers, marks.
///
/// The whole tree is held here and written in one call. Nothing talks to the
/// database per keystroke — a form is edited for ten minutes and saved once,
/// and a stage created by its first character would leave an empty stage behind
/// every abandoned edit.
///
/// The stages are steps rather than one long column for the same reason the
/// filling screen makes them steps: a form of six stages is six screens of
/// questions, and showing them at once is what the stage exists to prevent.
class EvaluationEditorScreen extends StatelessWidget {
  const EvaluationEditorScreen({
    super.key,
    this.templateId,
    this.isInUse = false,
  });

  /// Null to create.
  final String? templateId;

  /// Sheets have been opened on it. Narrow in effect — only the subject kind is
  /// frozen — but the editor has to know, because the database refuses the
  /// change and an error at save is worse than a disabled control.
  final bool isInUse;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => EvaluationEditorCubit(
      EvaluationsRepository(),
      templateId: templateId,
      isInUse: isInUse,
    ),
    child: const _View(),
  );
}

class _View extends StatelessWidget {
  const _View();

  Future<void> _save(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<EvaluationEditorCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final id = await cubit.save();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            id == null
                ? friendlyErrorL(l, cubit.state.error)
                : l.evaluationEditorSaved,
          ),
        ),
      );
  }

  /// The sheets standing on this form — and the way out of the dead end when
  /// deleting is refused because of them.
  Future<void> _openEvaluations(BuildContext context) async {
    final cubit = context.read<EvaluationEditorCubit>();
    final id = cubit.templateId;
    if (id == null) return;
    await Navigator.of(context).push(
      fadeThroughRoute(
        (_) => EvaluationsScreen(
          scope: EvaluationsScope.all,
          templateId: id,
          title: cubit.state.form.title,
        ),
      ),
    );
  }

  /// Deleting the form from the screen that shows it whole.
  ///
  /// The list has this too, and both are wanted: there it is a decision about
  /// a card, here it is a decision about the questions you have just read.
  Future<void> _delete(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<EvaluationEditorCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Said before the dialog rather than after the refusal: the database will
    // refuse it — `on delete restrict` — and being told why in advance is the
    // difference between a rule and a failure.
    if (cubit.state.isInUse) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l.evaluationFormInUseDelete),
            // Not merely "you cannot": here is where they are.
            action: SnackBarAction(
              label: l.evaluationFormShowEvaluations,
              onPressed: () => _openEvaluations(context),
            ),
          ),
        );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(cubit.state.form.title),
        content: Text(l.evaluationFormDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final error = await cubit.delete();
    messenger.hideCurrentSnackBar();
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorL(l, error))),
      );
      return;
    }
    // Straight out. The cubit dropped the dirty flag on the way, so the
    // PopScope above lets this through rather than asking whether to keep
    // edits to a form that is gone.
    navigator.pop(true);
    messenger.showSnackBar(SnackBar(content: Text(l.evaluationFormDeleted)));
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    final l = context.l10n;
    if (!context.read<EvaluationEditorCubit>().state.isDirty) return true;

    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l.evaluationDiscardChanges),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.commonDone),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return BlocBuilder<EvaluationEditorCubit, EvaluationEditorState>(
      builder: (context, state) {
        final cubit = context.read<EvaluationEditorCubit>();

        return PopScope(
          canPop: !state.isDirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (await _confirmLeave(context) && context.mounted) {
              Navigator.of(context).pop(cubit.templateId != null);
            }
          },
          child: Scaffold(
            appBar: GlassAppBar(
              title: Text(
                cubit.templateId == null
                    ? l.evaluationEditorNewTitle
                    : l.evaluationEditorTitle,
              ),
              actions: [
                // Only on a form the server has seen — there is nothing to
                // delete, and nothing to list sheets against, until then. Left
                // OUT rather than disabled for a reader without the trust: a
                // greyed-out Delete says the form can be deleted and that they
                // are the wrong person, which is more than this screen means.
                if (cubit.templateId != null &&
                    context.watch<SessionCubit>().state.can(
                      PermissionCodes.evaluationsTemplates,
                    ))
                  OverflowMenu(
                    actions: [
                      MenuAction(
                        icon: AppIcons.evaluations,
                        label: l.evaluationFormShowEvaluations,
                        onSelected: () => _openEvaluations(context),
                      ),
                      MenuAction(
                        icon: AppIcons.delete,
                        label: l.evaluationFormDelete,
                        isDestructive: true,
                        onSelected: () => _delete(context),
                      ),
                    ],
                  ),
              ],
            ),
            body: SafeArea(
              child: switch (state.status) {
                EvaluationEditorStatus.loading => const Center(
                  child: AppLoader(),
                ),
                EvaluationEditorStatus.error => EmptyState(
                  icon: AppIcons.evaluationForms,
                  title: friendlyError(context, state.error),
                  action: FilledButton(
                    onPressed: cubit.load,
                    child: Text(l.commonRetry),
                  ),
                ),
                _ => _Editor(state: state),
              },
            ),
            bottomNavigationBar: state.status == EvaluationEditorStatus.loading
                ? null
                : _Bar(
                    state: state,
                    templateId: cubit.templateId,
                    onSave: () => _save(context),
                  ),
          ),
        );
      },
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.state});
  final EvaluationEditorState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EvaluationEditorCubit>();
    final index = state.form.stages.isEmpty
        ? 0
        : state.stageIndex.clamp(0, state.form.stages.length - 1);

    return ResponsivePage(
      width: PageWidth.editor,
      builder: (context, size) => SinglePaneLayout(
        gutter: size.gutter,
        children: [
          _HeaderCard(state: state),
          const SizedBox(height: AppSpacing.lg),
          _StageTabs(state: state, index: index),
          const SizedBox(height: AppSpacing.md),
          if (state.form.stages.isNotEmpty) ...[
            // Keyed on the stage's identity, so the text controllers below are
            // rebuilt rather than carrying one stage's words into the next.
            _StageCard(
              key: ValueKey('stage-$index-${state.form.stages[index].id}'),
              stage: state.form.stages[index],
              index: index,
              canRemove: state.form.stages.length > 1,
            ),
            const SizedBox(height: AppSpacing.md),
            for (var q = 0; q < state.form.stages[index].questions.length; q++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _QuestionCard(
                  key: ValueKey(
                    'q-$index-$q-${state.form.stages[index].questions[q].id}',
                  ),
                  question: state.form.stages[index].questions[q],
                  stageIndex: index,
                  questionIndex: q,
                  isLast:
                      q == state.form.stages[index].questions.length - 1,
                ),
              ),
            if (state.form.stages[index].questions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  context.l10n.evaluationEditorNoQuestions,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => cubit.addQuestion(
                      index,
                      EvaluationQuestionKind.choice,
                    ),
                    icon: const Icon(AppIcons.evaluationChoice, size: 18),
                    label: Text(context.l10n.evaluationEditorAddChoice),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => cubit.addQuestion(
                      index,
                      EvaluationQuestionKind.text,
                    ),
                    icon: const Icon(AppIcons.evaluationWritten, size: 18),
                    label: Text(context.l10n.evaluationEditorAddWritten),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The form's name, what it judges, and whether it may be handed out.
class _HeaderCard extends StatefulWidget {
  const _HeaderCard({required this.state});
  final EvaluationEditorState state;

  @override
  State<_HeaderCard> createState() => _HeaderCardState();
}

class _HeaderCardState extends State<_HeaderCard> {
  late final _title = TextEditingController(text: widget.state.form.title);
  late final _description = TextEditingController(
    text: widget.state.form.description ?? '',
  );

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _HeaderCard old) {
    super.didUpdateWidget(old);
    // After a save the form comes back from the server with server-minted ids.
    // The words are the same words, so the controllers are only re-seeded when
    // they genuinely differ — resetting them on every rebuild would move the
    // caret to the start on every keystroke.
    if (_title.text != widget.state.form.title) {
      _title.text = widget.state.form.title;
    }
    final description = widget.state.form.description ?? '';
    if (_description.text != description) _description.text = description;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<EvaluationEditorCubit>();
    final form = widget.state.form;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            onChanged: cubit.setTitle,
            decoration: InputDecoration(
              labelText: l.evaluationEditorName,
              hintText: l.evaluationEditorNameHint,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _description,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: cubit.setDescription,
            decoration: InputDecoration(
              labelText: l.evaluationEditorDescription,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l.evaluationEditorFor, style: text.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final target in EvaluationTarget.values)
                ChoiceChip(
                  label: Text(evaluationTargetLabel(l, target)),
                  avatar: Icon(evaluationTargetIcon(target), size: 16),
                  selected: form.target == target,
                  visualDensity: VisualDensity.compact,
                  onSelected: widget.state.isInUse
                      ? null
                      : (_) => cubit.setTarget(target),
                ),
            ],
          ),
          // What the chip above does NOT mean, said out loud, because it is the
          // thing everybody reads it as: choosing «ملف تشغيلي» here does not
          // pick a file. A form is written once for a KIND of subject and then
          // opened again and again against different ones — and WHICH one is
          // named at the moment the evaluation is opened, on the card in this
          // same section. Without this line the chip looks like a picker whose
          // list failed to load.
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.warning, size: 16, color: scheme.secondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l.evaluationEditorForHint,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (widget.state.isInUse) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.evaluationEditorForLocked,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            value: form.isActive,
            contentPadding: EdgeInsets.zero,
            title: Text(l.evaluationEditorPublish),
            subtitle: Text(
              // The reason it cannot be switched on, when it cannot: a disabled
              // switch with no sentence beside it is a dead control.
              form.canPublish || !form.isActive
                  ? l.evaluationEditorPublishHint
                  : l.evaluationEditorCannotPublish,
              style: text.bodySmall,
            ),
            onChanged: (v) {
              if (v && !form.canPublish) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(l.evaluationEditorCannotPublish)),
                  );
                return;
              }
              cubit.setActive(v);
            },
          ),
        ],
      ),
    );
  }
}

class _StageTabs extends StatelessWidget {
  const _StageTabs({required this.state, required this.index});

  final EvaluationEditorState state;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<EvaluationEditorCubit>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < state.form.stages.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                selected: i == index,
                visualDensity: VisualDensity.compact,
                avatar: const Icon(AppIcons.evaluationStage, size: 16),
                label: Text(
                  state.form.stages[i].title.trim().isEmpty
                      ? '${l.evaluationEditorStageName} ${i + 1}'
                      : '${i + 1}. ${state.form.stages[i].title}',
                ),
                onSelected: (_) => cubit.goToStage(i),
              ),
            ),
          ActionChip(
            avatar: const Icon(AppIcons.add, size: 16),
            label: Text(l.evaluationEditorAddStage),
            visualDensity: VisualDensity.compact,
            onPressed: cubit.addStage,
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatefulWidget {
  const _StageCard({
    super.key,
    required this.stage,
    required this.index,
    required this.canRemove,
  });

  final EvaluationStage stage;
  final int index;

  /// A form with no stage has nowhere to put a question, so
  /// [EvaluationEditorCubit.removeStage] refuses to leave it empty — deleting
  /// the last stage just hands back an identical blank one. Hiding the
  /// control here is the honest version of that refusal: without it, the
  /// last stage's delete button looks broken rather than unavailable.
  final bool canRemove;

  @override
  State<_StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<_StageCard> {
  late final _title = TextEditingController(text: widget.stage.title);
  late final _description = TextEditingController(
    text: widget.stage.description ?? '',
  );

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _remove() async {
    final l = context.l10n;
    final cubit = context.read<EvaluationEditorCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l.evaluationEditorRemoveStageConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok == true) cubit.removeStage(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<EvaluationEditorCubit>();
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) => cubit.setStageTitle(widget.index, v),
                  decoration: InputDecoration(
                    labelText: l.evaluationEditorStageName,
                    hintText: l.evaluationEditorStageNameHint,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.evaluationEditorMoveUp,
                onPressed: widget.index == 0
                    ? null
                    : () => cubit.moveStage(widget.index, widget.index - 1),
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                tooltip: l.evaluationEditorMoveDown,
                onPressed: () =>
                    cubit.moveStage(widget.index, widget.index + 1),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              if (widget.canRemove)
                IconButton(
                  tooltip: l.evaluationEditorRemoveStage,
                  onPressed: _remove,
                  icon: Icon(AppIcons.delete, color: scheme.error),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _description,
            minLines: 1,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) => cubit.setStageDescription(widget.index, v),
            decoration: InputDecoration(
              labelText: l.evaluationEditorStageDescription,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GlassBadge(
              label: l.evaluationFormTotal(
                formatMark(widget.stage.totalPoints),
              ),
              icon: AppIcons.evaluationScore,
              color: scheme.secondary,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// One question: its words, its mark, whether it is compulsory, and — for a
/// choice — its answers with what each one earns.
class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.stageIndex,
    required this.questionIndex,
    required this.isLast,
  });

  final EvaluationQuestion question;
  final int stageIndex;
  final int questionIndex;
  final bool isLast;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late final _text = TextEditingController(text: widget.question.text);
  late final _points = TextEditingController(
    text: widget.question.points == 0 ? '' : formatMark(widget.question.points),
  );

  @override
  void dispose() {
    _text.dispose();
    _points.dispose();
    super.dispose();
  }

  void _edit(EvaluationQuestion Function(EvaluationQuestion) change) => context
      .read<EvaluationEditorCubit>()
      .editQuestion(widget.stageIndex, widget.questionIndex, change);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<EvaluationEditorCubit>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final q = widget.question;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(evaluationKindIcon(q.kind), size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                evaluationKindLabel(l, q.kind),
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: l.evaluationEditorMoveUp,
                visualDensity: VisualDensity.compact,
                onPressed: widget.questionIndex == 0
                    ? null
                    : () => cubit.moveQuestion(
                        widget.stageIndex,
                        widget.questionIndex,
                        widget.questionIndex - 1,
                      ),
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                tooltip: l.evaluationEditorMoveDown,
                visualDensity: VisualDensity.compact,
                onPressed: widget.isLast
                    ? null
                    : () => cubit.moveQuestion(
                        widget.stageIndex,
                        widget.questionIndex,
                        widget.questionIndex + 1,
                      ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => cubit.removeQuestion(
                  widget.stageIndex,
                  widget.questionIndex,
                ),
                icon: Icon(AppIcons.delete, size: 20, color: scheme.error),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _text,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) => _edit((old) => old.copyWith(text: v)),
            decoration: InputDecoration(
              labelText: l.evaluationEditorQuestionText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (q.kind.isScored)
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _points,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => _edit(
                      (old) =>
                          old.copyWith(points: double.tryParse(v.trim()) ?? 0),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l.evaluationEditorQuestionPoints,
                    ),
                  ),
                ),
              if (q.kind.isScored) const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SwitchListTile(
                  value: q.isRequired,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l.evaluationEditorRequired, style: text.bodyMedium),
                  onChanged: (v) => _edit((old) => old.copyWith(isRequired: v)),
                ),
              ),
            ],
          ),
          if (!q.kind.isScored)
            Text(
              l.evaluationEditorWrittenNote,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            )
          else ...[
            // Two things the office needs telling before the first sheet comes
            // back four marks short. Neither is refused — a half-edited form is
            // a normal state to be in — but both are said.
            if (q.options.length < 2)
              _Warning(message: l.evaluationEditorNeedsTwoOptions)
            else if (q.isUnreachable)
              _Warning(
                message: l.evaluationEditorUnreachable(
                  formatMark(q.bestAnswerPoints),
                  formatMark(q.points),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < q.options.length; i++)
              _OptionRow(
                key: ValueKey('opt-$i-${q.options[i].id}'),
                option: q.options[i],
                stageIndex: widget.stageIndex,
                questionIndex: widget.questionIndex,
                optionIndex: i,
                // A choice needs two answers to be a choice, so the last two
                // cannot be removed one at a time down to nothing.
                canRemove: q.options.length > 2,
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => cubit.addOption(
                  widget.stageIndex,
                  widget.questionIndex,
                ),
                icon: const Icon(AppIcons.add, size: 18),
                label: Text(l.evaluationEditorAddOption),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatefulWidget {
  const _OptionRow({
    super.key,
    required this.option,
    required this.stageIndex,
    required this.questionIndex,
    required this.optionIndex,
    required this.canRemove,
  });

  final EvaluationOption option;
  final int stageIndex;
  final int questionIndex;
  final int optionIndex;
  final bool canRemove;

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  late final _text = TextEditingController(text: widget.option.text);
  late final _points = TextEditingController(
    text: widget.option.points == 0 ? '' : formatMark(widget.option.points),
  );

  @override
  void dispose() {
    _text.dispose();
    _points.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<EvaluationEditorCubit>();
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => cubit.setOptionText(
                widget.stageIndex,
                widget.questionIndex,
                widget.optionIndex,
                v,
              ),
              decoration: InputDecoration(
                isDense: true,
                labelText: l.evaluationEditorOptionText,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 96,
            child: TextField(
              controller: _points,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) => cubit.setOptionPoints(
                widget.stageIndex,
                widget.questionIndex,
                widget.optionIndex,
                double.tryParse(v.trim()) ?? 0,
              ),
              decoration: InputDecoration(
                isDense: true,
                labelText: l.evaluationEditorOptionPoints,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: widget.canRemove
                ? () => cubit.removeOption(
                    widget.stageIndex,
                    widget.questionIndex,
                    widget.optionIndex,
                  )
                : null,
            icon: Icon(AppIcons.reject, size: 18, color: scheme.error),
          ),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.warning, size: 16, color: scheme.tertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.state,
    required this.templateId,
    required this.onSave,
  });

  final EvaluationEditorState state;

  /// Null until the form has been saved once. Nothing can be opened on a form
  /// the server has never seen.
  final String? templateId;

  final VoidCallback onSave;

  /// The step after saving, and the answer to the question this screen kept
  /// being asked: choosing «ملف تشغيلي» above picks a KIND, and this is where
  /// the particular file gets named. Without it a person finishes a form and is
  /// left on a screen with no visible way forward — they go back, and the next
  /// thing they look for is the picker that was never on this page.
  Future<void> _assign(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<EvaluationEditorCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final opened = await openAssignEvaluation(context, templateId: templateId!);
    // The count of what is open on this form moved, and the editor shows it.
    await cubit.load();
    if (opened == null || !context.mounted) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.evaluationAssignedMany(opened.count)),
          action: SnackBarAction(
            label: l.evaluationAssignedShow,
            onPressed: () => Navigator.of(context).push(
              fadeThroughRoute(
                (_) => EvaluationSheetScreen(
                  evaluationId: opened.firstId,
                  canReopen: true,
                ),
              ),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final saving = state.status == EvaluationEditorStatus.saving;

    /// Whether the Save button has anything to be about.
    final hasEdits = templateId == null || state.isDirty || saving;

    // Every one of these has to hold. A form the server has not seen cannot be
    // assigned; one that is switched off is refused by the database; and one
    // with unsaved edits would be opened against the version on the server
    // rather than the one on screen — which is the worst of the three, because
    // it would look like it worked.
    final canAssign =
        templateId != null &&
        state.form.isActive &&
        !state.isDirty &&
        !saving &&
        context.watch<SessionCubit>().state.can(
          PermissionCodes.evaluationsAssign,
        );

    return GlassSurface(
      radius: 0,
      strong: true,
      shadow: false,
      bordered: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The form's total, always visible while it is being written. It
              // is the number the office is actually building toward, and it
              // moves with every mark typed.
              Text(
                l.evaluationEditorTotal(formatMark(state.form.totalPoints)),
                style: text.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (canAssign) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _assign(context),
                        icon: const Icon(AppIcons.add, size: 18),
                        label: Text(l.evaluationsNew),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  // Absent, not disabled, on a saved form with nothing changed
                  // on it — which is how this screen stands most of the time it
                  // is open, because it is also where a form is READ. A Save
                  // button over an untouched form is an unfinished errand that
                  // does not exist; it comes back the moment a word is typed,
                  // and its absence is what tells you the work is in.
                  //
                  // A form the server has never seen keeps it throughout, in
                  // the disabled state, because there the button is the whole
                  // point of the screen and hiding it would leave a new form
                  // with no visible way to become one.
                  if (hasEdits)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: state.canSave && !saving ? onSave : null,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Icon(AppIcons.selected, size: 18),
                        label: Text(l.evaluationEditorSave),
                      ),
                    ),
                ],
              ),
              // Why the button above is absent on a form that is otherwise
              // finished. Said rather than left to be worked out.
              if (templateId != null &&
                  !state.form.isActive &&
                  state.form.canPublish) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.evaluationFormMustBeActive,
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
