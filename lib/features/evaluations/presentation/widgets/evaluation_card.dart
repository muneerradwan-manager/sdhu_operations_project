import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/info_section.dart';
import '../../domain/evaluation.dart';
import 'evaluation_labels.dart';
import 'score_bar.dart';

/// One evaluation as a row in either register.
///
/// A finished sheet leads with its mark; an unfinished one leads with how far
/// through it is. The two are never both shown, because a running total on a
/// half-filled form is a score somebody would quote.
class EvaluationCard extends StatelessWidget {
  const EvaluationCard({
    super.key,
    required this.evaluation,
    this.onOpen,
    this.onDelete,
    this.showEvaluator = false,
  });

  final Evaluation evaluation;
  final VoidCallback? onOpen;

  /// Null where deleting is not this reader's to do — a person's own list of
  /// errands, where withdrawing the work is not the same as doing it.
  final VoidCallback? onDelete;

  /// Whether to name who is filling it. True in the register, false in a
  /// person's own list — where the evaluator is the reader.
  final bool showEvaluator;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final subject = (evaluation.targetLabel ?? '').trim().isEmpty
        ? evaluationTargetLabel(l, evaluation.target)
        : evaluation.targetLabel!;
    final tone = evaluation.isOverdue ? scheme.error : scheme.primary;

    return GlassCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The kind's glyph in a tinted frame, as everywhere a card leads
              // with an icon — a bare glyph floating beside a title reads as
              // decoration; a seated one reads as structure.
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: tone.withValues(alpha: 0.18)),
                ),
                child: Icon(
                  evaluationTargetIcon(evaluation.target),
                  size: 22,
                  color: tone,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // The kind and the form's name second, in the smaller type,
                    // as one quiet line: two sheets on the same subject differ
                    // by their paper, but it is the subject a reader scans the
                    // list for. Identity as text, not a pill — only status
                    // earns a colour.
                    Text(
                      '${evaluationTargetLabel(l, evaluation.target)}'
                      ' · ${evaluation.templateTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                PopupMenuButton<int>(
                  icon: const Icon(AppIcons.more),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 0, child: Text(l.evaluationDelete)),
                  ],
                  onSelected: (_) => onDelete!(),
                )
              else
                const NavChevron(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (evaluation.isSubmitted)
            ScoreBar(
              score: evaluation.score ?? 0,
              total: evaluation.maxScore ?? 0,
              dense: true,
            )
          else
            _Progress(evaluation: evaluation),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              GlassBadge(
                label: evaluation.isSubmitted
                    ? l.evaluationStatusSubmitted
                    : l.evaluationStatusDraft,
                icon: evaluation.isSubmitted
                    ? AppIcons.approve
                    : AppIcons.pending,
                color: evaluation.isSubmitted ? scheme.primary : scheme.tertiary,
                dense: true,
              ),
              if (evaluation.isOverdue)
                GlassBadge(
                  label: l.evaluationOverdue,
                  icon: AppIcons.warning,
                  color: scheme.error,
                  dense: true,
                )
              else if (evaluation.dueOn != null && !evaluation.isSubmitted)
                GlassBadge(
                  label: l.evaluationDueOn(formatDate(evaluation.dueOn)),
                  icon: AppIcons.seasons,
                  color: scheme.onSurfaceVariant,
                  dense: true,
                ),
              // Who and when are facts, not states, so they wear the muted
              // tone — the coloured pills above are reserved for what stands
              // out: finished, pending, late.
              if (showEvaluator && evaluation.evaluatorName != null)
                GlassBadge(
                  label: evaluation.evaluatorName!,
                  icon: AppIcons.employees,
                  color: scheme.onSurfaceVariant,
                  dense: true,
                ),
              GlassBadge(
                label: evaluation.isSubmitted
                    ? l.evaluationSubmittedOn(formatDate(evaluation.submittedAt))
                    : l.evaluationOpenedOn(formatDate(evaluation.createdAt)),
                color: scheme.onSurfaceVariant,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// How far through an unfinished sheet is — answered out of asked, and never a
/// mark. What a half-filled form adds up to is not information about anything.
class _Progress extends StatelessWidget {
  const _Progress({required this.evaluation});
  final Evaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.evaluationProgress(
            evaluation.answeredCount,
            evaluation.questionCount,
          ),
          style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: evaluation.progress,
            minHeight: 5,
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            valueColor: AlwaysStoppedAnimation(
              evaluation.isOverdue ? scheme.error : scheme.secondary,
            ),
          ),
        ),
      ],
    );
  }
}
