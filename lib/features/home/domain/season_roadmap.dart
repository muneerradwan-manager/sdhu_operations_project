import 'package:flutter/widgets.dart';

import '../../../core/constants/permission_codes.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_cubit.dart';

// The season in the order it is actually run.
//
// This is not the list of doors again. [homeDestinations] answers "what may
// this person open?", which is the right question for a menu and the wrong one
// for somebody who has just been handed the app: it says WHERE everything is
// and nothing at all about WHEN. A man who can open المواسم and البيانات
// المرجعية still does not know that the second is useless before the first, and
// that both are useless once the buses have started moving.
//
// So this is the other axis. One season, laid out from the week before it opens
// to the week after it closes, in phases, with each step saying what it is for
// and what it is waiting on. It is the only screen in the app that describes
// the WORK rather than the software.
//
// Two rules it is built by, and they pull against each other:
//
//   * **The map is complete.** Every step of the season is drawn, including the
//     ones this reader will never take. A map with the other man's half torn
//     out is not a map — a تشغيلي who cannot see that somebody had to fill in
//     the master data before his file existed does not understand his own
//     place in the season.
//   * **A step that is not yours never pretends to be a door.** It is dimmed,
//     it carries a lock, it says بيد الإدارة, and it does not respond to a
//     press. This is the exact opposite of the failure the tiles guard
//     against — that one shows a door and then has the route refuse it; this
//     one says up front that the step is in other hands and offers nothing.
//
// The permission on each step is the same rule its route is guarded by in
// `sectionGuards`, exactly as in [homeDestinations], and
// `test/season_roadmap_test.dart` fails if a step ever offers a route the
// router would bounce.

/// One phase of the season: a name, a colour, and the steps under it.
enum RoadmapPhase {
  /// Before anything moves. Done once a year, and everything else stands on it.
  setup(Accent.gold),

  /// The paperwork the season will be worked through: the files, who is in
  /// them, the forms and the notices.
  build(Accent.greenDeep),

  /// ذو الحجة itself. The only phase most of the mission ever touches, and the
  /// only one measured in hours rather than weeks.
  run(Accent.green),

  /// Watching it happen, and reading it back.
  watch(Accent.plum),

  /// Closing the year: the marks, the records taken out, the next season.
  close(Accent.red);

  const RoadmapPhase(this.accent);

  final Accent accent;

  /// Its number on the spine — 1-based, because it is read aloud as "المرحلة
  /// الأولى" and not as an array index.
  int get step => index + 1;

  String title(AppLocalizations l) => switch (this) {
    setup => l.roadmapPhaseSetup,
    build => l.roadmapPhaseBuild,
    run => l.roadmapPhaseRun,
    watch => l.roadmapPhaseWatch,
    close => l.roadmapPhaseClose,
  };

  /// When in the year this phase happens — the line under the name.
  String when(AppLocalizations l) => switch (this) {
    setup => l.roadmapPhaseSetupWhen,
    build => l.roadmapPhaseBuildWhen,
    run => l.roadmapPhaseRunWhen,
    watch => l.roadmapPhaseWatchWhen,
    close => l.roadmapPhaseCloseWhen,
  };

  String body(AppLocalizations l) => switch (this) {
    setup => l.roadmapPhaseSetupBody,
    build => l.roadmapPhaseBuildBody,
    run => l.roadmapPhaseRunBody,
    watch => l.roadmapPhaseWatchBody,
    close => l.roadmapPhaseCloseBody,
  };
}

/// One step of the season.
@immutable
class RoadmapStep {
  const RoadmapStep({
    required this.phase,
    required this.icon,
    required this.title,
    required this.body,
    required this.route,
    required this.open,
    this.note,
    this.everyone = false,
  });

  final RoadmapPhase phase;
  final IconData icon;
  final String title;

  /// What is done at this step, and why it stands where it stands.
  final String body;

  /// Where it is done. Offered as a door only when [open] — see the head of
  /// this file.
  final String route;

  /// Whether this reader may take the step.
  final bool open;

  /// The one thing about this step that nothing on the screen behind it would
  /// have told you: that a report written with no network is not lost, that a
  /// check-in is refused from the wrong end of the street, that closing a file
  /// is what releases its evaluations.
  ///
  /// Deliberately not on every step. A page where every card carries a tip is a
  /// page where none of them is read.
  final String? note;

  /// Whether the step belongs to everybody rather than to a permission.
  ///
  /// Drawn as a badge, because it is genuinely surprising: most of what an
  /// operations app does is gated, and "anybody may report that a coach has
  /// broken down" is a decision somebody should be able to see was made.
  final bool everyone;
}

/// The whole season, in order, with each step told whether this reader may take
/// it.
///
/// Nothing is filtered out. See the head of this file for why.
List<RoadmapStep> seasonRoadmap(SessionState s, AppLocalizations l) {
  // The dashboard answers for itself section by section on the server, so
  // anyone holding any part of it may open it — the same union the tiles use.
  final dashboard =
      s.can(PermissionCodes.employeesView) ||
      s.can(PermissionCodes.approvalsView) ||
      s.can(PermissionCodes.modulesViewAll) ||
      s.can(PermissionCodes.modulesMembers);

  return [
    // ── ١ · التأسيس ──────────────────────────────────────────────────────
    RoadmapStep(
      phase: RoadmapPhase.setup,
      icon: AppIcons.seasons,
      title: l.navSeasons,
      body: l.roadmapStepSeason,
      note: l.roadmapNoteSeason,
      route: Routes.seasons,
      open: s.canSeeSeasons,
    ),
    RoadmapStep(
      phase: RoadmapPhase.setup,
      icon: AppIcons.referenceData,
      title: l.navReferenceData,
      body: l.roadmapStepReference,
      note: l.roadmapNoteReference,
      route: Routes.referenceData,
      open: s.can(PermissionCodes.referenceView),
    ),
    RoadmapStep(
      phase: RoadmapPhase.setup,
      icon: AppIcons.approvals,
      title: l.navApprovals,
      body: l.roadmapStepApprovals,
      route: Routes.approvals,
      open: s.can(PermissionCodes.approvalsView),
    ),
    RoadmapStep(
      phase: RoadmapPhase.setup,
      icon: AppIcons.employees,
      title: l.navEmployees,
      body: l.roadmapStepEmployees,
      route: Routes.employees,
      open: s.can(PermissionCodes.employeesView),
    ),
    RoadmapStep(
      phase: RoadmapPhase.setup,
      icon: AppIcons.permissions,
      title: l.navPermissions,
      body: l.roadmapStepPermissions,
      note: l.roadmapNotePermissions,
      route: Routes.permissions,
      open: s.can(PermissionCodes.permissionsView),
    ),

    // ── ٢ · بناء العمل ───────────────────────────────────────────────────
    RoadmapStep(
      phase: RoadmapPhase.build,
      icon: AppIcons.modules,
      title: l.navModulesManage,
      body: l.roadmapStepFiles,
      note: l.roadmapNoteFiles,
      route: Routes.modulesManage,
      open: s.can(PermissionCodes.modulesViewAll),
    ),
    RoadmapStep(
      phase: RoadmapPhase.build,
      icon: AppIcons.tasks,
      title: l.navTasksManage,
      body: l.roadmapStepAssign,
      route: Routes.tasksManage,
      open: s.can(PermissionCodes.tasksAssign),
    ),
    RoadmapStep(
      phase: RoadmapPhase.build,
      icon: AppIcons.evaluationForms,
      title: l.navEvaluationForms,
      body: l.roadmapStepForms,
      note: l.roadmapNoteForms,
      route: Routes.evaluationForms,
      open:
          s.can(PermissionCodes.evaluationsTemplates) ||
          s.can(PermissionCodes.evaluationsAssign),
    ),
    RoadmapStep(
      phase: RoadmapPhase.build,
      icon: AppIcons.reports,
      title: l.navReportsManage,
      body: l.roadmapStepCirculars,
      route: Routes.reportsManage,
      open: s.can(PermissionCodes.reportsViewAll),
    ),

    // ── ٣ · التشغيل ──────────────────────────────────────────────────────
    //
    // Everything in this phase is open to everybody, and that is the phase's
    // whole character: ذو الحجة is not run by the people with permissions, it
    // is run by whoever is standing in Mina at three in the morning.
    RoadmapStep(
      phase: RoadmapPhase.run,
      icon: AppIcons.modules,
      title: l.navModules,
      body: l.roadmapStepMyFiles,
      route: Routes.modules,
      open: true,
      everyone: true,
    ),
    RoadmapStep(
      phase: RoadmapPhase.run,
      icon: AppIcons.tasks,
      title: l.navTasks,
      body: l.roadmapStepMyTasks,
      note: l.roadmapNoteOffline,
      route: Routes.tasks,
      open: true,
      everyone: true,
    ),
    RoadmapStep(
      phase: RoadmapPhase.run,
      icon: AppIcons.qrCode,
      title: l.myCheckInsTitle,
      body: l.roadmapStepCheckIn,
      note: l.roadmapNoteCheckIn,
      route: Routes.myCheckIns,
      open: true,
      everyone: true,
    ),
    RoadmapStep(
      phase: RoadmapPhase.run,
      icon: AppIcons.warning,
      title: l.incidentTitle,
      body: l.roadmapStepIncident,
      note: l.roadmapNoteIncident,
      route: Routes.raiseIncident,
      open: true,
      everyone: true,
    ),
    RoadmapStep(
      phase: RoadmapPhase.run,
      icon: AppIcons.reports,
      title: l.navReports,
      body: l.roadmapStepReadCirculars,
      route: Routes.reports,
      open: true,
      everyone: true,
    ),
    RoadmapStep(
      phase: RoadmapPhase.run,
      icon: AppIcons.complaints,
      title: l.navMyComplaints,
      body: l.roadmapStepComplain,
      route: Routes.complaints,
      open: true,
      everyone: true,
    ),

    // ── ٤ · الإشراف ──────────────────────────────────────────────────────
    RoadmapStep(
      phase: RoadmapPhase.watch,
      icon: AppIcons.dashboard,
      title: l.navDashboard,
      body: l.roadmapStepDashboard,
      route: Routes.dashboard,
      open: dashboard,
    ),
    RoadmapStep(
      phase: RoadmapPhase.watch,
      icon: AppIcons.map,
      title: l.seasonMapTitle,
      body: l.roadmapStepMap,
      route: Routes.seasonMap,
      open: s.can(PermissionCodes.mapView),
    ),
    RoadmapStep(
      phase: RoadmapPhase.watch,
      icon: AppIcons.checkIn,
      title: l.presenceTitle,
      body: l.roadmapStepPresence,
      route: Routes.presence,
      open: s.can(PermissionCodes.checkinBoard),
    ),
    RoadmapStep(
      phase: RoadmapPhase.watch,
      icon: AppIcons.warning,
      title: l.incidentsTitle,
      body: l.roadmapStepIncidents,
      route: Routes.incidents,
      open: s.can(PermissionCodes.incidentsReceive),
    ),
    RoadmapStep(
      phase: RoadmapPhase.watch,
      icon: AppIcons.complaints,
      title: l.navComplaints,
      body: l.roadmapStepComplaints,
      note: l.roadmapNoteComplaints,
      route: Routes.complaintsManage,
      open: s.can(PermissionCodes.complaintsView),
    ),
    RoadmapStep(
      phase: RoadmapPhase.watch,
      icon: AppIcons.auditLog,
      title: l.navAuditLog,
      body: l.roadmapStepAudit,
      route: Routes.auditLog,
      open: s.can(PermissionCodes.auditView),
    ),

    // ── ٥ · الإغلاق ──────────────────────────────────────────────────────
    RoadmapStep(
      phase: RoadmapPhase.close,
      icon: AppIcons.evaluations,
      title: l.navEvaluations,
      body: l.roadmapStepEvaluate,
      note: l.roadmapNoteEvaluate,
      route: Routes.evaluations,
      open: true,
      everyone: true,
    ),
    RoadmapStep(
      phase: RoadmapPhase.close,
      icon: AppIcons.upload,
      title: l.exportTitle,
      body: l.roadmapStepExport,
      route: Routes.export,
      open: s.can(PermissionCodes.exportData),
    ),
    RoadmapStep(
      phase: RoadmapPhase.close,
      icon: AppIcons.milestone,
      title: l.roadmapStepArchiveTitle,
      body: l.roadmapStepArchive,
      note: l.roadmapNoteArchive,
      route: Routes.seasons,
      open: s.canSeeSeasons,
    ),
  ];
}

/// The map cut into its phases, in the enum's own order.
///
/// Unlike the shelves of the home grid, no phase is ever dropped: a season has
/// five of these whoever is reading, and a map missing its middle is not a map.
List<({RoadmapPhase phase, List<RoadmapStep> steps})> roadmapPhases(
  List<RoadmapStep> steps,
) => [
  for (final phase in RoadmapPhase.values)
    (
      phase: phase,
      steps: [
        for (final step in steps)
          if (step.phase == phase) step,
      ],
    ),
];
