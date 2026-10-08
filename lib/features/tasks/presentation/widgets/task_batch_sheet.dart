import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/error_text.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/info_section.dart';
import '../../../../core/widgets/states.dart';
import '../../application/tasks_board_cubit.dart';
import '../../domain/personal_task.dart';
import 'task_state_widgets.dart';

/// One decision, and everyone carrying a piece of it.
///
/// The question this sheet exists to answer is the one 0105 made unanswerable:
/// «استلام كشوف الحجاج — كم أنجزها من الستة؟». Under that migration the six
/// rows were unrelated, and the follow-up screen grouped by PERSON, so the
/// decision existed only in the head of whoever made it.
///
/// Two buttons at the foot, and both are the assigner's real work: accept
/// everything that is claimed done, and nudge whoever has not. Neither is a
/// bulk write on the server — each acceptance is its own decision, its own
/// event and its own notification (see [TasksBoardCubit.acceptAll]). What is
/// saved is six taps, not six judgements.
Future<void> showTaskBatchSheet(
  BuildContext context, {
  required TaskBatch batch,
}) async {
  final cubit = context.read<TasksBoardCubit>();
  await showAppSheet<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _BatchSheet(batch: batch),
    ),
  );
}

class _BatchSheet extends StatefulWidget {
  const _BatchSheet({required this.batch});

  final TaskBatch batch;

  @override
  State<_BatchSheet> createState() => _BatchSheetState();
}

class _BatchSheetState extends State<_BatchSheet> {
  List<PersonalTask>? _tasks;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await context.read<TasksBoardCubit>().batchTasks(
        widget.batch.id,
      );
      if (mounted) setState(() => _tasks = tasks);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _acceptReady(List<PersonalTask> ready) async {
    final cubit = context.read<TasksBoardCubit>();
    final l = context.l10n;
    setState(() => _busy = true);
    final accepted = await cubit.acceptAll(ready);
    if (!mounted) return;
    setState(() => _busy = false);
    _say(l.taskBatchAccepted(accepted));
    await _load();
  }

  Future<void> _nudge(List<PersonalTask> behind) async {
    final cubit = context.read<TasksBoardCubit>();
    final l = context.l10n;
    setState(() => _busy = true);
    final sent = await cubit.nudge(behind);
    if (!mounted) return;
    setState(() => _busy = false);
    _say(l.taskBatchNudged(sent));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final batch = widget.batch;
    final tasks = _tasks;

    final ready = [
      for (final task in tasks ?? const <PersonalTask>[])
        if (task.state == TaskState.submitted && task.can(TaskState.done)) task,
    ];
    final behind = [
      for (final task in tasks ?? const <PersonalTask>[])
        if (task.state.isOpen && task.state != TaskState.submitted) task,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(batch.title, style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  l.taskBatchCarriers(batch.total),
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (batch.dueOn != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    l.taskDue(formatDate(batch.dueOn)),
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),
                TaskProgressPill(done: batch.done, total: batch.total),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
            TaskProgressBar(value: batch.progress),

            const SizedBox(height: AppSpacing.lg),
            if (_error != null)
              Text(
                friendlyError(context, _error),
                style: text.bodySmall?.copyWith(color: scheme.error),
              )
            else if (tasks == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: AppLoader(),
              )
            else
              // One line per person: the name, and where they are. Everything
              // else about the task is one tap away in its own page, and a
              // sheet that tried to show six threads would show none of them.
              for (final task in tasks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      TaskStateDot(state: task.state, size: 14),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          task.ownerName ?? l.taskPickPerson,
                          style: text.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.isOverdue) ...[
                        TaskLatePill(task: task),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      TaskStateChip(state: task.state),
                    ],
                  ),
                ),

            if (tasks != null && (ready.isNotEmpty || behind.isNotEmpty)) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  if (ready.isNotEmpty)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _acceptReady(ready),
                        icon: const Icon(AppIcons.approve, size: 18),
                        label: Text(l.taskBatchAcceptReady(ready.length)),
                      ),
                    ),
                  if (ready.isNotEmpty && behind.isNotEmpty)
                    const SizedBox(width: AppSpacing.sm),
                  if (behind.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _nudge(behind),
                        icon: const Icon(AppIcons.notifications, size: 18),
                        label: Text(l.taskBatchNudge),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
