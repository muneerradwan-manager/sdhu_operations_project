import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/creator_page.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/saved_copy_banner.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/states.dart';
import '../application/tasks_cubit.dart';
import '../data/tasks_repository.dart';
import '../domain/personal_task.dart';
import 'task_detail_screen.dart';
import 'task_editor_screen.dart';
import 'widgets/task_card.dart';
import 'widgets/task_state_widgets.dart';

/// One person's task list, and nothing else's.
///
/// This screen has no relation to the operational files, and no administration
/// either. What is on it came from exactly two pens: the viewer's own — tasks
/// they wrote for themselves, theirs entirely — and the pen of whoever holds
/// `tasks.assign`.
///
/// It stays a LIST. The board with its columns is one screen along, behind
/// `tasks.assign`, and it is there because its reader is sitting down; this one
/// is read standing in Mina with one thumb, and columns on a telephone in that
/// position are a way of showing five things badly.
///
/// What it gains instead is the ability to answer «ما المتأخر؟» without the
/// reader doing the arithmetic — the six views (0118), sliced on the server
/// because "overdue" is a question about a clock and a state machine.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, this.compose = false});

  /// Open the editor as soon as the screen is up.
  ///
  /// Set by the button on the home card. The composer needs this screen's
  /// cubit, so it cannot be opened from the card directly — the card asks for
  /// the screen AND the sheet, and the screen provides both in the right order.
  final bool compose;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => TasksCubit(TasksRepository()),
    child: _View(compose: compose),
  );
}

class _View extends StatefulWidget {
  const _View({this.compose = false});

  final bool compose;

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // After the first frame, so the editor has a Scaffold to sit above — and
    // once, because `initState` is the only place that is true of.
    if (widget.compose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _add();
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Writing one for oneself. Queues when there is no signal — a reminder is
  /// written standing somewhere, and the outbox is what makes that survivable.
  Future<void> _add() {
    final cubit = context.read<TasksCubit>();
    return openTaskEditor(
      context,
      onSubmit: (draft) => cubit.create(
        title: draft.title,
        description: draft.description,
        dueOn: draft.dueOn,
        priority: draft.priority,
        kind: draft.kind,
        steps: draft.steps,
      ),
    );
  }

  /// One way in and one way back: the task is a page above this list, and
  /// closing it lands here. Reloaded on return rather than trusted, because
  /// what happened up there may have moved the row out of the current view
  /// entirely — accepting a task in «الجارية» removes it from «الجارية».
  Future<void> _open(PersonalTask task) async {
    final cubit = context.read<TasksCubit>();
    await Navigator.of(
      context,
    ).push(fadeThroughRoute((_) => TaskDetailScreen(taskId: task.id)));
    await cubit.load();
  }

  Future<void> _quickMove(PersonalTask task, TaskState next) async {
    final cubit = context.read<TasksCubit>();
    final l = context.l10n;
    final outcome = await cubit.move(task, next);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            !outcome.ok
                ? friendlyError(context, outcome.error)
                : outcome.queued
                ? l.outboxSavedOffline
                : l.taskStateSaved,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: GlassAppBar(title: Text(l.tasksTitle)),
      floatingActionButton: CreateFab(label: l.tasksNew, onPressed: _add),
      body: SafeArea(
        child: BlocBuilder<TasksCubit, TasksState>(
          builder: (context, state) {
            final cubit = context.read<TasksCubit>();

            if (state.status == TasksStatus.error) {
              return EmptyState(
                icon: AppIcons.tasks,
                title: friendlyError(context, state.error),
                action: FilledButton(
                  onPressed: cubit.load,
                  child: Text(l.commonRetry),
                ),
              );
            }

            return ResponsivePage(
              builder: (context, size) => Column(
                children: [
                  // Same place as on every other list in the app, and visible
                  // without being asked for. The box used to hide behind a lens
                  // in the bar, which taught this screen's reader that the list
                  // could not be searched — the one thing it must not say about
                  // a list that can.
                  SearchFilterBar(
                    hint: l.tasksSearch,
                    controller: _search,
                    onChanged: cubit.setQuery,
                  ),
                  _ViewBar(
                    view: state.view,
                    stats: state.stats,
                    onChanged: cubit.setView,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: cubit.load,
                      child: _List(
                        state: state,
                        gutter: size.gutter,
                        onOpen: _open,
                        onQuickMove: _quickMove,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The six views, and the two numbers worth putting on the bar itself.
///
/// «متأخرة» carries its count and «الجارية» does not, and that is the whole
/// point of the bar: a number beside every tab is a row of numbers nobody
/// reads, and a number beside the one that means "something is wrong" is a
/// thing a person acts on.
class _ViewBar extends StatelessWidget {
  const _ViewBar({
    required this.view,
    required this.stats,
    required this.onChanged,
  });

  final TaskView view;
  final TaskStats stats;
  final void Function(TaskView view) onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          for (final option in TaskView.values)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: ChoiceChip(
                selected: option == view,
                onSelected: (_) => onChanged(option),
                label: Text(
                  option == TaskView.overdue && stats.overdue > 0
                      ? '${taskViewLabel(context, option)} ${stats.overdue}'
                      : taskViewLabel(context, option),
                ),
                labelStyle: option == TaskView.overdue && stats.overdue > 0
                    ? TextStyle(
                        color: option == view ? null : scheme.error,
                        fontWeight: FontWeight.w700,
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.state,
    required this.gutter,
    required this.onOpen,
    required this.onQuickMove,
  });

  final TasksState state;
  final double gutter;
  final Future<void> Function(PersonalTask task) onOpen;
  final Future<void> Function(PersonalTask task, TaskState next) onQuickMove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final padding = context.scrollPadding(
      horizontal: gutter,
      bottom: AppSpacing.xl * 2,
    );

    if (state.status == TasksStatus.loading) {
      return SkeletonList(height: 132, padding: padding);
    }

    if (state.tasks.isEmpty) {
      // The banner rides above the empty state too, and that case is the one
      // that most needs it: "you have nothing to do" read off a saved copy is
      // the most confidently wrong sentence this screen can say.
      //
      // And "nothing matches" is never printed as "nothing to do" — an empty
      // list under a filter is a statement about the filter.
      return ListView(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SavedCopyBanner(savedAt: state.savedAt),
          const SizedBox(height: AppSpacing.xl),
          EmptyState(
            icon: AppIcons.tasks,
            title: state.isFiltered ? l.tasksNoMatch : l.tasksEmpty,
            message: state.isFiltered ? null : l.tasksEmptyHint,
            action: state.isFiltered
                ? TextButton(
                    onPressed: context.read<TasksCubit>().clearFilters,
                    child: Text(l.tasksClearFilters),
                  )
                : null,
          ),
        ],
      );
    }

    // Two sections, as 0105 had them, and for its reason: what a man wrote for
    // himself and what was written for him are answerable in different ways,
    // and merging them would let one of the two hide inside the other.
    final assigned = state.assignedToMe;
    final own = state.own;

    return ListView(
      padding: padding,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // Draws nothing when the read was live.
        SavedCopyBanner(savedAt: state.savedAt),

        if (assigned.isNotEmpty) ...[
          _Heading(
            title: l.tasksAssignedSection,
            subtitle: l.tasksAssignedHint,
            icon: AppIcons.approvals,
            tasks: assigned,
          ),
          for (final task in assigned)
            TaskCard(
              task: task,
              showAuthor: true,
              busy: state.busy,
              onTap: () => onOpen(task),
              onQuickMove: (next) => onQuickMove(task, next),
            ),
        ],

        if (own.isNotEmpty) ...[
          _Heading(
            title: l.tasksOwnSection,
            subtitle: l.tasksOwnHint,
            icon: AppIcons.myProfile,
            tasks: own,
          ),
          for (final task in own)
            TaskCard(
              task: task,
              busy: state.busy,
              onTap: () => onOpen(task),
              onQuickMove: (next) => onQuickMove(task, next),
            ),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tasks,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<PersonalTask> tasks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (done, total) = PersonalTask.progressOf(tasks);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TaskProgressPill(done: done, total: total),
        ],
      ),
    );
  }
}
