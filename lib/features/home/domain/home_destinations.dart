import 'package:flutter/widgets.dart';

import '../../../core/constants/permission_codes.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_cubit.dart';
import '../../checkin/domain/check_in.dart' show isPlaceScannerSupported;

// Every door the home page opens, in one list.
//
// It used to be two lists written inline in the screen that drew them, which
// was fine while there was one such screen. There are now two — the grid of
// tiles and the standing sidebar — and a catalogue written twice is a
// catalogue that disagrees with itself: the second copy is the one that gets a
// new section late, or keeps a permission the first one dropped. The rule that
// matters most here is the one that would break most quietly. A door shown to
// somebody who may not walk through it is not merely untidy; it is the app
// telling a man he has authority he does not have, and then a route refusing
// him at the threshold.
//
// So the list is declared once and both screens read it. What each does with
// an entry still differs — a tile draws its subtitle, a rail draws it as a
// tooltip — but WHICH entries exist, in what order, under whose permission, is
// answered here and nowhere else.
//
// Accent per destination, so a returning user recognises a door by its colour
// before they finish reading the label — which only works if the colours are
// spread. They were not: green held nine of the thirteen tiles, on a green
// backdrop, under a green app bar, beside a green greeting ring. A colour that
// covers three quarters of a screen is not an accent, it is the paper.
//
// The families carry the meaning, and all three are actually spent:
//
//   * GREEN — the mission's own work. It stays the app's primary — it is the
//     backdrop, the theme and the app bar — which is exactly why it now takes
//     three of these rather than nine. A door is green here when it is the
//     work itself, not merely when it is ours.
//   * GOLD — the calendar and the reference material: the season, the lists
//     everything else is built from, and the times published to the whole
//     mission.
//   * RED — people, and what is said and decided about them: the employees,
//     the approvals, a person's own complaints, and — in the deepest of the
//     reds — the record that keeps all of it.
//
// Each is an [Accent] rather than a raw brand colour, because a print palette
// does not divide evenly across a night mode and a paper one: every red is
// unreadable on the dark backdrop and every gold on the light. See
// app_accents.dart for the measurements.

/// A shelf of the home page: a name, a colour, and the destinations under it.
///
/// A reader holding every permission is handed a dozen doors in الإدارة, and a
/// dozen doors in one undivided grid is not a menu, it is a wall. He knows what
/// he came for; what he cannot do is find it, because nothing on the page says
/// where that kind of thing is kept. So the section is shelved, and each shelf
/// is named and coloured — the name does the finding, and the colour is what he
/// remembers the second time.
///
/// The shelf is DECLARED by each entry rather than derived from its position,
/// which is the other half of the fix and the less visible one. The colour used
/// to be assigned by index — two tiles to a colour, counting down the filtered
/// list — so a reader without `approvals.view` shifted every pair below the gap
/// onto a different colour, and two people describing this screen to each other
/// were describing different screens. A shelf is a property of what the door
/// IS; it survives the filter, and nothing has to be counted.
enum HomeGroup {
  /// Everybody's own work, and it is everybody's by assignment rather than by
  /// grant: a file reaches its members by name, an evaluation reaches its
  /// evaluator by name, and a task list is owned by existing.
  ///
  /// The one shelf that is not part of الإدارة — see [isAdmin].
  general(Accent.green),

  /// The paperwork itself: the season's operational files, the decisions drawn
  /// from them, and the blank forms the office writes. Green, the mission's own
  /// work.
  ///
  /// Everything here is paper this office ISSUES. That is the line the
  /// complaints register turned out to be on the wrong side of — see where it
  /// stands now, and why.
  files(Accent.greenDeep),

  /// Everybody with an account: who they are, whether they are let in at all,
  /// what they may do, what they are told to do — and what has been said about
  /// them. Red, which is what red is for here.
  people(Accent.red),

  /// The year, and the lists everything else is built from.
  season(Accent.gold),

  /// Looking at all of it: the numbers from above, the acts in order, and the
  /// urgent reports. The deepest red there is.
  ///
  /// It used to be described as the shelf that only ever looks BACK, and two of
  /// the things on it have since left for that reason — the complaints and the
  /// evaluations register are both worked through rather than read after the
  /// fact. What remains is the season seen whole, plus the screens here that
  /// are read while it is still happening.
  oversight(Accent.plum);

  const HomeGroup(this.accent);

  /// The shelf's own colour, which every door under it wears unless it names
  /// one of its own — see [HomeDestination.accent].
  final Accent accent;

  /// Whether this shelf lives under the الإدارة heading.
  ///
  /// A person is two things at once on this page — somebody with authority and
  /// somebody with work — and the two were once mixed in one list: "الملفات
  /// التشغيلية" meant his own postings to one man and the season's whole
  /// paperwork to another, depending on what he held.
  bool get isAdmin => this != HomeGroup.general;

  String title(AppLocalizations l) => switch (this) {
    general => l.homeGeneralSection,
    files => l.homeAdminGroupFiles,
    people => l.homeAdminGroupPeople,
    season => l.homeAdminGroupSeason,
    oversight => l.homeAdminGroupOversight,
  };
}

/// One door: what it is called, what is behind it, and where it goes.
@immutable
class HomeDestination {
  const HomeDestination({
    required this.group,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.accent,
    this.action,
    this.actionLabel,
    this.actionIcon,
  });

  final HomeGroup group;
  final IconData icon;
  final String title;

  /// One line saying what lives behind the door. The grid prints it under the
  /// title; the rail hands it to the tooltip and to whatever reads the tree
  /// aloud, because a rail has no room for it and dropping it entirely would
  /// take the explanation away from the people who need it most.
  final String subtitle;

  final String route;

  /// Overrides [HomeGroup.accent] for a door that carries its own colour.
  ///
  /// Only العام spends this. Its doors are not one shelf of one kind of work —
  /// they are a man's files, his errands, his marks, his complaints and his
  /// whereabouts — and painting all six the group's green is the wash this
  /// palette was rebalanced to remove.
  final Accent? accent;

  /// A second thing this door can do, and it is a DIFFERENT thing: the door
  /// opens something, the action writes something. `?compose=1` on the same
  /// route, so the act arrives THROUGH the record rather than past it — closing
  /// the composer lands on the line it just wrote.
  final String? action;
  final String? actionLabel;
  final IconData? actionIcon;

  Color colorOf(BuildContext context) => (accent ?? group.accent).of(context);
}

/// Every door this session may walk through, in the order the page shows them.
///
/// The filter is the point. Each `if` here is the same rule the route itself is
/// guarded by in `sectionGuards` — keeping the two side by side is what stops
/// them drifting into a section that is hidden but open, or shown but shut.
/// `test/home_destinations_test.dart` fails if a guarded route appears here
/// under a different permission than the one that guards it.
List<HomeDestination> homeDestinations(
  SessionState session,
  AppLocalizations l,
) {
  // The dashboard has a section per permission and drops the rest, so the door
  // opens for anyone holding any one of them. Listed rather than asked of the
  // page, because a door that leads to an empty page is worse than no door.
  final canSeeDashboard =
      session.can(PermissionCodes.employeesView) ||
      session.can(PermissionCodes.approvalsView) ||
      session.can(PermissionCodes.modulesViewAll) ||
      session.can(PermissionCodes.modulesMembers);

  return <HomeDestination>[
    // ── العام ────────────────────────────────────────────────────────────
    //
    // The work, and it is everybody's: a file reaches its members through
    // assignment, not through a permission. This lists what THIS person was put
    // into — the same handful for a manager as for anyone else, because being
    // allowed to open every file does not make every file his work.
    HomeDestination(
      group: HomeGroup.general,
      icon: AppIcons.modules,
      title: l.navModules,
      subtitle: l.navModulesSubtitle,
      route: Routes.modules,
      accent: Accent.green,
    ),
    // Published to everybody, and gated by nothing: a circular is not an
    // assignment, it is information the whole mission needs. Reading is open to
    // any approved account; entering one is what needs a permission.
    HomeDestination(
      group: HomeGroup.general,
      icon: AppIcons.reports,
      title: l.navReports,
      subtitle: l.navReportsSubtitle,
      route: Routes.reports,
      accent: Accent.goldSoft,
    ),
    // Gated by nothing, for a reason of its own: an evaluation reaches its
    // evaluator by NAME. There is no permission to fill one, so there is
    // nothing to hide this behind — and a person with no errands opens it to an
    // empty list, which is the true answer rather than a missing door. What was
    // written ABOUT them is not here either; that lives on their own profile,
    // which is the one door that hands over the marks with no name on them.
    HomeDestination(
      group: HomeGroup.general,
      icon: AppIcons.evaluations,
      title: l.navEvaluations,
      subtitle: l.navEvaluationsSubtitle,
      route: Routes.evaluations,
      accent: Accent.plum,
    ),
        // Where this person has been, and the way to add to it. Two verbs on one
    // door, and they belong together: the man about to scan a code is the same
    // man wondering whether last night's scan registered.
    //
    // Gated by nothing, twice over. Filing your own arrival needs no grant —
    // the code on the wall and the phone's position are the credential, and a
    // system in which only certain people may report where they are is a system
    // that does not know where anybody is. Reading your own record needs none
    // either: `place_check_ins` opens its policy with `profile_id = auth.uid()`,
    // and §30.3 of 0098 says so in words.
    //
    // The door itself stays on every platform — a man reads where he has been
    // from whatever is in front of him — and only the ACT goes, on a machine
    // with no camera to open. See [isPlaceScannerSupported].
    HomeDestination(
      group: HomeGroup.general,
      icon: AppIcons.auditLog,
      title: l.myCheckInsTitle,
      subtitle: l.navMyCheckInsSubtitle,
      route: Routes.myCheckIns,
      accent: Accent.greenDark,
      action: isPlaceScannerSupported ? '${Routes.myCheckIns}?compose=1' : null,
      actionLabel: l.checkInAction,
      actionIcon: AppIcons.qrCode,
    ),
    // Gated by nothing, and for the same reason as the two above: a man reading
    // where he himself is being sent, and when he flies home, is not exercising
    // a privilege. RLS says the same thing (0129) — his own journey is his
    // whatever else he holds.
    HomeDestination(
      group: HomeGroup.general,
      icon: AppIcons.travel,
      title: l.navMyJourney,
      subtitle: l.navMyJourneySubtitle,
      route: Routes.myJourney,
      accent: Accent.greenDeep,
    ),
    // Gated by nothing: everyone owns a task list by existing (0105), and what
    // was assigned to them arrived by name, not by grant. No relation to the
    // operational files — that is the whole point of it.
    HomeDestination(
      group: HomeGroup.general,
      icon: AppIcons.tasks,
      title: l.navTasks,
      subtitle: l.navTasksSubtitle,
      route: Routes.tasks,
      accent: Accent.gold,
      action: '${Routes.tasks}?compose=1',
      actionLabel: l.tasksNew,
    ),
    // Gated by nothing, and that is the point: complaining is not a permission
    // somebody grants. This is what a person filed and the way to file another.
    // What was filed ABOUT them is not here — that lives on their own profile,
    // which is where a man looks for what is being said about him, and is the
    // one door that hands it over without a name on it.
    HomeDestination(
      group: HomeGroup.general,
      icon: AppIcons.complaints,
      title: l.navMyComplaints,
      subtitle: l.navMyComplaintsSubtitle,
      route: Routes.complaints,
      accent: Accent.red,
      action: '${Routes.complaints}?compose=1',
      actionLabel: l.complaintsNew,
    ),
    // Gated by nothing, for the reason [Routes.myIncidents] gives: reading
    // what you raised needs no grant, any more than raising it did. It used
    // to be a chip riding along on every app bar in the app instead of a door
    // of its own — reachable everywhere and found, by the same token, nowhere
    // in particular. Here it is a fact about a person's own reports, beside
    // the rest of what is his.
    HomeDestination(
      group: HomeGroup.general,
      icon: AppIcons.warning,
      title: l.myIncidentsTitle,
      subtitle: l.navMyIncidentsSubtitle,
      route: Routes.myIncidents,
      accent: Accent.redDeep,
      action: '${Routes.myIncidents}?compose=1',
      actionLabel: l.incidentTitle,
    ),

    // No door for the profile: the greeting panel already carries the user's
    // face and name, and tapping something with your own name on it is where
    // anyone looks for it first.

    // ── الإدارة · الملفات والقرارات والتعميمات ───────────────────────────
    if (session.can(PermissionCodes.modulesViewAll))
      HomeDestination(
        group: HomeGroup.files,
        icon: AppIcons.modules,
        title: l.navModulesManage,
        subtitle: l.navModulesManageSubtitle,
        route: Routes.modulesManage,
      ),
    if (session.can(PermissionCodes.reportsViewAll))
      HomeDestination(
        group: HomeGroup.files,
        icon: AppIcons.reports,
        title: l.navReportsManage,
        subtitle: l.navReportsManageSubtitle,
        route: Routes.reportsManage,
      ),
    // The two halves of التقييم are deliberately two doors rather than one
    // section with a switch. The paper and the marks are different trusts:
    // whoever writes the questions need not read anybody's answers. Which is
    // also why they land on different shelves — the register is oversight, and
    // the blank form is the office's own stationery, filed with the rest of the
    // paperwork. Filling one is neither; that is an errand, and it stands above
    // under العام with the rest of a person's own work.
    //
    // سجل التقييمات is not here either — but it is no longer nowhere. It used
    // to be reached only from inside إدارة التقييمات, on the reasoning that a
    // register means nothing away from the papers it was written from. That
    // reasoning holds for ONE form's sheets, and that door is still on every
    // form card. It does not hold for the register itself: every sheet on
    // every form, read to see how the season's appraisals are going, is
    // oversight — so it stands with the dashboard and the log, below.
    if (session.can(PermissionCodes.evaluationsTemplates))
      HomeDestination(
        group: HomeGroup.files,
        icon: AppIcons.evaluationForms,
        title: l.navEvaluationForms,
        subtitle: l.navEvaluationFormsSubtitle,
        route: Routes.evaluationForms,
      ),

    // ── الإدارة · الأشخاص والصلاحيات ─────────────────────────────────────
    if (session.can(PermissionCodes.employeesView))
      HomeDestination(
        group: HomeGroup.people,
        icon: AppIcons.employees,
        title: l.navEmployees,
        subtitle: l.navEmployeesSubtitle,
        route: Routes.employees,
      ),
    if (session.can(PermissionCodes.approvalsView))
      HomeDestination(
        group: HomeGroup.people,
        icon: AppIcons.approvals,
        title: l.navApprovals,
        subtitle: l.navApprovalsSubtitle,
        route: Routes.approvals,
      ),
    // Directly beside the account queue, because they are the same JOB.
    //
    // The whole register is oversight work; filing one and reading your own are
    // not — those are everybody's, and stand above under العام beside the rest
    // of a person's own work.
    //
    // It has now moved twice, and the second move corrects the reasoning of the
    // first. Leaving الإشراف والسجلات was right: that shelf is what you read
    // AFTER the fact, and a complaint register is worked THROUGH — replied to,
    // dismissed, locked. But "worked through" does not pick out الملفات; it
    // picks out a QUEUE OF CASES, and this app has exactly one other —
    // اعتماد الحسابات, on this shelf. Two queues with the same rhythm on two
    // different shelves was the mistake.
    //
    // Three things settle it. الملفات والقرارات والتعميمات names three kinds of
    // paper the OFFICE writes, and a complaint arrives from outside that pen —
    // filing it there mixes what we issue with what reaches us. What a complaint
    // escalates INTO lands on a person and on their account (§24: a rule here
    // can suspend one with no human in the loop), and accounts are what this
    // shelf governs. And whoever opens it opens the staff directory and the
    // approvals queue in the same sitting, not the operational files.
    //
    // The honest objection is that a complaint may be about a hotel or a file
    // rather than a person. It may — but somebody still has to answer for it,
    // and this shelf already carries إسناد المهام, which is neither a person
    // nor a permission.
    if (session.can(PermissionCodes.complaintsView))
      HomeDestination(
        group: HomeGroup.people,
        icon: AppIcons.complaints,
        title: l.navComplaints,
        subtitle: l.navComplaintsSubtitle,
        route: Routes.complaintsManage,
      ),
    // Beside the permissions, and for the same reason: writing a task onto
    // somebody's list is an act aimed at a PERSON, and whoever came here came
    // looking for him. Not on the files shelf — this system has no relation to
    // the operational files (0105).
    if (session.can(PermissionCodes.tasksAssign))
      HomeDestination(
        group: HomeGroup.people,
        icon: AppIcons.tasks,
        title: l.navTasksManage,
        subtitle: l.navTasksManageSubtitle,
        route: Routes.tasksManage,
      ),
    // With the people rather than on a shelf of its own: what a man may do is a
    // fact about the man, and somebody who came here to change it came looking
    // for HIM.
    if (session.can(PermissionCodes.permissionsView))
      HomeDestination(
        group: HomeGroup.people,
        icon: AppIcons.permissions,
        title: l.navPermissions,
        subtitle: l.navPermissionsSubtitle,
        route: Routes.permissions,
      ),

    // ── الإدارة · الموسم والمراجع ────────────────────────────────────────
    if (session.canSeeSeasons)
      HomeDestination(
        group: HomeGroup.season,
        icon: AppIcons.seasons,
        title: l.navSeasons,
        subtitle: l.navSeasonsSubtitle,
        route: Routes.seasons,
      ),
    if (session.can(PermissionCodes.referenceView))
      HomeDestination(
        group: HomeGroup.season,
        icon: AppIcons.referenceData,
        title: l.navReferenceData,
        subtitle: l.navReferenceDataSubtitle,
        route: Routes.referenceData,
      ),
    // The season's flights and movements. It belongs on the season's shelf
    // rather than with the people: what is administered here is the year's
    // travel, and the men on it are who each trip happens to be carrying.
    if (session.can(PermissionCodes.travelViewAll))
      HomeDestination(
        group: HomeGroup.season,
        icon: AppIcons.travel,
        title: l.navTravel,
        subtitle: l.navTravelSubtitle,
        route: Routes.travel,
      ),

    // ── الإدارة · الإشراف والسجلات ───────────────────────────────────────
    //
    // Not a door among the doors. Every other one is a place to go and do
    // something; this is about all of them at once, which is why it heads the
    // shelf of things that look at the season rather than do anything to it.
    if (canSeeDashboard)
      HomeDestination(
        group: HomeGroup.oversight,
        icon: AppIcons.dashboard,
        title: l.navDashboard,
        subtitle: l.navDashboardSubtitle,
        route: Routes.dashboard,
      ),
    // Every appraisal in the mission, by the thing being appraised. It reads
    // like the dashboard rather than like a queue — nothing on it is worked
    // THROUGH, it is looked at — which is what puts it on this shelf and not
    // beside the forms it was written from. Those stay in الملفات: writing the
    // questions and reading everyone's answers are two different trusts, and
    // §26.1 keeps them two different doors.
    if (session.can(PermissionCodes.evaluationsView))
      HomeDestination(
        group: HomeGroup.oversight,
        icon: AppIcons.evaluations,
        title: l.navEvaluationsManage,
        subtitle: l.navEvaluationsManageSubtitle,
        route: Routes.evaluationsManage,
      ),
    // Beside the dashboard, and the pairing is the meaning: one is the season
    // from above, the other is the season act by act.
    if (session.can(PermissionCodes.auditView))
      HomeDestination(
        group: HomeGroup.oversight,
        icon: AppIcons.auditLog,
        title: l.navAuditLog,
        subtitle: l.navAuditLogSubtitle,
        route: Routes.auditLog,
      ),
    // The season drawn. It belongs on the oversight shelf beside the dashboard
    // and for the same reason — both are the season seen whole rather than a
    // thing to go and do — and it is the only one of them that is read while the
    // season is still happening.
    //
    // Gated since 0100. The RPC still answers per reader and that is untouched;
    // what changed is that the season laid out whole is an operations-room view,
    // and a member does not need one to serve in his own tower.
    if (session.can(PermissionCodes.mapView))
      HomeDestination(
        group: HomeGroup.oversight,
        icon: AppIcons.checkIn,
        title: l.seasonMapTitle,
        subtitle: l.seasonMapSubtitle,
        route: Routes.seasonMap,
      ),
    // Taking data out of the app. It belongs on the oversight shelf and not in
    // settings: settings is where a person adjusts how the app behaves FOR HIM —
    // the language, the theme, whether it may notify him. An export is not a
    // preference, it is work done ON the season's records, and it sits with the
    // other screens that look at all of them at once.
    //
    // Gated since 0100, and it is the grant that most needs a door. It used to
    // gate itself by offering only what the reader could already open;
    // `export.data` now widens the row policies themselves, so a holder takes
    // out what he cannot see on any screen.
    if (session.can(PermissionCodes.exportData))
      HomeDestination(
        group: HomeGroup.oversight,
        icon: AppIcons.upload,
        title: l.exportTitle,
        subtitle: l.exportSubtitle,
        route: Routes.export,
      ),
    // The operations room's own screen. Oversight, but of a different kind from
    // the rest of this group: everything else here is read after the fact, and
    // this one is read while it is still happening.
    if (session.can(PermissionCodes.incidentsReceive))
      HomeDestination(
        group: HomeGroup.oversight,
        icon: AppIcons.warning,
        title: l.incidentsTitle,
        subtitle: l.incidentsEmptyHint,
        route: Routes.incidents,
      ),
    // Beside the map, and for the same reason: both are the season seen whole
    // while it is still happening. The map says where the places are and this
    // says who is in them.
    if (session.can(PermissionCodes.checkinBoard))
      HomeDestination(
        group: HomeGroup.oversight,
        icon: AppIcons.checkIn,
        title: l.presenceTitle,
        subtitle: l.presenceSubtitle,
        route: Routes.presence,
      ),
  ];
}

/// The same list, cut into shelves, keeping the enum's own order and dropping
/// any shelf nothing landed on.
///
/// A group with nothing under it produces no heading — a reader who may see the
/// seasons but not the reference lists gets الموسم والمراجع with one door under
/// it, and a reader who may see neither is never told the shelf exists.
List<({HomeGroup group, List<HomeDestination> destinations})> homeShelves(
  List<HomeDestination> destinations,
) => [
  for (final group in HomeGroup.values)
    if (destinations.any((d) => d.group == group))
      (
        group: group,
        destinations: [
          for (final d in destinations)
            if (d.group == group) d,
        ],
      ),
];
