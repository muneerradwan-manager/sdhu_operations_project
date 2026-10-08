import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/l10n/permission_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/responsive.dart';
import '../application/permission_editor_cubit.dart';
import '../data/permissions_repository.dart';
import '../domain/permission.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/states.dart';

class PermissionEditorScreen extends StatelessWidget {
  const PermissionEditorScreen({
    super.key,
    required this.userId,
    required this.employeeName,
  });

  final String userId;
  final String employeeName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PermissionEditorCubit(PermissionsRepository(), userId),
      child: _View(employeeName: employeeName),
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.employeeName});
  final String employeeName;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: GlassAppBar(
        title: Text(
          employeeName.isEmpty ? l.permissionEditorTitle : employeeName,
        ),
      ),
      body: SafeArea(
        child: ResponsivePage(
          builder: (context, size) =>
              BlocConsumer<PermissionEditorCubit, PermissionEditorState>(
                listenWhen: (p, c) => c.error != null && p.error != c.error,
                listener: (context, state) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(friendlyError(context, state.error))));
                },
                builder: (context, state) {
                  if (state.status == PermissionEditorStatus.loading) {
                    return const SkeletonList(height: 200);
                  }
                  final parents = state.catalog
                      .where((p) => p.isParent)
                      .toList();
                  final grantedActions = state.granted
                      .where(
                        (id) =>
                            state.catalog.any((p) => p.id == id && !p.isParent),
                      )
                      .length;
                  final totalActions = state.catalog
                      .where((p) => !p.isParent)
                      .length;
                  final cubit = context.read<PermissionEditorCubit>();

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      size.gutter,
                      12,
                      size.gutter,
                      24 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    children: [
                      // The tally is one sentence and a bar; it does not get wider
                      // just because the window did.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: _CountHeader(
                          granted: grantedActions,
                          total: totalActions,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Each group is an independent decision — nobody reads
                      // "الملفات" before "المواسم" — so on a wide window they stand
                      // beside each other instead of forming a column half a screen
                      // wide and several screens long. A masonry grid rather than a
                      // row-major one: "الملفات" runs to fifteen actions and
                      // "المواسم" to two, and a grid that held them to one row's
                      // height would leave thirteen rows of glass under the short
                      // one before the next row was allowed to start.
                      MasonryGrid(
                        weightOf: (i) =>
                            _sectionWeight(cubit.childrenOf(parents[i].id)),
                        children: staggered([
                          for (final parent in parents)
                            _PermissionSection(
                              parent: parent,
                              children: cubit.childrenOf(parent.id),
                              granted: state.granted,
                              busy: state.busy,
                              byId: {
                                for (final p in state.catalog) p.id: p,
                              },
                              prerequisites: state.prerequisites,
                              onToggle: cubit.toggle,
                            ),
                        ], step: const Duration(milliseconds: 40)),
                      ),
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }
}

/// A rough estimate of a section's height, in rows, for [MasonryGrid] to
/// balance columns by. Exactness is not the point — only that "المواسم" with
/// two actions is treated as far shorter than "الملفات" with fifteen. The
/// header line counts as one row and the trailing spacer as a fraction of
/// one; every action counts as a row, plus most of another when it carries a
/// "يتطلب" subtitle under its name.
double _sectionWeight(List<Permission> children) =>
    1.2 + children.length + children.length * 0.35;

class _CountHeader extends StatelessWidget {
  const _CountHeader({required this.granted, required this.total});
  final int granted;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = total == 0 ? 0.0 : granted / total;

    return GlassCard(
      tint: scheme.primary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.shield, color: scheme.primary, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  context.l10n.permissionGrantedCount(granted, total),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // At-a-glance sense of how much access this person holds.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: scheme.primary.withValues(alpha: 0.14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One section of the sheet: a heading (sections are not grants) and every
/// action under it, each with its own switch.
///
/// An action that depends on others says so under its name. Granting it grants
/// the missing ground with it; revoking a ground visibly takes its dependents
/// — the same rule the database enforces, drawn rather than documented.
class _PermissionSection extends StatelessWidget {
  const _PermissionSection({
    required this.parent,
    required this.children,
    required this.granted,
    required this.busy,
    required this.byId,
    required this.prerequisites,
    required this.onToggle,
  });

  final Permission parent;
  final List<Permission> children;
  final Set<String> granted;
  final Set<String> busy;
  final Map<String, Permission> byId;
  final Map<String, Set<String>> prerequisites;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final grantedChildren = children
        .where((c) => granted.contains(c.id))
        .length;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
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
                : Text('$grantedChildren / ${children.length}'),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          for (final child in children)
            SwitchListTile(
              contentPadding: const EdgeInsetsDirectional.only(
                start: 32,
                end: 16,
              ),
              dense: true,
              secondary: _busyOr(child.id, const SizedBox(width: 1)),
              title: Text(permissionLabel(l, child.code)),
              subtitle: _requiresLine(l, child),
              value: granted.contains(child.id),
              onChanged: busy.contains(child.id)
                  ? null
                  : (_) => onToggle(child.id),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// "يتطلب: عرض الموظفين" — the action's direct ground, named. Written under
  /// every dependent action, granted or not, because it also explains why
  /// revoking the ground will pull this switch down.
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

  Widget _busyOr(String id, Widget fallback) {
    if (busy.contains(id)) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }
    return fallback;
  }
}
