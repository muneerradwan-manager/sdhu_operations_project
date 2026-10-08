import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../application/evaluation_sheet_cubit.dart';
import '../data/evaluations_repository.dart';
import '../domain/evaluation.dart';
import 'widgets/evaluation_labels.dart';
import 'widgets/score_bar.dart';

/// One sheet, filled or read.
///
/// The same screen for both, because the server answers both with the same
/// call. What differs is `canFill`, which the server decides — and which is the
/// only thing this screen consults before drawing a radio or a written answer.
///
/// The stages are STEPS rather than a single scroll: a form of sixty questions
/// is unreadable in one column, and the stepper is what a مرحلة is for on a
/// screen. The stage that is short of a required answer is where the submit
/// button sends the reader, because "something is missing" without saying where
/// is a form somebody scrolls twice and abandons.
class EvaluationSheetScreen extends StatelessWidget {
  const EvaluationSheetScreen({
    super.key,
    required this.evaluationId,
    this.canReopen = false,
  });

  final String evaluationId;

  /// Whether this reader may send a finished sheet back. `evaluations.assign`;
  /// the server refuses it to anybody else, so this only decides whether the
  /// menu item is drawn.
  final bool canReopen;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => EvaluationSheetCubit(EvaluationsRepository(), evaluationId),
    child: _View(canReopen: canReopen),
  );
}

class _View extends StatelessWidget {
  const _View({required this.canReopen});
  final bool canReopen;

  Future<void> _saveDraft(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<EvaluationSheetCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final error = await cubit.saveDraft();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error == null ? l.evaluationDraftSaved : friendlyErrorL(l, error),
          ),
        ),
      );
  }

  Future<void> _submit(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<EvaluationSheetCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final error = await cubit.submit();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error == null ? l.evaluationSubmitted : friendlyErrorL(l, error),
          ),
        ),
      );
  }

  Future<void> _reopen(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<EvaluationSheetCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l.evaluationReopenConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.evaluationReopen),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final error = await cubit.reopen();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error == null ? l.evaluationReopened : friendlyErrorL(l, error),
          ),
        ),
      );
  }

  /// Leaving with answers in hand that the server has not been told about.
  /// Asked rather than saved silently: a save is an act, and one the reader did
  /// not ask for is one they cannot undo.
  Future<bool> _confirmLeave(BuildContext context) async {
    final l = context.l10n;
    final state = context.read<EvaluationSheetCubit>().state;
    if (!state.isDirty || !state.canFill) return true;

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

    return BlocBuilder<EvaluationSheetCubit, EvaluationSheetState>(
      builder: (context, state) {
        final sheet = state.sheet;
        final cubit = context.read<EvaluationSheetCubit>();

        return PopScope(
          canPop: !(state.isDirty && state.canFill),
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (await _confirmLeave(context) && context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
          child: Scaffold(
            appBar: GlassAppBar(
              title: Text(sheet?.templateTitle ?? l.evaluationSheetTitle),
              actions: [
                if (canReopen && (sheet?.status.isSubmitted ?? false))
                  IconButton(
                    tooltip: l.evaluationReopen,
                    onPressed: () => _reopen(context),
                    icon: const Icon(AppIcons.edit),
                  ),
              ],
            ),
            body: SafeArea(
              child: switch (state.status) {
                EvaluationSheetStatus.loading => const Center(
                  child: AppLoader(),
                ),
                EvaluationSheetStatus.error => EmptyState(
                  icon: AppIcons.evaluations,
                  title: friendlyError(context, state.error),
                  action: FilledButton(
                    onPressed: cubit.load,
                    child: Text(l.commonRetry),
                  ),
                ),
                _ when sheet == null => const SizedBox.shrink(),
                _ => _Sheet(state: state, sheet: sheet),
              },
            ),
            bottomNavigationBar: sheet == null || state.status ==
                    EvaluationSheetStatus.error
                ? null
                : _Bar(
                    state: state,
                    sheet: sheet,
                    onSave: () => _saveDraft(context),
                    onSubmit: () => _submit(context),
                  ),
          ),
        );
      },
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.state, required this.sheet});

  final EvaluationSheetState state;
  final EvaluationSheet sheet;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    if (sheet.stages.isEmpty) {
      return EmptyState(
        icon: AppIcons.evaluations,
        title: l.evaluationEditorNoQuestions,
      );
    }

    final index = state.stageIndex.clamp(0, sheet.stages.length - 1);
    final stage = sheet.stages[index];

    return ResponsivePage(
      width: PageWidth.reading,
      builder: (context, size) => SinglePaneLayout(
        gutter: size.gutter,
        // Rebuilt from scratch when the stage changes, so a written answer's
        // controller does not carry the previous stage's text into the next
        // one's box.
        key: ValueKey(index),
        children: [
          _Header(sheet: sheet),
          const SizedBox(height: AppSpacing.md),
          _Stepper(sheet: sheet, index: index),
          const SizedBox(height: AppSpacing.lg),
          _StageHead(stage: stage, index: index, total: sheet.stages.length),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < stage.questions.length; i++) ...[
            _QuestionCard(
              question: stage.questions[i],
              stageIndex: index,
              questionIndex: i,
              editable: state.canFill,
              showMissing: state.showMissing,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// Who and what this sheet is about, and — when it is finished — its mark.
class _Header extends StatelessWidget {
  const _Header({required this.sheet});
  final EvaluationSheet sheet;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final subject = (sheet.targetLabel ?? '').trim().isEmpty
        ? evaluationTargetLabel(l, sheet.target)
        : sheet.targetLabel!;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(evaluationTargetIcon(sheet.target), color: scheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.evaluationSubject,
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(subject, style: text.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          if ((sheet.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            GlassSurface(
              subtle: true,
              blur: false,
              shadow: false,
              bordered: false,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.notifications, size: 18, color: scheme.secondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(sheet.note!, style: text.bodySmall),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              GlassBadge(
                label: sheet.status.isSubmitted
                    ? l.evaluationStatusSubmitted
                    : l.evaluationStatusDraft,
                icon: sheet.status.isSubmitted
                    ? AppIcons.approve
                    : AppIcons.pending,
                color: sheet.status.isSubmitted
                    ? scheme.primary
                    : scheme.tertiary,
                dense: true,
              ),
              if (sheet.dueOn != null && !sheet.status.isSubmitted)
                GlassBadge(
                  label: l.evaluationDueOn(formatDate(sheet.dueOn)),
                  icon: AppIcons.seasons,
                  dense: true,
                ),
              // The evaluator is named only to a reader who may know. To the
              // subject the field does not arrive at all, and the badge says so
              // out loud rather than leaving a gap somebody would read as a bug.
              GlassBadge(
                label: sheet.isEvaluatorHidden
                    ? l.evaluationEvaluatorHidden
                    : (sheet.evaluatorName ?? l.evaluationEvaluator),
                icon: sheet.isEvaluatorHidden
                    ? AppIcons.shield
                    : AppIcons.employees,
                color: sheet.isEvaluatorHidden ? scheme.onSurfaceVariant : null,
                dense: true,
              ),
            ],
          ),
          if (sheet.status.isSubmitted) ...[
            const SizedBox(height: AppSpacing.lg),
            ScoreBar(score: sheet.points, total: sheet.maxScore),
          ],
        ],
      ),
    );
  }
}

/// The stages, as a row of taps. Each one carries whether it is complete, so a
/// reader on stage 3 can see that stage 1 still has a hole in it.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.sheet, required this.index});

  final EvaluationSheet sheet;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EvaluationSheetCubit>();
    final scheme = Theme.of(context).colorScheme;

    if (sheet.stages.length < 2) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < sheet.stages.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                selected: i == index,
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  sheet.stages[i].isComplete
                      ? AppIcons.approve
                      : AppIcons.evaluationStage,
                  size: 16,
                  color: sheet.stages[i].isComplete ? scheme.primary : null,
                ),
                label: Text('${i + 1}. ${sheet.stages[i].title}'),
                onSelected: (_) => cubit.goToStage(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _StageHead extends StatelessWidget {
  const _StageHead({
    required this.stage,
    required this.index,
    required this.total,
  });

  final EvaluationSheetStage stage;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.evaluationStageOf(index + 1, total),
          style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(stage.title, style: text.titleLarge),
        if ((stage.description ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            stage.description!,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        if (stage.totalPoints > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.evaluationStageScore(
              formatMark(stage.points),
              formatMark(stage.totalPoints),
            ),
            style: text.labelMedium?.copyWith(color: scheme.secondary),
          ),
        ],
      ],
    );
  }
}

/// One question and its answer.
///
/// A choice draws its answers as a radio list with each one's mark beside it —
/// the evaluator is being asked to award a number, and hiding what each answer
/// is worth would be asking them to award it blind. A written question draws a
/// box and says nothing about marks, because it has none.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.stageIndex,
    required this.questionIndex,
    required this.editable,
    required this.showMissing,
  });

  final EvaluationSheetQuestion question;
  final int stageIndex;
  final int questionIndex;
  final bool editable;
  final bool showMissing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final missing = showMissing && question.isRequired && !question.isAnswered;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  question.text,
                  style: text.titleSmall?.copyWith(
                    color: missing ? scheme.error : null,
                  ),
                ),
              ),
              if (question.kind.isScored) ...[
                const SizedBox(width: AppSpacing.sm),
                GlassBadge(
                  label: formatScore(question.points, question.totalPoints),
                  icon: AppIcons.evaluationScore,
                  color: question.isAnswered ? scheme.primary : null,
                  dense: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              GlassBadge(
                label: question.isRequired
                    ? l.evaluationQuestionRequired
                    : l.evaluationQuestionOptional,
                color: question.isRequired
                    ? (missing ? scheme.error : scheme.secondary)
                    : scheme.onSurfaceVariant,
                dense: true,
              ),
              if (missing)
                GlassBadge(
                  label: l.evaluationQuestionUnanswered,
                  icon: AppIcons.warning,
                  color: scheme.error,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (question.kind.isScored)
            _Choices(
              question: question,
              stageIndex: stageIndex,
              questionIndex: questionIndex,
              editable: editable,
            )
          else
            _Written(
              question: question,
              stageIndex: stageIndex,
              questionIndex: questionIndex,
              editable: editable,
            ),
        ],
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.question,
    required this.stageIndex,
    required this.questionIndex,
    required this.editable,
  });

  final EvaluationSheetQuestion question;
  final int stageIndex;
  final int questionIndex;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EvaluationSheetCubit>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // A finished sheet has no options to offer: it is read from what was
    // chosen, in the wording it was chosen under. So the chosen answer is drawn
    // on its own rather than as one of a list nobody may change.
    if (question.options.isEmpty) {
      return Row(
        children: [
          Icon(AppIcons.selected, size: 18, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(question.answer ?? '—', style: text.bodyMedium),
          ),
        ],
      );
    }

    return Column(
      children: [
        for (final option in question.options)
          RadioListTile<String?>(
            value: option.id,
            // ignore: deprecated_member_use
            groupValue: question.optionId,
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            controlAffinity: ListTileControlAffinity.leading,
            // Tapping the chosen one again clears it, which is the only way to
            // un-answer an optional question a radio row offers.
            // ignore: deprecated_member_use
            onChanged: editable
                ? (value) =>
                      cubit.choose(stageIndex, questionIndex, value)
                : null,
            title: Row(
              children: [
                Expanded(child: Text(option.text, style: text.bodyMedium)),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  formatMark(option.points),
                  style: text.labelMedium?.copyWith(
                    color: option.id == question.optionId
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Written extends StatefulWidget {
  const _Written({
    required this.question,
    required this.stageIndex,
    required this.questionIndex,
    required this.editable,
  });

  final EvaluationSheetQuestion question;
  final int stageIndex;
  final int questionIndex;
  final bool editable;

  @override
  State<_Written> createState() => _WrittenState();
}

class _WrittenState extends State<_Written> {
  late final _controller = TextEditingController(
    text: widget.question.textAnswer ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (!widget.editable) {
      final written = (widget.question.textAnswer ?? '').trim();
      return Text(
        written.isEmpty ? '—' : written,
        style: text.bodyMedium?.copyWith(
          color: written.isEmpty ? scheme.onSurfaceVariant : null,
          fontStyle: written.isEmpty ? FontStyle.italic : null,
        ),
      );
    }

    return TextField(
      controller: _controller,
      minLines: 3,
      maxLines: 8,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (value) => context.read<EvaluationSheetCubit>().write(
        widget.stageIndex,
        widget.questionIndex,
        value,
      ),
      decoration: InputDecoration(
        hintText: l.evaluationWriteHint,
        alignLabelWithHint: true,
      ),
    );
  }
}

/// The bar along the bottom: where you are, and what you may do about it.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.state,
    required this.sheet,
    required this.onSave,
    required this.onSubmit,
  });

  final EvaluationSheetState state;
  final EvaluationSheet sheet;
  final VoidCallback onSave;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<EvaluationSheetCubit>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final index = sheet.stages.isEmpty
        ? 0
        : state.stageIndex.clamp(0, sheet.stages.length - 1);
    final isLast = index >= sheet.stages.length - 1;
    final saving = state.status == EvaluationSheetStatus.saving;

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
              // A read-only sheet says so and offers nothing. Drawing disabled
              // buttons instead would leave a reader waiting for them to become
              // enabled.
              if (!sheet.canFill)
                Text(
                  l.evaluationLocked,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else ...[
                Text(
                  l.evaluationProgress(sheet.answeredCount, sheet.questionCount),
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving
                              ? null
                              : () => cubit.goToStage(index - 1),
                          child: Text(l.evaluationBack),
                        ),
                      ),
                    if (index > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : onSave,
                        icon: const Icon(AppIcons.selected, size: 18),
                        label: Text(l.evaluationSaveDraft),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: isLast
                          ? FilledButton.icon(
                              onPressed: saving ? null : onSubmit,
                              icon: saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : const Icon(AppIcons.send, size: 18),
                              label: Text(l.evaluationSubmit),
                            )
                          : FilledButton(
                              onPressed: saving
                                  ? null
                                  : () => cubit.goToStage(index + 1),
                              child: Text(l.evaluationNext),
                            ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
