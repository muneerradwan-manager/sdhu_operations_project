import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/info_section.dart';
import '../../domain/personal_task.dart';
import 'task_state_widgets.dart';

/// One task as every list draws it.
///
/// 0105 drew a row: a dot, a title, whatever the note said, and a state chip.
/// That was enough when there were three states and no deadline anybody acted
/// on. What this has to carry now is everything a person decides by WITHOUT
/// opening it — how late it is, how urgent, how far through its steps, whether
/// anybody has said anything — and it has to do it in two lines, because the
/// list is thirty rows long and read standing up.
///
/// The urgency is a stripe on the leading edge rather than a badge in the row:
/// a badge competes with the title for the same horizontal space, and the one
/// question this card answers first is «أيّها المتأخر؟» — which the eye should
/// find by running down an edge, not by reading.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.showOwner = false,
    this.showAuthor = false,
    this.onQuickMove,
    this.busy = false,
  });

  final PersonalTask task;
  final VoidCallback onTap;

  /// Name whose list it is on — for the assigner's follow-up screens.
  final bool showOwner;

  /// Name who assigned it — for «مُسندة إليّ».
  final bool showAuthor;

  /// The one-tap move offered on the row itself, when there is an obvious one.
  /// Null hides the button entirely; see [_quickMove] for what counts as
  /// obvious.
  final void Function(TaskState next)? onQuickMove;

  final bool busy;

  /// The move worth offering without opening the task.
  ///
  /// Only ever a move that needs NO words: «بدأت» and «أرسِل للقبول» and, on a
  /// man's own list, «أنجزتُها». Blocking and returning are not here and must
  /// not be — both are assertions the server refuses without a sentence
  /// (`task_comment_required`, 0117), and a button that opens a dialogue is not
  /// a one-tap button, it is a worse way of opening the task.
  TaskState? get _quickMove {
    if (task.can(TaskState.inProgress) && task.state == TaskState.notStarted) {
      return TaskState.inProgress;
    }
    if (task.can(TaskState.submitted)) return TaskState.submitted;
    if (task.can(TaskState.done) && !task.isAssigned) return TaskState.done;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final quick = onQuickMove == null ? null : _quickMove;

    final stripe = task.isOverdue
        ? scheme.error
        : task.priority == TaskPriority.high
        ? scheme.error
        : task.priority == TaskPriority.low
        ? scheme.tertiary
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The stripe, drawn on the START edge so it lands on the right in
              // Arabic — where the eye begins the line.
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: stripe,
                  borderRadius: const BorderRadiusDirectional.horizontal(
                    start: Radius.circular(AppRadius.lg),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TaskStateDot(state: task.state),
                          const SizedBox(width: AppSpacing.sm),
                          TaskKeyLabel(seq: task.seq),
                          const Spacer(),
                          TaskStateChip(state: task.state),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      Text(
                        task.title,
                        style: text.bodyMedium?.copyWith(
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          // Struck through, not greyed: a finished task is
                          // still part of the record and has to stay readable.
                          decoration:
                              task.state.isDone ||
                                  task.state == TaskState.cancelled
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: scheme.onSurfaceVariant,
                        ),
                      ),

                      if (task.description case final description?) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],

                      if (task.hasSteps) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: TaskProgressBar(
                                value: task.stepsDone / task.stepsTotal,
                                height: 4,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              l.taskProgress(task.stepsDone, task.stepsTotal),
                              style: text.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TaskPriorityChip(priority: task.priority),
                          TaskLatePill(task: task),
                          if (task.dueOn != null && !task.isOverdue)
                            _Meta(
                              icon: AppIcons.seasons,
                              label: formatDate(task.dueOn),
                            ),
                          if (showOwner && task.ownerName != null)
                            _Meta(
                              icon: AppIcons.myProfile,
                              label: task.ownerName!,
                              highlight: true,
                            ),
                          if (showAuthor && task.authorName != null)
                            _Meta(
                              icon: AppIcons.approvals,
                              label: l.taskAssignedBy(task.authorName!),
                              highlight: true,
                            ),
                          if (task.batchTitle case final batch?)
                            _Meta(icon: AppIcons.taskBatch, label: batch),
                          if (task.commentCount > 0)
                            _Meta(
                              icon: AppIcons.complaints,
                              label: '${task.commentCount}',
                            ),
                          if (task.attachmentCount > 0)
                            _Meta(
                              icon: AppIcons.attach,
                              label: '${task.attachmentCount}',
                            ),
                        ],
                      ),

                      // The last thing said, when there is one. One line: the
                      // whole conversation is a tap away, and a card that grew
                      // with the thread would push the next task off the screen.
                      if (task.note case final note?
                          when note.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              AppIcons.complaints,
                              size: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                note.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (quick != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FilledButton.tonalIcon(
                            onPressed: busy ? null : () => onQuickMove!(quick),
                            icon: Icon(
                              taskMoveIcon(quick, from: task.state),
                              size: 16,
                            ),
                            label: Text(
                              taskMoveLabel(
                                context,
                                quick,
                                isAssigned: task.isAssigned,
                                from: task.state,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, this.highlight = false});

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = highlight ? scheme.primary : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, height: 1.4),
        ),
      ],
    );
  }
}
