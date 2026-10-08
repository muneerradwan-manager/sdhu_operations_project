import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/constants/permission_codes.dart';
import 'package:sdhu_operations_project/core/router/app_router.dart';
import 'package:sdhu_operations_project/features/auth/application/session_cubit.dart';
import 'package:sdhu_operations_project/features/home/domain/season_roadmap.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile_enums.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

/// The operational map draws the WHOLE season, including the steps this reader
/// will never take — which makes it the one screen in the app that deliberately
/// shows what somebody may not do.
///
/// That is safe exactly as long as one thing holds: **a step is offered as a
/// door if and only if the router would let this reader through it.** Under-
/// permit and the map hides work from the man whose job it is; over-permit and
/// it invites him into a page that bounces him back to the home screen, which
/// is worse than the lock it was trying to avoid drawing.
SessionState _holding(Set<String> permissions) =>
    SessionState(status: SessionStatus.approved, permissions: permissions);

final _admin = SessionState(
  status: SessionStatus.approved,
  profile: const Profile(
    id: 'admin',
    accountStatus: AccountStatus.approved,
    isAdmin: true,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  // One at a time, for the reason written out in `home_destinations_test.dart`:
  // a step drawn on one code and guarded by another passes every test where the
  // reader happens to hold both.
  const codes = [
    PermissionCodes.employeesView,
    PermissionCodes.approvalsView,
    PermissionCodes.seasonsView,
    PermissionCodes.modulesViewAll,
    PermissionCodes.modulesMembers,
    PermissionCodes.exportData,
    PermissionCodes.mapView,
    PermissionCodes.tasksAssign,
    PermissionCodes.checkinBoard,
    PermissionCodes.referenceView,
    PermissionCodes.reportsViewAll,
    PermissionCodes.permissionsView,
    PermissionCodes.auditView,
    PermissionCodes.complaintsView,
    PermissionCodes.evaluationsView,
    PermissionCodes.evaluationsTemplates,
    PermissionCodes.evaluationsAssign,
    PermissionCodes.incidentsReceive,
  ];

  Iterable<(String, SessionState)> sessions() sync* {
    yield ('a session holding nothing', _holding({}));
    yield ('an admin', _admin);
    for (final code in codes) {
      yield ('somebody holding only $code', _holding({code}));
    }
  }

  group('seasonRoadmap', () {
    test('a step is unlocked exactly when its route would admit the reader', () {
      for (final (description, session) in sessions()) {
        for (final step in seasonRoadmap(session, l)) {
          final guard = sectionGuards[step.route];
          if (guard == null) continue;
          expect(
            step.open,
            guard(session),
            reason:
                '"${step.title}" (${step.route}) disagreed with its own route '
                'for $description',
          );
        }
      }
    });

    test('the ungated steps are open to everybody', () {
      // Everything in التشغيل, and the reasoning is the phase's whole
      // character: a system in which only certain people may report a
      // broken-down coach is a system that does not find out about the coach.
      //
      // The dashboard is the one exception and is excluded by name: it is
      // deliberately absent from `sectionGuards` because it answers for itself
      // section by section on the server, so the map has to work out its own
      // union — which the test below does separately.
      for (final (description, session) in sessions()) {
        for (final step in seasonRoadmap(session, l)) {
          if (sectionGuards.containsKey(step.route)) continue;
          if (step.route == Routes.dashboard) continue;
          expect(
            step.open,
            isTrue,
            reason:
                '"${step.title}" was locked for $description, and it '
                'belongs to everyone',
          );
        }
      }
    });

    test('the everyone badge is never worn by a guarded step', () {
      // The badge says "no permission stands in the way of this". Worn by a
      // step the router guards, it is simply a lie.
      for (final (_, session) in sessions()) {
        for (final step in seasonRoadmap(session, l).where((s) => s.everyone)) {
          expect(
            sectionGuards.containsKey(step.route),
            isFalse,
            reason:
                '"${step.title}" claims to be open to everyone, and its '
                'route is guarded',
          );
          expect(step.open, isTrue);
        }
      }
    });

    test('the dashboard opens for any one of the four it is built from', () {
      RoadmapStep door(SessionState s) => seasonRoadmap(
        s,
        l,
      ).firstWhere((step) => step.route == Routes.dashboard);

      for (final code in [
        PermissionCodes.employeesView,
        PermissionCodes.approvalsView,
        PermissionCodes.modulesViewAll,
        PermissionCodes.modulesMembers,
      ]) {
        expect(
          door(_holding({code})).open,
          isTrue,
          reason: 'the dashboard refused $code, which owns a section of it',
        );
      }

      expect(
        door(_holding({PermissionCodes.auditView})).open,
        isFalse,
        reason: 'the dashboard opened for a permission that owns none of it',
      );
    });

    test('the whole season is drawn, whoever is reading', () {
      // Nothing is filtered out — a map with the other man's half torn out is
      // not a map. The length has to be identical for a brand-new member and
      // for the person who runs the Administration.
      final everyone = seasonRoadmap(_holding({}), l);
      final admin = seasonRoadmap(_admin, l);

      expect(everyone.length, admin.length);
      expect(
        everyone.map((s) => s.route).toList(),
        admin.map((s) => s.route).toList(),
        reason:
            'the map changed shape with the reader; it must only change '
            'which of its steps are unlocked',
      );
    });

    test('every phase has steps, in the order the year runs', () {
      for (final (description, session) in sessions()) {
        final phases = roadmapPhases(seasonRoadmap(session, l));
        expect(phases.map((p) => p.phase).toList(), RoadmapPhase.values);
        for (final entry in phases) {
          expect(
            entry.steps,
            isNotEmpty,
            reason: '${entry.phase.name} came out empty for $description',
          );
        }
      }
    });

    test('an admin holds the whole map', () {
      final steps = seasonRoadmap(_admin, l);
      expect(
        steps.where((s) => s.open).length,
        steps.length,
        reason: 'a step was locked against somebody who may open everything',
      );
    });

    test('a member holds only what belongs to everyone', () {
      // Six steps of التشغيل plus filling in the evaluations he was asked for.
      // If this number moves, either a section was quietly opened to the whole
      // mission or a step that belongs to everybody was quietly shut.
      final steps = seasonRoadmap(_holding({}), l);
      final open = steps.where((s) => s.open).map((s) => s.route).toList();

      expect(open, [
        Routes.modules,
        Routes.tasks,
        Routes.myCheckIns,
        Routes.raiseIncident,
        Routes.reports,
        Routes.complaints,
        Routes.evaluations,
      ]);
    });

    test('every step names a route the app actually has', () {
      // The constants are checked by the compiler; what is not is whether the
      // map has quietly grown a step pointing somewhere nobody meant it to.
      for (final step in seasonRoadmap(_admin, l)) {
        expect(
          _knownRoutes.contains(step.route),
          isTrue,
          reason:
              '"${step.title}" points at ${step.route}, which is not one '
              'of the screens this map is meant to reach',
        );
      }
    });
  });
}

/// Every path the roadmap is allowed to point at, written out so that a step
/// aimed at a screen this app does not have fails here.
const _knownRoutes = {
  Routes.seasons,
  Routes.referenceData,
  Routes.approvals,
  Routes.employees,
  Routes.permissions,
  Routes.modulesManage,
  Routes.tasksManage,
  Routes.evaluationForms,
  Routes.reportsManage,
  Routes.modules,
  Routes.tasks,
  Routes.myCheckIns,
  Routes.raiseIncident,
  Routes.reports,
  Routes.complaints,
  Routes.dashboard,
  Routes.seasonMap,
  Routes.presence,
  Routes.incidents,
  Routes.complaintsManage,
  Routes.auditLog,
  Routes.evaluations,
  Routes.export,
};
