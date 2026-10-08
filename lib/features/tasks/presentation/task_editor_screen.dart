import 'package:flutter/material.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/offline/save_outcome.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/creator_page.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../data/tasks_outbox.dart';
import '../domain/personal_task.dart';
import 'widgets/task_state_widgets.dart';

/// What the editor collected, handed to whoever opened it.
typedef TaskDraft = ({
  String title,
  String? description,
  DateTime? dueOn,
  TaskPriority priority,
  TaskKind kind,
  List<String> steps,

  /// Whether the checklist differs from what the task had. False on a new
  /// task, and false on an edit that only corrected a spelling — rewriting the
  /// steps sends them all back, and doing that for the sake of a title would
  /// re-write somebody's ticks.
  bool stepsChanged,
});

typedef TaskEditorSubmit = Future<SaveOutcome> Function(TaskDraft draft);

/// Writes a task, or corrects one the caller holds the full pen over.
///
/// [existing] is null for a new one. [assignTo] names other people's lists —
/// the assigners' door, and a LIST because one duty is routinely handed to
/// several people in one decision; empty writes onto the caller's own.
///
/// The write itself is [onSubmit] rather than a cubit this page reaches for,
/// and that is not indirection for its own sake: the three screens that open
/// this one write through three different objects and, more importantly, three
/// different RULES. Writing to oneself queues when there is no signal;
/// assigning to six people never does (see [TasksOutbox]). A page that held a
/// cubit would have to know which of those it was doing.
Future<bool> openTaskEditor(
  BuildContext context, {
  PersonalTask? existing,
  List<(String id, String name)> assignTo = const [],
  required TaskEditorSubmit onSubmit,
}) async {
  final saved = await Navigator.of(context).push<bool>(
    fadeThroughRoute(
      (_) => TaskEditorScreen(
        existing: existing,
        assignTo: assignTo,
        onSubmit: onSubmit,
      ),
    ),
  );
  return saved == true;
}

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({
    super.key,
    this.existing,
    this.assignTo = const [],
    required this.onSubmit,
  });

  final PersonalTask? existing;
  final List<(String id, String name)> assignTo;
  final TaskEditorSubmit onSubmit;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late DateTime? _dueOn = widget.existing?.dueOn;
  late TaskPriority _priority = widget.existing?.priority ?? TaskPriority.normal;
  late TaskKind _kind = widget.existing?.kind ?? TaskKind.task;

  /// The checklist, as labels. Editing an existing task starts from what it
  /// has; the server preserves ticks by label when this is sent back, so
  /// reordering four boxes does not un-tick the two already done.
  late final List<TextEditingController> _steps = [
    for (final step in widget.existing?.steps ?? const <TaskStep>[])
      TextEditingController(text: step.label),
  ];

  bool _busy = false;
  String? _error;

  bool get _isNew => widget.existing == null;
  bool get _isAssigning => widget.assignTo.isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  List<String> get _stepLabels => [
    for (final step in _steps)
      if (step.text.trim().isNotEmpty) step.text.trim(),
  ];

  Future<void> _save() async {
    final l = context.l10n;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = l.commonRequired);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final description = _description.text.trim();
    final outcome = await widget.onSubmit((
      title: title,
      description: description.isEmpty ? null : description,
      dueOn: _dueOn,
      priority: _priority,
      kind: _kind,
      steps: _stepLabels,
      stepsChanged: _stepsChanged,
    ));

    if (!mounted) return;
    if (!outcome.ok) {
      setState(() {
        _busy = false;
        _error = outcome.error;
      });
      return;
    }
    final queued = outcome.queued;

    // Said here rather than by the list: this page knows WHAT was written, and
    // the messenger it speaks to belongs to the app, not to this route — the
    // line stays up over the list it returns to.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(queued ? l.outboxSavedOffline : l.taskSaved),
        ),
      );
    Navigator.of(context).pop(true);
  }

  bool get _stepsChanged {
    final was = [
      for (final step in widget.existing?.steps ?? const <TaskStep>[])
        step.label,
    ];
    final now = _stepLabels;
    if (was.length != now.length) return true;
    for (var i = 0; i < was.length; i++) {
      if (was[i] != now[i]) return true;
    }
    return false;
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueOn ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _dueOn = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return CreatorPage(
      title: _isNew ? (_isAssigning ? l.tasksAssign : l.tasksNew) : l.taskEdit,
      submitLabel: l.commonSave,
      busy: _busy,
      onSubmit: _save,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Every name, not a count: whoever is about to hand out a duty is
              // owed the chance to notice the wrong man in the list BEFORE six
              // people are notified, and "6 employees" gives him nothing to
              // notice with.
              if (_isAssigning) ...[
                Text(
                  l.tasksAssign,
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final (_, name) in widget.assignTo)
                      GlassBadge(
                        label: name,
                        icon: AppIcons.myProfile,
                        dense: true,
                      ),
                  ],
                ),
                if (widget.assignTo.length > 1) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        AppIcons.taskBatch,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          l.taskBatchCarriers(widget.assignTo.length),
                          style: text.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],

              TextField(
                controller: _title,
                enabled: !_busy,
                autofocus: _isNew,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l.taskTitleLabel),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _description,
                enabled: !_busy,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.taskDescriptionLabel,
                  helperText: l.commonOptional,
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              _ChipRow<TaskPriority>(
                label: l.taskPriority,
                values: TaskPriority.values,
                selected: _priority,
                enabled: !_busy,
                labelOf: (value) => taskPriorityLabel(context, value),
                onChanged: (value) => setState(() => _priority = value),
              ),

              const SizedBox(height: AppSpacing.md),
              _ChipRow<TaskKind>(
                label: l.taskKind,
                values: TaskKind.values,
                selected: _kind,
                enabled: !_busy,
                labelOf: (value) => taskKindLabel(context, value),
                onChanged: (value) => setState(() => _kind = value),
              ),

              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickDue,
                icon: const Icon(AppIcons.seasons, size: 18),
                label: Text(
                  _dueOn == null ? l.taskNoDue : l.taskDue(formatDate(_dueOn)),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  friendlyError(context, _error),
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
            ],
          ),
        ),

        // ------------------------------------------------------------ steps
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
                    l.commonOptional,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              for (var i = 0; i < _steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _steps[i],
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: '${l.taskStepHint} ${i + 1}',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l.commonDelete,
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _steps.removeAt(i).dispose();
                              }),
                        icon: const Icon(AppIcons.delete, size: 18),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(
                          () => _steps.add(TextEditingController()),
                        ),
                  icon: const Icon(AppIcons.add, size: 18),
                  label: Text(l.taskStepAdd),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A labelled row of exclusive chips — used for the two small enums, which are
/// three values each and belong on screen rather than behind a dropdown.
class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final void Function(T value) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final value in values)
              ChoiceChip(
                label: Text(labelOf(value)),
                selected: value == selected,
                onSelected: enabled ? (_) => onChanged(value) : null,
              ),
          ],
        ),
      ],
    );
  }
}
