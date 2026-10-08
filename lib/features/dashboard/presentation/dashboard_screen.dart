import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/l10n/permission_labels.dart';
import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../../l10n/app_localizations.dart';
// The three sections added in 0123 name states, priorities and complaint kinds
// that other screens already name. Borrowed rather than re-spelled: a chart
// that called «بانتظار القبول» something else than the board does would be two
// answers to one question.
import '../../complaints/domain/complaint.dart' show ComplaintTarget;
import '../../complaints/presentation/widgets/complaint_labels.dart';
import '../../tasks/domain/personal_task.dart'
    show TaskPriority, TaskState;
import '../../tasks/presentation/widgets/task_state_widgets.dart';
import '../application/dashboard_cubit.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_stats.dart';

/// The season, from above.
///
/// Every other screen in this app answers one question about one row. This is
/// the only one that answers a question about the whole season — how many of
/// its files are actually running, whether the people who owe reports are
/// filing them, where the mission's strength sits.
///
/// What appears depends entirely on what the reader holds. The database drops
/// the sections a permission does not cover rather than zeroing them, and this
/// screen draws whatever it was handed: a man with `approvals.decide` and
/// nothing else sees the queue and no files at all. That is why there is no
/// permission check anywhere below — the answer already arrived filtered, and
/// checking again here would be a second, disagreeing copy of the same rule.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardCubit(DashboardRepository()),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(l.dashboardTitle)),
      body: Builder(
        builder: (context) => BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            if (state.status == DashboardStatus.loading &&
                state.stats.season == null) {
              return const SkeletonList(count: 4, height: 112, minTileWidth: CardWidth.stat);
            }
            if (state.status == DashboardStatus.error) {
              return EmptyState(
                icon: AppIcons.dashboard,
                title: friendlyError(context, state.error),
                action: FilledButton(
                  onPressed: () => context.read<DashboardCubit>().refresh(),
                  child: Text(l.commonRetry),
                ),
              );
            }
            if (state.stats.season == null) {
              return EmptyState(
                icon: AppIcons.seasons,
                title: l.dashboardNoSeason,
              );
            }

            return ResponsivePage(
              builder: (context, size) => SinglePaneLayout(
                gutter: size.gutter,
                onRefresh: () => context.read<DashboardCubit>().refresh(),
                children: _sections(context, l, state),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context,
    AppLocalizations l,
    DashboardState state,
  ) {
    final stats = state.stats;

    if (stats.isEmpty) {
      return [
        const SizedBox(height: AppSpacing.xl),
        _SeasonFilter(state: state),
        const SizedBox(height: AppSpacing.xxl),
        EmptyState(icon: AppIcons.dashboard, title: l.dashboardNothingToShow),
      ];
    }

    return [
      FadeSlideIn(child: _SeasonFilter(state: state)),
      const SizedBox(height: AppSpacing.lg),

      // The headline row: the four or five numbers somebody opens this page to
      // read. Everything below explains one of them.
      AdaptiveGrid(
        minTileWidth: CardWidth.stat,
        maxColumns: 4,
        children: staggered(_headline(context, l, stats)),
      ),

      if (stats.people != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(
            l.dashboardSectionPeople,
            icon: AppIcons.participants,
          ),
        ),
        _cards([
          ChartCard(
            title: l.dashboardInternalSplit,
            child: DonutChart(
              otherLabel: l.chartOther,
              centerLabel: l.dashboardParticipants,
              slices: [
                ChartSlice(
                  label: l.dashboardInternal,
                  value: stats.people!.internal,
                ),
                ChartSlice(
                  label: l.dashboardExternal,
                  value: stats.people!.external,
                ),
              ],
            ),
          ),
          ChartCard(
            title: l.dashboardByMission,
            child: DonutChart(
              otherLabel: l.chartOther,
              centerLabel: l.chartTotal,
              slices: [
                for (final m in stats.people!.byMission)
                  ChartSlice(label: _label(context, m), value: m.count),
              ],
            ),
          ),
          ChartCard(
            title: l.dashboardByGender,
            child: DonutChart(
              otherLabel: l.chartOther,
              centerLabel: l.chartTotal,
              slices: [
                for (final g in stats.people!.byGender)
                  ChartSlice(label: _gender(l, g.key), value: g.count),
              ],
            ),
          ),
          if (stats.people!.byJobTitle.isNotEmpty)
            ChartCard(
              title: l.dashboardByJobTitle,
              child: RankedBars(
                slices: [
                  for (final t in stats.people!.byJobTitle)
                    ChartSlice(label: _label(context, t), value: t.count),
                ],
              ),
            ),
        ]),
      ],

      if (stats.modules != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(
            l.dashboardSectionModules,
            icon: AppIcons.modules,
          ),
        ),
        AdaptiveGrid(
          minTileWidth: CardWidth.stat,
          maxColumns: 4,
          children: staggered([
            StatTile(
              label: l.dashboardRunning,
              value: '${stats.modules!.running}',
              icon: AppIcons.activate,
              color: Accent.green.of(context),
            ),
            StatTile(
              label: l.dashboardEnded,
              value: '${stats.modules!.ended}',
              icon: AppIcons.pending,
              color: Accent.goldSoft.of(context),
            ),
            StatTile(
              label: l.dashboardNodes,
              value: '${stats.modules!.nodes}',
              icon: AppIcons.roles,
              color: Accent.greenDeep.of(context),
            ),
            // Drawn in the alarm colour only when it is not zero: a red tile
            // that is always there stops being a warning and becomes furniture.
            StatTile(
              label: l.dashboardUnstaffed,
              value: '${stats.modules!.unstaffed}',
              icon: AppIcons.emptyInbox,
              color: stats.modules!.unstaffed > 0
                  ? Theme.of(context).colorScheme.error
                  : Accent.greenDark.of(context),
              caption: stats.modules!.unstaffed > 0
                  ? l.dashboardUnstaffedCaption
                  : null,
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        _cards([
          ChartCard(
            title: l.dashboardActiveDraft,
            child: DonutChart(
              otherLabel: l.chartOther,
              centerLabel: l.dashboardFiles,
              slices: [
                ChartSlice(
                  label: l.moduleActiveSection,
                  value: stats.modules!.active,
                ),
                ChartSlice(
                  label: l.moduleBadgeDraft,
                  value: stats.modules!.draft,
                ),
              ],
            ),
          ),
          if (stats.modules!.byType.isNotEmpty)
            ChartCard(
              title: l.dashboardByType,
              child: RankedBars(
                slices: [
                  for (final t in stats.modules!.byType)
                    ChartSlice(label: _label(context, t), value: t.count),
                ],
              ),
            ),
        ]),
      ],

      if (stats.reports != null || stats.ratings != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(l.dashboardSectionWork, icon: AppIcons.tasks),
        ),
        _cards([
          if (stats.reports != null)
            ChartCard(
              title: l.dashboardReportsTrend,
              child: TrendChart(
                emptyLabel: l.dashboardReportsEmpty,
                labelForDay: _day,
                points: [
                  for (final d in stats.reports!.series)
                    TrendPoint(day: d.day, value: d.count),
                ],
              ),
            ),
          if (stats.ratings != null)
            ChartCard(
              title: l.dashboardRatingDistribution,
              trailing: stats.ratings!.average == null
                  ? null
                  : GlassBadge(
                      label:
                          '${l.dashboardAverage} '
                          '${stats.ratings!.average!.toStringAsFixed(2)}',
                      icon: AppIcons.rating,
                      dense: true,
                    ),
              child: StarBars(counts: stats.ratings!.distribution),
            ),
        ]),
      ],

      if (stats.centralReports != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(
            l.dashboardSectionCentralReports,
            icon: AppIcons.reports,
          ),
        ),
        AdaptiveGrid(
          minTileWidth: CardWidth.stat,
          maxColumns: 4,
          children: staggered([
            StatTile(
              label: l.dashboardCentralPublished,
              value: '${stats.centralReports!.published}',
              icon: AppIcons.reports,
              color: Accent.green.of(context),
            ),
            // Alarm colour only while there is actually something unfinished,
            // same rule as the unstaffed-files tile.
            StatTile(
              label: l.dashboardCentralDrafts,
              value: '${stats.centralReports!.drafts}',
              icon: AppIcons.documentEmpty,
              color: stats.centralReports!.drafts > 0
                  ? Accent.goldSoft.of(context)
                  : Accent.greenDark.of(context),
            ),
            StatTile(
              label: l.dashboardCentralGeneral,
              value: '${stats.centralReports!.general}',
              icon: AppIcons.file,
              color: Accent.greenDeep.of(context),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        _cards([
          ChartCard(
            title: l.dashboardCentralSplit,
            child: DonutChart(
              otherLabel: l.chartOther,
              centerLabel: l.chartTotal,
              slices: [
                ChartSlice(
                  label: l.dashboardCentralPublished,
                  value: stats.centralReports!.published,
                ),
                ChartSlice(
                  label: l.dashboardCentralDrafts,
                  value: stats.centralReports!.drafts,
                ),
              ],
            ),
          ),
          if (stats.centralReports!.byType.isNotEmpty)
            ChartCard(
              title: l.dashboardCentralByType,
              child: RankedBars(
                slices: [
                  for (final t in stats.centralReports!.byType)
                    ChartSlice(label: _label(context, t), value: t.count),
                ],
              ),
            ),
        ]),
      ],

      if (stats.notifications != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(
            l.dashboardSectionNotifications,
            icon: AppIcons.notifications,
          ),
        ),
        AdaptiveGrid(
          minTileWidth: CardWidth.stat,
          maxColumns: 4,
          children: staggered([
            StatTile(
              label: l.dashboardNotifMessages30,
              value: '${stats.notifications!.messages}',
              icon: AppIcons.send,
              color: Accent.green.of(context),
              caption: l.dashboardNotifAllTime(
                stats.notifications!.totalMessages,
              ),
              spark: [
                for (final d in stats.notifications!.series) d.count,
              ],
            ),
            StatTile(
              label: l.dashboardNotifRecipients,
              value: '${stats.notifications!.recipients}',
              icon: AppIcons.participants,
              color: Accent.greenDeep.of(context),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        _cards([
          ChartCard(
            title: l.dashboardNotifTrend,
            child: TrendChart(
              emptyLabel: l.dashboardNotifTrendEmpty,
              labelForDay: _day,
              points: [
                for (final d in stats.notifications!.series)
                  TrendPoint(day: d.day, value: d.count),
              ],
            ),
          ),
          // A share of a whole gets a ring rather than a fourth tile: "68%"
          // printed as a number is a number, and the question a reader is
          // actually asking — is most of it read, or hardly any of it — is a
          // question about a proportion, which is a shape.
          if (stats.notifications!.readShare != null)
            ChartCard(
              title: l.dashboardNotifReadShare,
              child: GaugeRing(
                value: stats.notifications!.readShare!,
                label: l.dashboardNotifReadOf(
                  stats.notifications!.read,
                  stats.notifications!.recipients,
                ),
              ),
            ),
        ]),
      ],

      // ─────────────────────────────── the five sections added in 0123 ──
      //
      // Three of them cannot be scoped to the season the selector at the top of
      // this page is set to, because their tables carry no season and should
      // not: a task given to a man is his until it is answered, a complaint is
      // about conduct, an emergency belongs to the hour it happened in. Every
      // one of those cards SAYS SO in its caption — a number sitting under a
      // season selector is read as that season's number, and letting the layout
      // imply what the data does not support is the whole failure this section
      // was added to correct.

      if (stats.incidents != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(
            l.dashboardSectionIncidents,
            icon: AppIcons.warning,
          ),
        ),
        AdaptiveGrid(
          minTileWidth: CardWidth.stat,
          maxColumns: 4,
          children: staggered([
            StatTile(
              label: l.dashboardIncidentsOpen,
              value: '${stats.incidents!.open}',
              icon: AppIcons.warning,
              color: stats.incidents!.open > 0
                  ? Accent.red.of(context)
                  : Accent.greenDark.of(context),
              caption: l.dashboardNotSeasonScoped,
            ),
            StatTile(
              label: l.dashboardIncidentsRecent,
              value: '${stats.incidents!.recent}',
              icon: AppIcons.trend,
              color: Accent.gold.of(context),
              caption: l.dashboardIncidentsAllTime(stats.incidents!.total),
              spark: [for (final d in stats.incidents!.series) d.count],
            ),
            // Minutes, and only when somebody has actually picked one up. A
            // response time of "0" on a register nobody has answered would read
            // as instant service.
            if (stats.incidents!.avgMinutesToHandle case final minutes?)
              StatTile(
                label: l.dashboardIncidentsAvgHandle,
                value: l.durationMinutes(minutes.round()),
                icon: AppIcons.checkIn,
                color: Accent.greenDeep.of(context),
                caption: l.dashboardIncidentsAvgHandleCaption,
              ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        _cards([
          ChartCard(
            title: l.dashboardIncidentsSplit,
            child: DonutChart(
              otherLabel: l.chartOther,
              centerLabel: l.chartTotal,
              slices: [
                ChartSlice(
                  label: l.incidentStateOpen,
                  value: stats.incidents!.open,
                ),
                ChartSlice(
                  label: l.incidentStateInProgress,
                  value: stats.incidents!.inProgress,
                ),
                ChartSlice(
                  label: l.incidentStateClosed,
                  value: stats.incidents!.closed,
                ),
              ],
            ),
          ),
          ChartCard(
            title: l.dashboardIncidentsTrend,
            child: TrendChart(
              emptyLabel: l.dashboardIncidentsTrendEmpty,
              labelForDay: _day,
              points: [
                for (final d in stats.incidents!.series)
                  TrendPoint(day: d.day, value: d.count),
              ],
            ),
          ),
        ]),
      ],

      if (stats.checkIn != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(
            l.dashboardSectionCheckIn,
            icon: AppIcons.checkIn,
          ),
        ),
        AdaptiveGrid(
          minTileWidth: CardWidth.stat,
          maxColumns: 4,
          children: staggered([
            StatTile(
              label: l.dashboardCheckInToday,
              value: '${stats.checkIn!.today}',
              icon: AppIcons.checkIn,
              color: Accent.green.of(context),
              spark: [for (final d in stats.checkIn!.series) d.count],
            ),
            StatTile(
              label: l.dashboardCheckInPeople,
              value: '${stats.checkIn!.people}',
              icon: AppIcons.participants,
              color: Accent.greenDeep.of(context),
              caption: l.dashboardCheckInPlaces(stats.checkIn!.places),
            ),
            StatTile(
              label: l.dashboardCheckInTotal,
              value: '${stats.checkIn!.total}',
              icon: AppIcons.document,
              color: Accent.goldSoft.of(context),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        _cards([
          ChartCard(
            title: l.dashboardCheckInTrend,
            child: TrendChart(
              emptyLabel: l.dashboardCheckInTrendEmpty,
              labelForDay: _day,
              points: [
                for (final d in stats.checkIn!.series)
                  TrendPoint(day: d.day, value: d.count),
              ],
            ),
          ),
        ]),
      ],

      if (stats.tasks != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(l.dashboardSectionTasks, icon: AppIcons.tasks),
        ),
        AdaptiveGrid(
          minTileWidth: CardWidth.stat,
          maxColumns: 4,
          children: staggered([
            StatTile(
              label: l.dashboardTasksOpen,
              value: '${stats.tasks!.open}',
              icon: AppIcons.tasks,
              color: Accent.green.of(context),
              caption: l.dashboardNotSeasonScoped,
            ),
            StatTile(
              label: l.dashboardTasksLate,
              value: '${stats.tasks!.late}',
              icon: AppIcons.warning,
              color: stats.tasks!.late > 0
                  ? Accent.red.of(context)
                  : Accent.greenDark.of(context),
              caption: l.dashboardTasksEscalated(stats.tasks!.escalated),
            ),
            // The queue somebody ELSE is holding: the assignee has said he is
            // finished and nobody has answered him. It belongs on this page
            // because it is invisible from either man's own list.
            StatTile(
              label: l.dashboardTasksAwaiting,
              value: '${stats.tasks!.awaitingReview}',
              icon: AppIcons.approvals,
              color: Accent.gold.of(context),
            ),
            StatTile(
              label: l.dashboardTasksAssignees,
              value: '${stats.tasks!.assignees}',
              icon: AppIcons.participants,
              color: Accent.greenDeep.of(context),
              caption: l.dashboardTasksAllTime(stats.tasks!.total),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        _cards([
          if (stats.tasks!.byState.isNotEmpty)
            ChartCard(
              title: l.dashboardTasksByState,
              child: RankedBars(
                slices: [
                  // The RPC sends the `task_state` spelling; the enum owns the
                  // translation from it, so the chart and the board cannot end
                  // up calling the same state two different things.
                  for (final s in stats.tasks!.byState)
                    ChartSlice(
                      label: taskStateLabel(context, TaskState.fromDb(s.key)),
                      value: s.count,
                    ),
                ],
              ),
            ),
          if (stats.tasks!.byPriority.isNotEmpty)
            ChartCard(
              title: l.dashboardTasksByPriority,
              child: DonutChart(
                otherLabel: l.chartOther,
                centerLabel: l.chartTotal,
                slices: [
                  for (final s in stats.tasks!.byPriority)
                    ChartSlice(
                      label: taskPriorityLabel(
                        context,
                        TaskPriority.fromDb(s.key),
                      ),
                      value: s.count,
                    ),
                ],
              ),
            ),
        ]),
      ],

      if (stats.evaluations != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(
            l.dashboardSectionEvaluations,
            icon: AppIcons.rating,
          ),
        ),
        AdaptiveGrid(
          minTileWidth: CardWidth.stat,
          maxColumns: 4,
          children: staggered([
            StatTile(
              label: l.dashboardEvalSubmitted,
              value: '${stats.evaluations!.submitted}',
              icon: AppIcons.rating,
              color: Accent.green.of(context),
              caption: l.dashboardEvalOf(stats.evaluations!.total),
            ),
            StatTile(
              label: l.dashboardEvalLate,
              value: '${stats.evaluations!.late}',
              icon: AppIcons.warning,
              color: stats.evaluations!.late > 0
                  ? Accent.red.of(context)
                  : Accent.greenDark.of(context),
              caption: l.dashboardEvalDrafts(stats.evaluations!.draft),
            ),
            // A percentage, never an average score — see [EvaluationDashStats]
            // for why the two are not the same figure.
            if (stats.evaluations!.averagePct case final pct?)
              StatTile(
                label: l.dashboardEvalAverage,
                value: '${pct.toStringAsFixed(1)}%',
                icon: AppIcons.trend,
                color: Accent.gold.of(context),
                caption: l.dashboardEvalAverageCaption,
              ),
            StatTile(
              label: l.dashboardEvalEvaluators,
              value: '${stats.evaluations!.evaluators}',
              icon: AppIcons.participants,
              color: Accent.greenDeep.of(context),
            ),
          ]),
        ),
      ],

      if (stats.complaints != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(
            l.dashboardSectionComplaints,
            icon: AppIcons.complaints,
          ),
        ),
        AdaptiveGrid(
          minTileWidth: CardWidth.stat,
          maxColumns: 4,
          children: staggered([
            StatTile(
              label: l.dashboardComplaintsOpen,
              value: '${stats.complaints!.open}',
              icon: AppIcons.complaints,
              color: stats.complaints!.open > 0
                  ? Accent.gold.of(context)
                  : Accent.greenDark.of(context),
              caption: l.dashboardNotSeasonScoped,
            ),
            StatTile(
              label: l.dashboardComplaintsRecent,
              value: '${stats.complaints!.recent}',
              icon: AppIcons.trend,
              color: Accent.greenDeep.of(context),
              caption: l.dashboardComplaintsAllTime(stats.complaints!.total),
            ),
            StatTile(
              label: l.dashboardComplaintsDismissed,
              value: '${stats.complaints!.dismissed}',
              icon: AppIcons.locked,
              color: Accent.goldSoft.of(context),
              caption: l.dashboardComplaintsLocked(stats.complaints!.locked),
            ),
          ]),
        ),
        // Counts only, and by TARGET TYPE — never a name. See
        // [ComplaintDashStats]: the register is structurally secret, and a
        // dashboard is the easiest place in an application to undo that.
        if (stats.complaints!.byTarget.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _cards([
            ChartCard(
              title: l.dashboardComplaintsByTarget,
              child: RankedBars(
                slices: [
                  for (final s in stats.complaints!.byTarget)
                    ChartSlice(
                      label: complaintTargetLabel(
                        l,
                        ComplaintTarget.fromDb(s.key),
                      ),
                      value: s.count,
                    ),
                ],
              ),
            ),
          ]),
        ],
      ],

      if (stats.reference != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(
            l.dashboardSectionReference,
            icon: AppIcons.referenceData,
          ),
        ),
        AdaptiveGrid(
          minTileWidth: CardWidth.stat,
          maxColumns: 4,
          children: staggered([
            StatTile(
              label: l.dashboardRefSets,
              value: '${stats.reference!.sets}',
              icon: AppIcons.referenceData,
              color: Accent.greenDeep.of(context),
            ),
            StatTile(
              label: l.dashboardRefItems,
              value: '${stats.reference!.items}',
              icon: AppIcons.document,
              color: Accent.green.of(context),
              caption: '${l.dashboardRefActive}: ${stats.reference!.active}',
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        _cards([
          ChartCard(
            title: l.dashboardRefSeasonSplit,
            child: DonutChart(
              otherLabel: l.chartOther,
              centerLabel: l.dashboardRefItems,
              slices: [
                ChartSlice(
                  label: l.dashboardRefSeasonItems,
                  value: stats.reference!.seasonItems,
                ),
                ChartSlice(
                  label: l.dashboardRefGeneralItems,
                  value: stats.reference!.generalItems,
                ),
              ],
            ),
          ),
          if (stats.reference!.bySet.isNotEmpty)
            ChartCard(
              title: l.dashboardRefBySet,
              child: RankedBars(
                slices: [
                  for (final s in stats.reference!.bySet)
                    ChartSlice(label: _label(context, s), value: s.count),
                ],
              ),
            ),
        ]),
      ],

      if (stats.permissions != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(
            l.dashboardSectionPermissions,
            icon: AppIcons.permissions,
          ),
        ),
        AdaptiveGrid(
          minTileWidth: CardWidth.stat,
          maxColumns: 4,
          children: staggered([
            StatTile(
              label: l.dashboardPermAdmins,
              value: '${stats.permissions!.admins}',
              icon: AppIcons.permissions,
              color: Accent.gold.of(context),
            ),
            StatTile(
              label: l.dashboardPermGrantees,
              value: '${stats.permissions!.grantees}',
              icon: AppIcons.participants,
              color: Accent.green.of(context),
            ),
            StatTile(
              label: l.dashboardPermGrants,
              value: '${stats.permissions!.grants}',
              icon: AppIcons.selected,
              color: Accent.greenDeep.of(context),
            ),
          ]),
        ),
        if (stats.permissions!.bySection.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _cards([
            ChartCard(
              title: l.dashboardPermBySection,
              child: RankedBars(
                slices: [
                  for (final s in stats.permissions!.bySection)
                    ChartSlice(
                      label: permissionLabel(l, s.key),
                      value: s.count,
                    ),
                ],
              ),
            ),
          ]),
        ],
      ],

      if (stats.approvals != null) ...[
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          child: SectionHeader(
            l.dashboardSectionQueue,
            icon: AppIcons.approvals,
          ),
        ),
        // Four states, which is one more than colour can carry — so this is a
        // ranked list in one hue, with the name at the start of each row.
        _cards([
          ChartCard(
            title: l.dashboardSectionQueue,
            child: RankedBars(
              slices: [
                ChartSlice(
                  label: l.dashboardPending,
                  value: stats.approvals!.pending,
                ),
                ChartSlice(
                  label: l.dashboardApproved,
                  value: stats.approvals!.approved,
                ),
                ChartSlice(
                  label: l.dashboardIncomplete,
                  value: stats.approvals!.incomplete,
                ),
                ChartSlice(
                  label: l.dashboardRejected,
                  value: stats.approvals!.rejected,
                ),
              ],
            ),
          ),
        ]),
      ],
    ];
  }

  List<Widget> _headline(
    BuildContext context,
    AppLocalizations l,
    DashboardStats stats,
  ) {
    return [
      // First in the row, ahead of the participant count, and only when there
      // is one. An open emergency is not a statistic — it is the one thing on
      // this page somebody is meant to stop reading and act on — so it goes at
      // the head of the headline and takes the error colour, and a register
      // with nothing open does not appear here at all rather than printing a
      // reassuring zero in red.
      if ((stats.incidents?.open ?? 0) > 0)
        StatTile(
          label: l.dashboardIncidentsOpen,
          value: '${stats.incidents!.open}',
          icon: AppIcons.warning,
          color: Accent.red.of(context),
          caption: l.dashboardIncidentsInProgress(stats.incidents!.inProgress),
        ),
      if (stats.people != null)
        StatTile(
          label: l.dashboardParticipants,
          value: '${stats.people!.participants}',
          icon: AppIcons.participants,
          color: Accent.green.of(context),
          caption: l.dashboardWithdrawnCaption(stats.people!.withdrawn),
        ),
      if (stats.modules != null)
        StatTile(
          label: l.dashboardFiles,
          value: '${stats.modules!.total}',
          icon: AppIcons.modules,
          color: Accent.greenDeep.of(context),
          caption: l.dashboardFilesCaption(
            stats.modules!.active,
            stats.modules!.draft,
          ),
        ),
      if (stats.reports != null)
        StatTile(
          label: l.dashboardReports,
          value: '${stats.reports!.total}',
          icon: AppIcons.trend,
          color: Accent.gold.of(context),
          caption: l.dashboardReportsCaption(stats.reports!.authors),
          // The one headline number with a shape behind it. "412 reports" and
          // "412 reports, none of them since Thursday" are different facts, and
          // the tile can carry the second without being asked.
          spark: [for (final d in stats.reports!.series) d.count],
        ),
      if (stats.ratings != null)
        StatTile(
          label: l.dashboardRatings,
          value: '${stats.ratings!.count}',
          icon: AppIcons.rating,
          color: Accent.goldSoft.of(context),
          caption: l.dashboardRatedPeople(stats.ratings!.ratedPeople),
        ),
      if (stats.approvals != null)
        StatTile(
          label: l.dashboardPending,
          value: '${stats.approvals!.pending}',
          icon: AppIcons.approvals,
          color: stats.approvals!.pending > 0
              ? Accent.red.of(context)
              : Accent.greenDark.of(context),
        ),
    ];
  }

  /// Chart panes never share a height: a five-row ranked list and a thirty-day
  /// trend are honestly different sizes, and forcing them level would print
  /// dead glass under the shorter one. (It would also crash — a pane holding a
  /// [LayoutBuilder] cannot be asked for an intrinsic height. See
  /// [GridCellWidth].)
  Widget _cards(List<Widget> cards) => AdaptiveGrid(
    equalHeights: false,
    children: staggered(cards.whereType<Widget>().toList()),
  );

  String _label(BuildContext context, CountedLabel c) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final en = c.labelEn;
    return english && en != null && en.isNotEmpty ? en : c.labelAr;
  }

  String _gender(AppLocalizations l, String key) => switch (key) {
    'male' => l.genderMale,
    'female' => l.genderFemale,
    _ => l.dashboardUnknown,
  };

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Which season everything on the page is counted over.
///
/// Held to the width of a year and put at the start edge: it is a filter, not a
/// heading, and a dropdown the width of a monitor asks for something much
/// longer than "1447 هـ".
class _SeasonFilter extends StatelessWidget {
  const _SeasonFilter({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DropdownButtonFormField<String>(
          initialValue: state.selectedSeasonId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l.dashboardSeason,
            prefixIcon: const Icon(AppIcons.seasons),
            isDense: true,
          ),
          items: [
            for (final s in state.seasons)
              DropdownMenuItem(
                value: s.id,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        l.seasonHijriYear(s.hijriYear),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (s.isCurrent) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(AppIcons.current, size: 14, color: scheme.secondary),
                    ],
                  ],
                ),
              ),
          ],
          onChanged: (v) =>
              v == null ? null : context.read<DashboardCubit>().selectSeason(v),
        ),
      ),
    );
  }
}
