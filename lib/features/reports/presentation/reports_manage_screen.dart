import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/overflow_menu.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../../seasons/data/seasons_repository.dart';
import '../application/reports_cubit.dart';
import '../data/reports_repository.dart';
import '../domain/report.dart';
import 'report_detail_screen.dart';
import 'reports_screen.dart';
import 'report_editor_screen.dart';

/// الإدارة ← إدارة التقارير.
///
/// The same list عام shows, plus the unpublished ones and the means to change
/// them — which is exactly the relationship إدارة الملفات التشغيلية has with
/// the files card in عام. Reading is everyone's; this is the paperwork.
class ReportsManageScreen extends StatelessWidget {
  const ReportsManageScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ReportsCubit(ReportsRepository(), SeasonsRepository()),
    child: const _View(),
  );
}

class _View extends StatelessWidget {
  const _View();

  Future<void> _edit(BuildContext context, {Report? existing}) async {
    final cubit = context.read<ReportsCubit>();
    // Loaded in full first: the list carries no rows, and an editor opened on a
    // report without them would save an empty table over a full one.
    final full = existing == null
        ? null
        : await ReportsRepository().fetchReport(existing.id);
    if (!context.mounted) return;
    final saved = await Navigator.of(
      context,
    ).push<bool>(fadeThroughRoute((_) => ReportEditorScreen(existing: full)));
    if (saved == true) await cubit.load();
  }

  Future<void> _delete(BuildContext context, Report report) async {
    final l = context.l10n;
    final cubit = context.read<ReportsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.commonDelete),
        content: Text(l.reportDeleteConfirm(report.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // The rows and the attachments go with it; the schema cascades.
      await ReportsRepository().deleteReport(report.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.reportDeleted)));
      await cubit.load();
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyErrorL(l, '$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.watch<SessionCubit>().state;
    final canCreate = session.can(PermissionCodes.reportsCreate);
    final canEdit = session.can(PermissionCodes.reportsEdit);
    final canDelete = session.can(PermissionCodes.reportsDelete);

    return Scaffold(
      appBar: GlassAppBar(title: Text(l.navReportsManage)),
      floatingActionButton: canCreate
          ? Builder(
              builder: (context) => FloatingActionButton.extended(
                onPressed: () => _edit(context),
                icon: const Icon(AppIcons.add),
                label: Text(l.reportNew),
              ),
            )
          : null,
      body: SafeArea(
        child: BlocBuilder<ReportsCubit, ReportsState>(
          builder: (context, state) {
            final cubit = context.read<ReportsCubit>();

            if (state.status == ReportsStatus.loading) {
              return ResponsivePage(
                builder: (context, size) => SkeletonList(
                  height: 108,
                  padding: context.scrollPadding(
                    horizontal: size.gutter,
                    bottom: AppSpacing.xl,
                  ),
                ),
              );
            }
            if (state.status == ReportsStatus.error) {
              return EmptyState(
                icon: AppIcons.reports,
                title: friendlyError(context, state.error),
                action: FilledButton(
                  onPressed: cubit.load,
                  child: Text(l.commonRetry),
                ),
              );
            }

            final visible = state.visible;
            return Column(
              children: [
                ReportsFilterBar(state: state),
                Expanded(
                  child: visible.isEmpty
                      ? EmptyState(
                          icon: AppIcons.reports,
                          title: state.isNarrowed
                              ? l.reportsNoMatches
                              : l.reportsManageEmpty,
                        )
                      : ResponsivePage(
                          builder: (context, size) => AdaptiveGridView(
                            padding: EdgeInsets.fromLTRB(
                              size.gutter,
                              AppSpacing.sm,
                              size.gutter,
                              AppSpacing.xxl * 2 +
                                  MediaQuery.viewPaddingOf(context).bottom,
                            ),
                            onRefresh: cubit.load,
                            spacing: AppSpacing.md,
                            itemCount: visible.length,
                            itemBuilder: (context, i) => FadeSlideIn(
                              // Cap the cascade so a row first built deep in the scroll doesn't
                              // sit invisible for seconds (same rule as the directory).
                              delay: Duration(milliseconds: 25 * (i < 8 ? i : 8)),
                              child: ReportCard(
                                report: visible[i],
                                onOpen: () => Navigator.of(context).push(
                                  fadeThroughRoute(
                                    (_) => ReportDetailScreen(
                                      reportId: visible[i].id,
                                      fromOffice: true,
                                    ),
                                  ),
                                ),
                                trailing: (canEdit || canDelete)
                                    ? OverflowMenu(
                                        actions: [
                                          if (canEdit)
                                            MenuAction(
                                              icon: AppIcons.edit,
                                              label: l.commonEdit,
                                              onSelected: () => _edit(
                                                context,
                                                existing: visible[i],
                                              ),
                                            ),
                                          if (canDelete)
                                            MenuAction(
                                              icon: AppIcons.delete,
                                              label: l.commonDelete,
                                              isDestructive: true,
                                              onSelected: () =>
                                                  _delete(context, visible[i]),
                                            ),
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
