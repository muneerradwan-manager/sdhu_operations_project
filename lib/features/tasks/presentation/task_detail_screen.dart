import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/attachments/attachment_picker.dart';
import '../../../core/attachments/attachments_view.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/offline/save_outcome.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../../../core/widgets/overflow_menu.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../modules/presentation/employee_picker_screen.dart';
import '../../seasons/data/seasons_repository.dart';
import '../application/task_detail_cubit.dart';
import '../application/tasks_cubit.dart';
import '../data/tasks_repository.dart';
import '../domain/personal_task.dart';
import 'task_editor_screen.dart';
import 'widgets/task_state_widgets.dart';
import 'widgets/task_thread_view.dart';

/// One task, open — a page, not a sheet.
///
/// 0105 put everything in one bottom sheet: the state chips, a note field, the
/// evidence and an overflow menu. That worked while a task had one note and
/// three states. It cannot hold a conversation, a checklist, a record of what
/// went on, and a row of moves whose availability changes with every one of
/// them — and a sheet that scrolls past the top of the screen is a page that
/// has not admitted it yet.
///
/// The rule this page is built on: **only the permitted move is drawn**. The
/// buttons come from [PersonalTask.actions], which the server computed with the
/// same function it will use to answer the write. There is no grey button that
/// says "yours, but not now", and there is no button the database refuses.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => TaskDetailCubit(TasksRepository(), taskId),
    child: const _View(),
  );
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _pending = <PendingAttachment>[];

  Future<void> _attach() async {
    final picked = await pickAttachment(context);
    if (picked != null && mounted) setState(() => _pending.add(picked));
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Moving the task.
  ///
  /// Two of the seven need words, and for those this stops and asks BEFORE
  /// writing — «متعثّرة» and «مُعادة» are assertions, and the server refuses
  /// them empty. The others go straight through: making a person confirm
  /// pressing «ابدأ» is asking them to press it twice.
  Future<void> _move(PersonalTask task, TaskState next) async {
    final cubit = context.read<TaskDetailCubit>();
    final l = context.l10n;

    String? comment;
    if (next.needsComment) {
      comment = await _askForWords(task, next);
      if (comment == null) return;
    } else if (next == TaskState.cancelled) {
      final ok = await _confirmCancel();
      if (ok != true) return;
    }

    final outcome = await cubit.move(
      next,
      note: comment,
      attachments: _pending,
      removed: const [],
    );
    if (!mounted) return;

    if (!outcome.ok) {
      _say(friendlyError(context, outcome.error));
      return;
    }
    setState(_pending.clear);
    // Said plainly rather than passed over: a person who knows their phone had
    // no signal is owed the difference between "it is with them" and "it is
    // with the app".
    _say(outcome.queued ? l.outboxSavedOffline : l.taskStateSaved);
  }

  /// The sentence a stuck or returned task cannot be moved without.
  ///
  /// Its own dialogue rather than the comment box at the foot of the page,
  /// because the words and the move are ONE act — typing the reason and then
  /// separately pressing the button leaves a thread in which somebody explained
  /// something and then, apparently unrelatedly, did it.
  Future<String?> _askForWords(PersonalTask task, TaskState next) {
    final l = context.l10n;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          taskMoveLabel(
            dialogContext,
            next,
            isAssigned: task.isAssigned,
            from: task.state,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.taskCommentHint,
            helperText: l.taskCommentRequired,
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final body = controller.text.trim();
              if (body.isEmpty) return;
              Navigator.of(dialogContext).pop(body);
            },
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmCancel() {
    final l = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.taskCancel),
        content: Text(l.taskCancelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.taskCancel),
          ),
        ],
      ),
    );
  }

  Future<void> _comment(String body) async {
    final cubit = context.read<TaskDetailCubit>();
    final l = context.l10n;
    final outcome = await cubit.comment(body, attachments: _pending);
    if (!mounted) return;
    if (!outcome.ok) {
      _say(friendlyError(context, outcome.error));
      return;
    }
    setState(_pending.clear);
    _say(outcome.queued ? l.outboxSavedOffline : l.taskCommentAdded);
  }

  /// Correcting the task itself. Reachable only where the full pen is —
  /// [PersonalTask.can] on the withdrawal move is the same answer
  /// `can_edit_personal_task` gives, so this button and the database agree
  /// without a second rule being written in Dart.
  Future<void> _edit(PersonalTask task) async {
    final cubit = context.read<TaskDetailCubit>();
    await openTaskEditor(
      context,
      existing: task,
      onSubmit: (draft) async {
        final error = await cubit.update(
          title: draft.title,
          description: draft.description,
          dueOn: draft.dueOn,
          priority: draft.priority,
          kind: draft.kind,
          steps: draft.stepsChanged ? draft.steps : null,
        );
        return error == null
            ? const SaveOutcome.sent()
            : SaveOutcome.failed(error);
      },
    );
  }

  /// Handing the task to somebody else.
  ///
  /// The mission's own roster, the same page assignment is made on — choosing
  /// who carries a duty is decided against what each candidate already carries,
  /// and that is the only page that shows it.
  ///
  /// One person, not several: a task is one row on one list, and "reassign to
  /// six" is not a handover, it is six new tasks. That is what the assign
  /// screen is for.
  Future<void> _reassign(PersonalTask task) async {
    final cubit = context.read<TaskDetailCubit>();
    final l = context.l10n;
    final seasonId = await _currentSeasonId();
    if (seasonId == null || !mounted) return;

    final person = await showSingleEmployeePicker(
      context,
      title: l.taskReassign,
      seasonId: seasonId,
      // Its current holder, and its author: handing it to the man who wrote it
      // would make `created_by = profile_id` — a private note — and it would
      // drop out of every follow-up screen, reading exactly like a failure.
      // The database refuses that too (`task_cannot_reassign_to_author`); this
      // is the polite half of the same answer.
      exclude: {task.profileId, task.createdBy},
    );
    if (person == null || !mounted) return;

    final error = await cubit.reassign(person.profile.id);
    if (!mounted) return;
    _say(error == null ? l.taskReassigned : friendlyError(context, error));
  }

  Future<String?> _currentSeasonId() async {
    try {
      return (await SeasonsRepository().fetchCurrentSeason())?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _delete(PersonalTask task) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.taskDelete),
        content: Text(l.taskDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await context.read<TaskDetailCubit>().delete();
    if (!mounted) return;
    if (error != null) {
      _say(friendlyError(context, error));
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return BlocBuilder<TaskDetailCubit, TaskDetailState>(
      builder: (context, state) {
        final cubit = context.read<TaskDetailCubit>();
        final task = state.task;

        return Scaffold(
          appBar: GlassAppBar(
            title: Text(
              task == null ? l.tasksTitle : l.taskKey(task.seq),
            ),
            actions: [
              // Shown exactly when the reader holds the full pen. Withdrawal is
              // the tell: the transition matrix (0117) allows it to nobody
              // else, so asking whether it is offered is asking the server the
              // question without a second rule being written here.
              if (task != null && task.can(TaskState.cancelled))
                OverflowMenu(
                  actions: [
                    MenuAction(
                      icon: AppIcons.edit,
                      label: l.taskEdit,
                      onSelected: () => _edit(task),
                    ),
                    // Only on assigned work: there is nobody to hand a man's
                    // own notebook to.
                    if (task.isAssigned)
                      MenuAction(
                        icon: AppIcons.switchAccount,
                        label: l.taskReassign,
                        onSelected: () => _reassign(task),
                      ),
                    MenuAction(
                      icon: AppIcons.taskCancel,
                      label: l.taskCancel,
                      isDestructive: true,
                      onSelected: () => _move(task, TaskState.cancelled),
                    ),
                    // Deleting survives only for a man's own notebook — 0117
                    // closed it for assigned work, because a row vanishing from
                    // somebody else's list overnight is not a decision they can
                    // read.
                    if (!task.isAssigned)
                      MenuAction(
                        icon: AppIcons.delete,
                        label: l.taskDelete,
                        isDestructive: true,
                        onSelected: () => _delete(task),
                      ),
                  ],
                ),
            ],
          ),
          body: SafeArea(
            child: switch (state.status) {
              TaskDetailStatus.loading => const Center(child: AppLoader()),
              TaskDetailStatus.gone => EmptyState(
                icon: AppIcons.tasks,
                title: l.taskGone,
                message: l.taskGoneHint,
              ),
              TaskDetailStatus.error => EmptyState(
                icon: AppIcons.tasks,
                title: friendlyError(context, state.error),
                action: FilledButton(
                  onPressed: cubit.load,
                  child: Text(l.commonRetry),
                ),
              ),
              TaskDetailStatus.ready => _Body(
                task: task!,
                state: state,
                pending: _pending,
                onMove: (next) => _move(task, next),
                onAttach: _attach,
                onRemoveAttachment: (i) => setState(() => _pending.removeAt(i)),
                onComment: _comment,
              ),
            },
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.task,
    required this.state,
    required this.pending,
    required this.onMove,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onComment,
  });

  final PersonalTask task;
  final TaskDetailState state;
  final List<PendingAttachment> pending;
  final void Function(TaskState next) onMove;
  final VoidCallback onAttach;
  final void Function(int index) onRemoveAttachment;
  final Future<void> Function(String body) onComment;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cubit = context.read<TaskDetailCubit>();

    return ResponsivePage(
      builder: (context, size) => ListView(
        padding: context.scrollPadding(
          horizontal: size.gutter,
          bottom: AppSpacing.xl,
        ),
        children: [
          // ---------------------------------------------------------- head
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TaskStateDot(state: task.state, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    TaskStateChip(state: task.state),
                    const Spacer(),
                    TaskPriorityChip(priority: task.priority, force: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(task.title, style: text.titleLarge),

                if (task.description case final description?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    description,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GlassBadge(
                      label: taskKindLabel(context, task.kind),
                      icon: AppIcons.tasks,
                      dense: true,
                    ),
                    if (task.isAssigned && task.authorName != null)
                      GlassBadge(
                        label: l.taskAssignedBy(task.authorName!),
                        icon: AppIcons.approvals,
                        dense: true,
                      ),
                    // The owner is named only when it is somebody other than
                    // the reader — «إلى: أحمد» on your own task would be
                    // telling you your own name.
                    if (task.ownerName != null &&
                        task.profileId != TasksCubit.viewerId)
                      GlassBadge(
                        label: l.taskAssignedTo(task.ownerName!),
                        icon: AppIcons.myProfile,
                        dense: true,
                      ),
                    if (task.batchTitle case final batch?)
                      GlassBadge(
                        label: l.taskBatchOf(batch),
                        icon: AppIcons.taskBatch,
                        dense: true,
                      ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(
                      AppIcons.seasons,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      task.dueOn == null
                          ? l.taskNoDue
                          : l.taskDue(formatDate(task.dueOn)),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TaskLatePill(task: task),
                  ],
                ),

                // The three moments, when they happened. Only the ones that
                // did: a task never submitted has no line saying it was not.
                if (task.startedAt != null ||
                    task.submittedAt != null ||
                    task.completedAt != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  for (final line in [
                    if (task.startedAt case final at?)
                      l.taskStartedAt(formatDateTime(at)),
                    if (task.submittedAt case final at?)
                      l.taskSubmittedAt(formatDateTime(at)),
                    if (task.completedAt case final at?)
                      l.taskAcceptedAt(formatDateTime(at)),
                  ])
                    Text(
                      line,
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ],
            ),
          ),

          // --------------------------------------------------------- moves
          const SizedBox(height: AppSpacing.md),
          _Moves(task: task, busy: state.busy, onMove: onMove),

          // --------------------------------------------------------- steps
          if (task.steps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            GlassCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(AppIcons.taskSteps, size: 16, color: scheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(l.taskSteps, style: text.titleSmall)),
                      Text(
                        l.taskStepsProgress(task.stepsDone, task.stepsTotal),
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TaskProgressBar(
                    value: task.stepsTotal == 0
                        ? 0
                        : task.stepsDone / task.stepsTotal,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final step in task.steps)
                    CheckboxListTile(
                      value: step.isDone,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      // Ticking is part of saying how it is going, so its
                      // owner may always do it. Rewriting the boxes is the full
                      // pen, and lives in the editor.
                      onChanged: state.busy
                          ? null
                          : (value) => cubit.toggleStep(step, value ?? false),
                      title: Text(
                        step.label,
                        style: text.bodyMedium?.copyWith(
                          decoration: step.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ----------------------------------------------------- evidence
          if (task.attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            GlassCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.taskEvidence, style: text.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  AttachmentsView(
                    attachments: task.attachments,
                    signer: cubit.signAttachment,
                  ),
                ],
              ),
            ),
          ],

          // ------------------------------------------------------- thread
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.taskThread, style: text.titleSmall),
                const SizedBox(height: AppSpacing.md),
                TaskThreadView(
                  entries: state.thread,
                  signer: cubit.signAttachment,
                ),
                const Divider(height: AppSpacing.xl),
                TaskCommentBox(
                  onSend: onComment,
                  onAttach: onAttach,
                  attachments: pending,
                  onRemoveAttachment: onRemoveAttachment,
                  busy: state.busy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The moves, and nothing but the moves.
///
/// Every button here came back from `personal_task_actions`. When the list is
/// empty the card says so in words rather than drawing nothing: a page with no
/// buttons and no sentence reads as a page that failed to load.
class _Moves extends StatelessWidget {
  const _Moves({
    required this.task,
    required this.busy,
    required this.onMove,
  });

  final PersonalTask task;
  final bool busy;
  final void Function(TaskState next) onMove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    // Withdrawal is in the overflow menu, where destructive things live. A
    // «ألغِ» sitting beside «اقبَل» at the same weight is a mis-tap waiting to
    // happen.
    final moves = [
      for (final move in TaskState.values)
        if (task.can(move) && move != TaskState.cancelled) move,
    ];

    if (moves.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            Icon(AppIcons.locked, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                task.isAssigned && !task.state.isOpen
                    ? l.taskNoActions
                    : l.taskReadOnly,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < moves.length; i++)
          _MoveButton(
            move: moves[i],
            task: task,
            // The first is the one the page expects to be pressed; the rest
            // are alternatives, and drawing five equal filled buttons would
            // make the page a menu instead of a next step.
            primary: i == 0,
            busy: busy,
            onPressed: () => onMove(moves[i]),
          ),
      ],
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({
    required this.move,
    required this.task,
    required this.primary,
    required this.busy,
    required this.onPressed,
  });

  final TaskState move;
  final PersonalTask task;
  final bool primary;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = taskMoveLabel(
      context,
      move,
      isAssigned: task.isAssigned,
      from: task.state,
    );
    final icon = Icon(taskMoveIcon(move, from: task.state), size: 18);
    final onTap = busy ? null : onPressed;

    if (primary) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: icon,
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: icon,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: move.needsComment
            ? Theme.of(context).colorScheme.error
            : null,
      ),
    );
  }
}
