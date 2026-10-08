import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/info_section.dart';
import '../../../../core/widgets/overflow_menu.dart';
import '../../../../core/widgets/selection_indicator.dart';
import '../../../../core/widgets/states.dart';
import '../../application/module_detail_cubit.dart';
import '../../domain/module_task.dart';
import '../../domain/module_type.dart';

/// The duties of a file, as DESCRIPTION (0105): what the work is, not how it
/// is going.
///
///   1. مهام الملف — the file's own list, which its members divide among
///      themselves off the record;
///   2. مهام كل دور — what holding رئيس قطاع or مشرف برج here means.
///
/// Nothing here is tappable into a tracker. There are no states, no evidence,
/// no per-person lists — a person's own tracked tasks live in «مهامي»,
/// outside the operational files entirely.
List<Widget> moduleTaskSections(
  BuildContext context,
  ModuleDetailState state, {
  required bool canManage,
}) {
  final l = context.l10n;
  final list = state.taskList;
  final byRole = list.byRole;

  return [
    const SizedBox(height: AppSpacing.lg),
    SectionHeader(
      l.moduleTasksSection,
      icon: AppIcons.tasks,
      trailing: canManage
          ? IconButton(
              tooltip: l.moduleTaskAdd,
              visualDensity: VisualDensity.compact,
              onPressed: () => showModuleTaskEditorSheet(
                context,
                context.read<ModuleDetailCubit>(),
              ),
              icon: const Icon(AppIcons.add, size: 20),
            )
          : null,
    ),

    if (list.isEmpty)
      GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l.moduleTasksNone,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),

    // 1 — the file's own.
    if (list.fileTasks.isNotEmpty)
      _TaskGroupCard(
        title: l.moduleTasksFile,
        subtitle: l.moduleTasksFileHint,
        icon: AppIcons.modules,
        tasks: list.fileTasks,
        canManage: canManage,
      ),

    // 2 — each post's. One card per role, whoever happens to hold it: the
    // duties belong to the post, and naming the holders here would undo that.
    for (final entry in byRole.entries)
      _TaskGroupCard(
        title: l.moduleTasksRoleOf(
          state.roleById(entry.key)?.name.of(context) ?? l.moduleTasksRole,
        ),
        subtitle: l.moduleTasksRoleHint,
        icon: AppIcons.roles,
        tasks: entry.value,
        canManage: canManage,
      ),
  ];
}

/// One heading and the duties under it.
class _TaskGroupCard extends StatelessWidget {
  const _TaskGroupCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tasks,
    required this.canManage,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<ModuleTask> tasks;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(title, style: text.titleSmall)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final task in tasks)
              _TaskRow(task: task, canManage: canManage),
          ],
        ),
      ),
    );
  }
}

/// One duty, written out. Tappable only for whoever may correct it — for
/// everyone else it is a sentence, and a sentence does not need a button.
class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.canManage});

  final ModuleTask task;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(AppIcons.tasks, size: 15, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title.of(context),
                  style: text.bodyMedium?.copyWith(height: 1.5),
                ),
                if (task.description != null)
                  Text(
                    task.description!.of(context),
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (task.dueOn != null)
                  Text(
                    l.moduleTaskDue(formatDate(task.dueOn)),
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!canManage) return row;
    return InkWell(
      onTap: () => showModuleTaskEditorSheet(
        context,
        context.read<ModuleDetailCubit>(),
        existing: task,
      ),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: row,
    );
  }
}

// ============================================================ writing a duty

/// Writes a duty onto this file, or corrects one already written on it.
///
/// [existing] is null for a new one. The cubit is passed rather than read off
/// [context] so the sheet can be opened from contexts that sit above the
/// provider.
Future<void> showModuleTaskEditorSheet(
  BuildContext context,
  ModuleDetailCubit cubit, {
  ModuleTask? existing,
}) async {
  await showAppSheet<bool>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _TaskEditorSheet(state: cubit.state, existing: existing),
    ),
  );
}

class _TaskEditorSheet extends StatefulWidget {
  const _TaskEditorSheet({required this.state, this.existing});

  final ModuleDetailState state;
  final ModuleTask? existing;

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  late TaskScope _scope = widget.existing?.scope ?? TaskScope.file;
  late String? _roleId = widget.existing?.roleId;
  late DateTime? _dueOn = widget.existing?.dueOn;
  late final _titleAr = TextEditingController(
    text: widget.existing?.title.ar ?? '',
  );
  late final _titleEn = TextEditingController(
    text: widget.existing?.title.en ?? '',
  );
  late final _description = TextEditingController(
    text: widget.existing?.description?.ar ?? '',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _titleAr.dispose();
    _titleEn.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final title = _titleAr.text.trim();
    if (title.isEmpty) {
      setState(() => _error = l.commonRequired);
      return;
    }
    if (_scope == TaskScope.role && _roleId == null) {
      setState(() => _error = l.moduleTaskPickRole);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final cubit = context.read<ModuleDetailCubit>();
    final id = widget.existing?.id;
    final error = id == null
        ? await cubit.createTask(
            scope: _scope,
            titleAr: title,
            titleEn: _titleEn.text.trim(),
            descriptionAr: _description.text.trim(),
            roleId: _roleId,
            dueOn: _dueOn,
          )
        : await cubit.updateTask(
            id: id,
            titleAr: title,
            titleEn: _titleEn.text.trim(),
            descriptionAr: _description.text.trim(),
            dueOn: _dueOn,
          );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final id = widget.existing?.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.moduleTaskDelete),
        content: Text(l.moduleTaskDeleteConfirm),
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

    setState(() => _busy = true);
    final error = await context.read<ModuleDetailCubit>().deleteTask(id);
    if (!mounted) return;
    if (error != null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final roles = widget.state.type?.allRoles ?? const <ModuleRole>[];
    // The scope of a duty already written is fixed: moving one from a post to
    // the whole file is not an edit, it is a different duty.
    final isNew = widget.existing == null;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    isNew ? l.moduleTaskAdd : l.moduleTaskEdit,
                    style: text.titleLarge,
                  ),
                ),
                if (!isNew)
                  OverflowMenu(
                    actions: [
                      MenuAction(
                        icon: AppIcons.delete,
                        label: l.moduleTaskDelete,
                        isDestructive: true,
                        onSelected: _delete,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            if (isNew) ...[
              Text(
                l.moduleTaskScope,
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final option in TaskScope.values)
                SelectionRow(
                  label: switch (option) {
                    TaskScope.file => l.moduleTaskScopeFile,
                    TaskScope.role => l.moduleTaskScopeRole,
                  },
                  subtitle: switch (option) {
                    TaskScope.file => l.moduleTaskScopeFileHint,
                    TaskScope.role => l.moduleTaskScopeRoleHint,
                  },
                  selected: _scope == option,
                  onTap: _busy ? () {} : () => setState(() => _scope = option),
                ),
              const SizedBox(height: AppSpacing.sm),

              if (_scope == TaskScope.role)
                DropdownButtonFormField<String>(
                  initialValue: _roleId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.moduleTaskRoleLabel),
                  items: [
                    for (final role in roles)
                      DropdownMenuItem(
                        value: role.id,
                        child: Text(role.name.of(context)),
                      ),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _roleId = v),
                ),
              const SizedBox(height: AppSpacing.md),
            ],

            TextField(
              controller: _titleAr,
              enabled: !_busy,
              decoration: InputDecoration(labelText: l.moduleTaskTitleLabel),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _titleEn,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l.moduleTaskTitleEnLabel,
                helperText: l.commonOptional,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _description,
              enabled: !_busy,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l.moduleTaskDescriptionLabel,
                helperText: l.commonOptional,
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueOn ?? now,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 3),
                      );
                      if (picked != null) setState(() => _dueOn = picked);
                    },
              icon: const Icon(AppIcons.seasons, size: 18),
              label: Text(
                _dueOn == null
                    ? l.moduleTaskNoDue
                    : l.moduleTaskDue(formatDate(_dueOn)),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(AppIcons.approve),
              label: Text(l.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
