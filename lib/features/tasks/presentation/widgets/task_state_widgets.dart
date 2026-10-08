import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../domain/personal_task.dart';

/// The colour of a state, one place, so the dot and the chip cannot disagree.
///
/// Seven now rather than three (0117), and two of them are deliberately not
/// green or grey: [TaskState.blocked] and [TaskState.returned] are the states
/// in which somebody is WAITING, and a list where those read like everything
/// else is a list that buries the only two rows worth acting on.
Color taskStateColor(ColorScheme scheme, TaskState state) => switch (state) {
  TaskState.notStarted => scheme.onSurfaceVariant,
  TaskState.inProgress => scheme.tertiary,
  TaskState.blocked => scheme.error,
  TaskState.submitted => scheme.secondary,
  TaskState.done => scheme.primary,
  TaskState.returned => scheme.error,
  TaskState.cancelled => scheme.outline,
};

String taskStateLabel(BuildContext context, TaskState state) => switch (state) {
  TaskState.notStarted => context.l10n.taskStateNotStarted,
  TaskState.inProgress => context.l10n.taskStateInProgress,
  TaskState.blocked => context.l10n.taskStateBlocked,
  TaskState.submitted => context.l10n.taskStateSubmitted,
  TaskState.done => context.l10n.taskStateDone,
  TaskState.returned => context.l10n.taskStateReturned,
  TaskState.cancelled => context.l10n.taskStateCancelled,
};

/// What pressing this state is CALLED, which is not what the state is called.
///
/// «بانتظار القبول» is a state; the button that puts a task into it says «أرسِل
/// للقبول». A screen that labelled the button with the state would be asking
/// the person to press a noun.
///
/// [isAssigned] decides one word and it is the important one: on a man's own
/// list «منجزة» is him finishing his work, and on somebody else's it is the
/// assigner ACCEPTING it. Same transition, two different acts.
String taskMoveLabel(
  BuildContext context,
  TaskState state, {
  required bool isAssigned,
  required TaskState from,
}) {
  final l = context.l10n;
  return switch (state) {
    TaskState.inProgress =>
      from == TaskState.done ? l.taskMoveReopen : l.taskMoveStart,
    TaskState.blocked => l.taskMoveBlock,
    TaskState.submitted => l.taskMoveSubmit,
    TaskState.done => isAssigned ? l.taskMoveAccept : l.taskMoveDone,
    TaskState.returned => l.taskMoveReturn,
    TaskState.cancelled => l.taskMoveCancel,
    TaskState.notStarted => l.taskMoveRestore,
  };
}

IconData taskMoveIcon(TaskState state, {required TaskState from}) =>
    switch (state) {
      TaskState.inProgress =>
        from == TaskState.done ? AppIcons.taskReopen : AppIcons.taskStart,
      TaskState.blocked => AppIcons.warning,
      TaskState.submitted => AppIcons.send,
      TaskState.done => AppIcons.approve,
      TaskState.returned => AppIcons.taskReturn,
      TaskState.cancelled => AppIcons.taskCancel,
      TaskState.notStarted => AppIcons.taskReturn,
    };

/// Seven shapes, not seven colours.
///
/// 0105 gave three: an empty ring, a half-filled ring and a tick, because
/// colour alone says nothing to a reader who cannot tell tertiary from primary
/// and these are read at sixteen pixels down a list of thirty. The four added
/// here keep the rule — each is a different GLYPH, and the colour only agrees
/// with it.
class TaskStateDot extends StatelessWidget {
  const TaskStateDot({super.key, required this.state, this.size = 16});

  final TaskState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = taskStateColor(Theme.of(context).colorScheme, state);
    return switch (state) {
      TaskState.done => Icon(AppIcons.selected, size: size, color: color),
      TaskState.inProgress => Icon(AppIcons.pending, size: size, color: color),
      TaskState.blocked => Icon(AppIcons.warning, size: size, color: color),
      TaskState.submitted => Icon(AppIcons.send, size: size, color: color),
      TaskState.returned => Icon(AppIcons.taskReturn, size: size, color: color),
      TaskState.cancelled => Icon(AppIcons.taskCancel, size: size, color: color),
      TaskState.notStarted => Container(
        width: size - 2,
        height: size - 2,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.4),
        ),
      ),
    };
  }
}

class TaskStateChip extends StatelessWidget {
  const TaskStateChip({super.key, required this.state});

  final TaskState state;

  @override
  Widget build(BuildContext context) {
    final color = taskStateColor(Theme.of(context).colorScheme, state);
    return _Pill(
      color: color,
      label: taskStateLabel(context, state),
    );
  }
}

String taskPriorityLabel(BuildContext context, TaskPriority priority) =>
    switch (priority) {
      TaskPriority.high => context.l10n.taskPriorityHigh,
      TaskPriority.normal => context.l10n.taskPriorityNormal,
      TaskPriority.low => context.l10n.taskPriorityLow,
    };

Color taskPriorityColor(ColorScheme scheme, TaskPriority priority) =>
    switch (priority) {
      TaskPriority.high => scheme.error,
      TaskPriority.normal => scheme.onSurfaceVariant,
      TaskPriority.low => scheme.tertiary,
    };

/// The urgency, said only when it is not the default.
///
/// Nine rows in ten are «عادية», and a badge on all of them labels nothing —
/// it just adds a word to every line and makes the one row that IS urgent
/// harder to find, which is the opposite of what a priority is for.
class TaskPriorityChip extends StatelessWidget {
  const TaskPriorityChip({super.key, required this.priority, this.force = false});

  final TaskPriority priority;
  final bool force;

  @override
  Widget build(BuildContext context) {
    if (!priority.isNotable && !force) return const SizedBox.shrink();
    final color = taskPriorityColor(Theme.of(context).colorScheme, priority);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          taskPriorityLabel(context, priority),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

String taskKindLabel(BuildContext context, TaskKind kind) => switch (kind) {
  TaskKind.task => context.l10n.taskKindTask,
  TaskKind.followUp => context.l10n.taskKindFollowUp,
  TaskKind.request => context.l10n.taskKindRequest,
};

String taskViewLabel(BuildContext context, TaskView view) => switch (view) {
  TaskView.today => context.l10n.taskViewToday,
  TaskView.week => context.l10n.taskViewWeek,
  TaskView.overdue => context.l10n.taskViewOverdue,
  TaskView.open => context.l10n.taskViewOpen,
  TaskView.done => context.l10n.taskViewDone,
  TaskView.all => context.l10n.taskViewAll,
};

/// How late, in words.
///
/// Not merely in red: this list is read on a phone held up under the sun in
/// Mina, behind a translucent card, and a colour is the first thing that
/// surface takes away. «تأخّرت يومين» survives being hard to see.
class TaskLatePill extends StatelessWidget {
  const TaskLatePill({super.key, required this.task});

  final PersonalTask task;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final due = task.dueOn;
    if (due == null || !task.state.isOpen) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(DateTime(due.year, due.month, due.day)).inDays;

    if (days > 0) {
      return _Pill(color: scheme.error, label: l.taskLateDays(days), bold: true);
    }
    if (days == 0) return _Pill(color: scheme.tertiary, label: l.taskDueToday);
    if (days == -1) {
      return _Pill(color: scheme.onSurfaceVariant, label: l.taskDueTomorrow);
    }
    return const SizedBox.shrink();
  }
}

/// "م-١٤٢" — the number a person says on a radio (0118).
class TaskKeyLabel extends StatelessWidget {
  const TaskKeyLabel({super.key, required this.seq});

  final int seq;

  @override
  Widget build(BuildContext context) => Text(
    context.l10n.taskKey(seq),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
      height: 1.4,
    ),
  );
}

/// "٤/٧" — how much of a list is behind it. Coloured only when it is all of it:
/// a green pill over four of seven would be a congratulation nobody earned.
class TaskProgressPill extends StatelessWidget {
  const TaskProgressPill({super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final complete = total > 0 && done == total;
    return _Pill(
      color: complete ? scheme.primary : scheme.onSurfaceVariant,
      label: context.l10n.taskProgress(done, total),
    );
  }
}

/// The thin bar under a batch or a checklist. Drawn rather than counted alone
/// because "four of six" and a bar two-thirds full are read by different parts
/// of the eye, and the follow-up screen is scanned, not read.
class TaskProgressBar extends StatelessWidget {
  const TaskProgressBar({super.key, required this.value, this.height = 5});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: scheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(
          value >= 1 ? scheme.primary : scheme.tertiary,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.label, this.bold = false});

  final Color color;
  final String label;
  final bool bold;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        height: 1.4,
        fontWeight: bold ? FontWeight.w700 : null,
      ),
    ),
  );
}
