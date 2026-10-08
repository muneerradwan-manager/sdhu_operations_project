import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/info_section.dart';
import '../../data/modules_repository.dart';
import '../../domain/module_task.dart';

/// Writes one duty onto a file — or onto a role in it — from OUTSIDE the
/// file's own page.
///
/// The file page's duty sheet asks for the scope and the role because it is
/// standing on a file already. This one is opened the other way around, from
/// the tasks board, where the module and the role were just chosen — so both
/// arrive settled and the sheet is only the words: title, note, date. What it
/// writes is the same row through the same [ModulesRepository.createFileTask],
/// so nothing exists in two versions.
///
/// Pops true when the duty was written, null when backed out of.
Future<bool?> showDutyComposerSheet(
  BuildContext context, {
  required String moduleId,
  required String moduleName,
  required TaskScope scope,
  String? roleId,
  String? roleName,
}) {
  return showAppSheet<bool>(
    context: context,
    builder: (_) => _DutyComposerSheet(
      moduleId: moduleId,
      moduleName: moduleName,
      scope: scope,
      roleId: roleId,
      roleName: roleName,
    ),
  );
}

class _DutyComposerSheet extends StatefulWidget {
  const _DutyComposerSheet({
    required this.moduleId,
    required this.moduleName,
    required this.scope,
    this.roleId,
    this.roleName,
  });

  final String moduleId;
  final String moduleName;
  final TaskScope scope;
  final String? roleId;
  final String? roleName;

  @override
  State<_DutyComposerSheet> createState() => _DutyComposerSheetState();
}

class _DutyComposerSheetState extends State<_DutyComposerSheet> {
  final _titleAr = TextEditingController();
  final _titleEn = TextEditingController();
  final _description = TextEditingController();
  DateTime? _dueOn;
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

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ModulesRepository().createFileTask(
        moduleId: widget.moduleId,
        scope: widget.scope,
        titleAr: title,
        titleEn: _titleEn.text.trim(),
        descriptionAr: _description.text.trim(),
        roleId: widget.roleId,
        dueOn: _dueOn,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Where the duty is going, spelled out over the fields: the file, and the
    // post when there is one. The reader chose both a moment ago, but a sheet
    // that repeats the address is a sheet that cannot write to the wrong one.
    final target = widget.roleName == null
        ? widget.moduleName
        : '${widget.moduleName} · ${widget.roleName}';

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
            Text(l.moduleTaskAdd, style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  widget.scope == TaskScope.role
                      ? AppIcons.roles
                      : AppIcons.modules,
                  size: 15,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    target,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

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
