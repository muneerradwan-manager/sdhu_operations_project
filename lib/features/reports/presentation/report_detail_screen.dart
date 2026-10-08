import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/widgets/overflow_menu.dart';
import '../../auth/application/session_cubit.dart';
import '../../../core/attachments/attachments_view.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../modules/data/modules_repository.dart';
import '../../modules/domain/module_type.dart';
import '../application/report_detail_cubit.dart';
import '../data/reports_repository.dart';
import '../domain/report.dart';
import '../domain/table_cells.dart';
import '../domain/report_type.dart';
import 'report_editor_screen.dart';
import 'widgets/report_block_view.dart';
import 'widgets/report_field_card.dart';
import 'widgets/report_table.dart';

/// One report in full: what it states, its table, the paper it came from.
class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({
    super.key,
    required this.reportId,
    this.fromOffice = false,
  });

  final String reportId;

  /// Whether this was opened from إدارة التقارير rather than from عام.
  ///
  /// The same rule the operational file follows: holding the permission is what
  /// makes editing possible, and coming in through the office is what makes
  /// THIS page the place to do it. Reached from عام the report is something
  /// being read, and a delete button does not belong on it.
  final bool fromOffice;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        ReportDetailCubit(ReportsRepository(), ModulesRepository(), reportId),
    child: _View(fromOffice: fromOffice),
  );
}

class _View extends StatelessWidget {
  const _View({required this.fromOffice});

  final bool fromOffice;

  Future<void> _edit(BuildContext context, Report report) async {
    final cubit = context.read<ReportDetailCubit>();
    final saved = await Navigator.of(
      context,
    ).push<bool>(fadeThroughRoute((_) => ReportEditorScreen(existing: report)));
    if (saved == true) await cubit.load();
  }

  Future<void> _delete(BuildContext context, Report report) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

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
      await ReportsRepository().deleteReport(report.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.reportDeleted)));
      // Nothing left on this page to look at.
      navigator.pop(true);
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyErrorL(l, '$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return BlocBuilder<ReportDetailCubit, ReportDetailState>(
      builder: (context, state) {
        final report = state.report;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: GlassAppBar(
            title: Text(report?.title ?? l.navReports),
            actions: [
              if (fromOffice && report != null)
                Builder(
                  builder: (context) {
                    final session = context.watch<SessionCubit>().state;
                    final canEdit = session.can(PermissionCodes.reportsEdit);
                    final canDelete = session.can(PermissionCodes.reportsDelete);
                    if (!canEdit && !canDelete) {
                      return const SizedBox.shrink();
                    }
                    return OverflowMenu(
                      actions: [
                        if (canEdit)
                          MenuAction(
                            icon: AppIcons.edit,
                            label: l.commonEdit,
                            onSelected: () => _edit(context, report),
                          ),
                        if (canDelete)
                          MenuAction(
                            icon: AppIcons.delete,
                            label: l.commonDelete,
                            isDestructive: true,
                            onSelected: () => _delete(context, report),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
          body: switch (state.status) {
            // Shaped like what is about to replace it: one column of tall
            // cards, at the page's own gutter. A skeleton that columns
            // differently from the screen it stands in for is a flash of a
            // layout that never arrives.
            ReportDetailStatus.loading => ResponsivePage(
              builder: (context, size) => SkeletonList(
                width: PageWidth.reading,
                maxColumns: 1,
                minTileWidth: CardWidth.full,
                height: 200,
                count: 3,
                padding: context.scrollPadding(
                  horizontal: size.gutter,
                  bottom: AppSpacing.xl,
                ),
              ),
            ),
            ReportDetailStatus.missing => EmptyState(
              icon: AppIcons.reports,
              title: l.reportMissing,
            ),
            ReportDetailStatus.error => EmptyState(
              icon: AppIcons.reports,
              title: friendlyError(context, state.error),
            ),
            ReportDetailStatus.ready => _Body(state: state, report: report!),
          },
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.report});

  final ReportDetailState state;
  final Report report;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final type = state.type;
    final fields = type?.fields ?? const <ModuleField>[];

    // Read straight through, not read across: a location and a code and a
    // document are three different things to DO, and each gets its own card.
    final plain = fields
        .where((f) => !isActionableReportField(f.kind))
        .toList();
    final own = fields.where((f) => isActionableReportField(f.kind)).toList();

    return Builder(
      builder: (context) => ResponsivePage(
        builder: (context, size) => SinglePaneLayout(
          gutter: size.gutter,
          onRefresh: context.read<ReportDetailCubit>().load,
          children: staggered([
            InfoSection(
              title: l.reportAboutSection,
              icon: AppIcons.reports,
              children: [
                InfoRow(
                  icon: AppIcons.reports,
                  label: l.reportKind,
                  value: report.typeName?.of(context),
                ),
                if ((report.number ?? '').isNotEmpty)
                  InfoRow(
                    icon: AppIcons.document,
                    label: l.reportNumber,
                    value: report.number,
                  ),
                InfoRow(
                  icon: AppIcons.seasons,
                  label: l.reportScope,
                  // A general report is not "missing a season" — it is true in
                  // all of them, and says so.
                  value: report.isSeasonal
                      ? l.seasonHijriYear(report.seasonHijriYear ?? 0)
                      : l.reportsScopeGeneral,
                ),
                if (type?.description != null)
                  InfoRow(
                    icon: AppIcons.document,
                    label: l.reportAbout,
                    value: type!.description!.of(context),
                  ),
                for (final f in plain)
                  if ((report.data[f.key]?.toString() ?? '').isNotEmpty)
                    InfoRow(
                      icon: AppIcons.document,
                      label: f.label.of(context),
                      value: report.data[f.key].toString(),
                    ),
              ],
            ),

            // A written report's content, in the order it was written.
            if (report.isWritten)
              for (final block in report.blocks)
                if (!block.isEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  ReportBlockView(
                    block: block,
                    expandedColumns: [
                      for (final item in state.expansionOf(block))
                        item.name.of(context),
                    ],
                    // What a stored cell means on this page: a reference id
                    // becomes its entry's name, a canonical time range becomes
                    // the localized sentence, an ISO date is formatted.
                    //
                    // The name is looked up across ALL of the set's entries —
                    // not this season's — for the reason reference_item.dart
                    // states about towers: a document written last season
                    // still has to render.
                    tableText: TableText(
                      referenceName: (code, id) =>
                          state
                              .setByCode(code)
                              ?.items
                              .where((i) => i.id == id)
                              .firstOrNull
                              ?.name
                              .of(context) ??
                          '',
                      timeRange: l.reportTimeRange,
                      date: (iso) => formatDate(DateTime.tryParse(iso)),
                    ),
                  ),
                ],

            // A typed one's content is its table.
            if ((type?.hasTable ?? false) && report.rows.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _TableCard(state: state, report: report),
            ],

            for (final f in own)
              if ((report.data[f.key]?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ReportFieldCard(
                  label: f.label.of(context),
                  value: report.data[f.key].toString(),
                  kind: f.kind,
                ),
              ],

            if (report.attachments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              GlassCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.reportSource,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AttachmentsView(
                      attachments: report.attachments,
                      signer: context.read<ReportDetailCubit>().signedUrl,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            Text(
              l.reportUpdated(formatDate(report.updatedAt)),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The report's table, drawn the way the window can actually hold it.
///
/// A column declared over a master-data list has already been expanded into one
/// column per entry by the cubit, so this draws whatever it is handed — which
/// for توزيع الوجبات is seventeen columns.
///
/// Seventeen columns do not go on a phone. A grid that wide either scrolls
/// sideways with the row labels sliding out of sight, or squeezes every cell to
/// three characters; both are worse than not being a grid. So below a wide
/// window each ROW is drawn as its own card — the key columns as a heading, the
/// rest as label-and-value lines. Same data, read down instead of across, which
/// is the direction a phone actually scrolls.
class _TableCard extends StatelessWidget {
  const _TableCard({required this.state, required this.report});

  final ReportDetailState state;
  final Report report;

  /// Values resolved once, with a spanning column's blank cell filled from the
  /// row above it — the date of all three documents is written once and read
  /// down the page.
  List<Map<String, String>> _resolved(
    BuildContext context,
    List<({String key, String Function(dynamic) label, ReportColumn column})>
    columns,
  ) {
    final carried = <String, String>{};
    return [
      for (final row in report.rows)
        {
          for (final c in columns)
            c.key: () {
              // A reference cell holds an id; the reader wants the name. And a
              // name looked up in a set that no longer has it reads as blank
              // rather than as a uuid nobody can use.
              var raw = row.value(c.key);
              if (c.column.isChoice && raw.isNotEmpty) {
                raw =
                    state
                        .setById(c.column.referenceSetId)
                        ?.items
                        .where((i) => i.id == raw)
                        .firstOrNull
                        ?.name
                        .of(context) ??
                    '';
              }
              if (!c.column.spansRows) return raw;
              if (raw.isNotEmpty) {
                carried[c.key] = raw;
                return raw;
              }
              return carried[c.key] ?? '';
            }(),
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final all = state.drawnColumns;
    if (all.isEmpty) return const SizedBox.shrink();
    final resolved = _resolved(context, all);

    // A column the season declared and this report never filled is dropped.
    //
    // The clusters are the season's — twenty-five of them in 1447 — while
    // توزيع الوجبات على التكتلات allots meals to the thirteen that are camped
    // at المشاعر. Expanding one column per cluster therefore built a table
    // twelve columns of which were blank from top to bottom: twice the width
    // for nothing, which is what pushed it out of being a table at all and
    // would have made poor reading if it had fit. Only EXPANDED columns are
    // dropped this way — a declared column standing empty is the type saying
    // something, and stays.
    final columns = [
      for (final c in all)
        if (!c.column.isExpanded ||
            resolved.any((row) => (row[c.key] ?? '').isNotEmpty))
          c,
    ];
    if (columns.isEmpty) return const SizedBox.shrink();
    final rows = resolved;

    // Which arrangement fits is [ReportTable]'s to decide, and it decides it by
    // measuring the room it is actually given. This used to be guessed here
    // from the window size, which is how a monitor at 150% scaling ended up
    // showing the season's cluster distribution as a stack of phone cards.
    return ReportTable(
      columns: [for (final c in columns) c.label(context)],
      rows: [
        for (final row in rows) [for (final c in columns) row[c.key] ?? ''],
      ],
      // A column entered as tags is read as tags. المكونات is nine items, and
      // nine items down a column is nine lines of table for one meal.
      tagged: {
        for (var i = 0; i < columns.length; i++)
          if (columns[i].column.isTags) i,
      },
    );
  }
}
