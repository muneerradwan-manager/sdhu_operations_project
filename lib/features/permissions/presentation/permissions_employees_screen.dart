import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/l10n/permission_labels.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/presentation/employee_picker_screen.dart';
import '../application/permission_assign_cubit.dart';
import '../data/permissions_repository.dart';
import '../domain/permission.dart';

/// الإدارة ← الصلاحيات, asked permissions-first.
///
/// This page used to be a list of employees, each opening a sheet of switches
/// — which answers "what may THIS person do", and that question now has a
/// better door: the permissions card on the employee's own page. What was
/// left for a whole page was the office's OTHER question, the one the
/// per-person sheet answers badly: "these five things — hand them to these
/// three people." Three data-entry clerks used to mean the same switches
/// flipped three times on three sheets; here they are one basket and one
/// press.
///
/// So the page reads in the order the act has: choose the permissions, then
/// choose the people. The basket keeps the same law the per-person editor and
/// the database keep — selecting an action pulls its ground in with it,
/// dropping a ground drops what stood on it — so nothing can be assembled
/// here that the server would refuse.
class PermissionsEmployeesScreen extends StatelessWidget {
  const PermissionsEmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PermissionAssignCubit(PermissionsRepository()),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  /// The second half of the act: who gets the basket.
  ///
  /// Through the same employee-picker PAGE every assignment in this app goes
  /// through — the one the operational files, the tasks and the evaluations
  /// choose people on — not a sheet of its own. Choosing who may do a thing
  /// deserves the same room as choosing who runs a tower: the search, the
  /// filters, and what each candidate already carries.
  Future<void> _assign(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<PermissionAssignCubit>();
    final messenger = ScaffoldMessenger.of(context);

    // The picker lists a season's participants; with no season under way
    // there is nobody to offer, and an empty page is a worse answer than the
    // sentence.
    final seasonId = cubit.state.seasonId;
    if (seasonId == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.moduleNoCurrentSeason)));
      return;
    }

    final picked = await showEmployeePicker(
      context,
      title: l.permissionAssignPickEmployees,
      seasonId: seasonId,
      selected: const {},
    );
    if (picked == null || picked.isEmpty) return;

    final result = await cubit.assign(picked);
    messenger.hideCurrentSnackBar();
    if (result.error != null) {
      // Partial is said as what SUCCEEDED plus the failure, not hidden: a
      // grant already written stays written, and pressing again finishes the
      // job — re-granting what landed is skipped, not doubled.
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorL(l, result.error))),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.grants == 0
              ? l.permissionAssignNothingNew
              : l.permissionAssignDone(result.users),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: GlassAppBar(title: Text(l.navPermissions)),
      body: SafeArea(
        child: BlocConsumer<PermissionAssignCubit, PermissionAssignState>(
          listenWhen: (p, c) => c.error != null && p.error != c.error,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(friendlyError(context, state.error))),
              );
          },
          builder: (context, state) {
            final cubit = context.read<PermissionAssignCubit>();

            if (state.status == PermissionAssignStatus.loading) {
              return const SkeletonList(height: 200);
            }
            if (state.status == PermissionAssignStatus.error) {
              return EmptyState(
                icon: AppIcons.permissions,
                title: friendlyError(context, state.error),
                action: FilledButton(
                  onPressed: cubit.load,
                  child: Text(l.commonRetry),
                ),
              );
            }

            final parents = state.catalog.where((p) => p.isParent).toList();

            return ResponsivePage(
              builder: (context, size) => ListView(
                padding: EdgeInsets.fromLTRB(
                  size.gutter,
                  AppSpacing.md,
                  size.gutter,
                  // Room for the button standing over the list.
                  AppSpacing.xxl * 2 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  _BasketHeader(
                    count: state.selected.length,
                    onClear: state.selected.isEmpty
                        ? null
                        : cubit.clearSelection,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // A masonry grid, not a row-major one: "الملفات" runs to
                  // fifteen actions and "المواسم" to two, and a grid that held
                  // them to one row's height would leave thirteen rows of
                  // glass under the short one before the next row started.
                  MasonryGrid(
                    weightOf: (i) =>
                        _sectionWeight(cubit.childrenOf(parents[i].id)),
                    children: staggered([
                      for (final parent in parents)
                        _SelectSection(
                          parent: parent,
                          children: cubit.childrenOf(parent.id),
                          selected: state.selected,
                          enabled: !state.assigning,
                          byId: {for (final p in state.catalog) p.id: p},
                          prerequisites: state.prerequisites,
                          onToggle: cubit.toggle,
                          onSection: (select) =>
                              cubit.setSection(parent.id, select),
                        ),
                    ], step: const Duration(milliseconds: 40)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton:
          BlocBuilder<PermissionAssignCubit, PermissionAssignState>(
            builder: (context, state) {
              // Absent until there is something to assign: a page opened to
              // browse the catalog should not wear a button that scolds.
              if (state.selected.isEmpty) return const SizedBox.shrink();
              return FloatingActionButton.extended(
                onPressed: state.assigning ? null : () => _assign(context),
                icon: state.assigning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(AppIcons.approvals),
                label: Text(l.permissionAssignAction),
              );
            },
          ),
    );
  }
}

/// What this page is and where the basket stands: the one-sentence concept,
/// and the running count that turns choosing into visible progress.
/// A rough estimate of a section's height, in rows, for [MasonryGrid] to
/// balance columns by. Exactness is not the point — only that "المواسم" with
/// two actions is treated as far shorter than "الملفات" with fifteen. The
/// header line counts as one row and the trailing spacer as a fraction of
/// one; every action counts as a row, plus most of another when it carries a
/// "يتطلب" subtitle under its name.
double _sectionWeight(List<Permission> children) =>
    1.2 + children.length + children.length * 0.35;

class _BasketHeader extends StatelessWidget {
  const _BasketHeader({required this.count, this.onClear});

  final int count;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GlassCard(
      tint: scheme.primary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  AppIcons.permissions,
                  size: 19,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  l.permissionAssignIntro,
                  style: text.bodySmall?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.permissionAssignSelectedCount(count),
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: count > 0 ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (onClear != null)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(AppIcons.reject, size: 16),
                  label: Text(l.moduleRosterClear),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One section of the catalog: a heading with a whole-section checkbox, and
/// every action under it with its own.
///
/// The tristate on the heading is the bulk within the bulk — "everything under
/// الملفات" is the commonest basket there is. An action that depends on others
/// says so under its name, and ticking it visibly ticks its ground, the same
/// law the per-person editor draws.
class _SelectSection extends StatelessWidget {
  const _SelectSection({
    required this.parent,
    required this.children,
    required this.selected,
    required this.enabled,
    required this.byId,
    required this.prerequisites,
    required this.onToggle,
    required this.onSection,
  });

  final Permission parent;
  final List<Permission> children;
  final Set<String> selected;
  final bool enabled;
  final Map<String, Permission> byId;
  final Map<String, Set<String>> prerequisites;
  final ValueChanged<String> onToggle;
  final ValueChanged<bool> onSection;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final picked = children.where((c) => selected.contains(c.id)).length;
    final all = children.isNotEmpty && picked == children.length;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        children: [
          ListTile(
            leading: Icon(AppIcons.shield, color: scheme.primary),
            title: Text(
              permissionLabel(l, parent.code),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: children.isEmpty
                ? null
                : Text('$picked / ${children.length}'),
            // Tristate reads the section; pressing it fills or empties it.
            trailing: Checkbox(
              tristate: true,
              value: all ? true : (picked == 0 ? false : null),
              onChanged: enabled && children.isNotEmpty
                  ? (_) => onSection(!all)
                  : null,
            ),
            onTap: enabled && children.isNotEmpty
                ? () => onSection(!all)
                : null,
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          for (final child in children)
            CheckboxListTile(
              contentPadding: const EdgeInsetsDirectional.only(
                start: 32,
                end: 16,
              ),
              dense: true,
              controlAffinity: ListTileControlAffinity.trailing,
              title: Text(permissionLabel(l, child.code)),
              subtitle: _requiresLine(l, child),
              value: selected.contains(child.id),
              onChanged: enabled ? (_) => onToggle(child.id) : null,
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// "يتطلب: عرض الموظفين" — the action's direct ground, named. It also
  /// explains why unticking that ground will pull this box down.
  Widget? _requiresLine(AppLocalizations l, Permission child) {
    final reqs = prerequisites[child.id] ?? const <String>{};
    if (reqs.isEmpty) return null;
    final names = [
      for (final id in reqs)
        if (byId[id] != null) permissionLabel(l, byId[id]!.code),
    ].join('، ');
    if (names.isEmpty) return null;
    return Text(l.permissionRequires(names));
  }
}
