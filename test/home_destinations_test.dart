import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/constants/permission_codes.dart';
import 'package:sdhu_operations_project/core/router/app_router.dart';
import 'package:sdhu_operations_project/features/auth/application/session_cubit.dart';
import 'package:sdhu_operations_project/features/home/domain/home_destinations.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile_enums.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

/// The home page now has two arrangements — the grid of tiles and the standing
/// rail — and both read this one list. Which makes the list the single place
/// where a door can be shown to somebody who may not walk through it, and this
/// the test that says it cannot.
///
/// The property is one sentence: **a door that is drawn is a door that opens.**
/// Anything here whose route is guarded must be guarded by a rule this very
/// session passes. A tile that survives the filter but bounces at the route is
/// the app telling a man he has authority he does not have.
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
    // The Arabic table, because it is the one the mission reads and the one
    // with no empty strings in it.
    l = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  /// Every session worth asking the question of: nobody, everybody, and each
  /// permission held entirely on its own.
  ///
  /// One at a time is the case that matters. Holding a whole realistic bundle
  /// hides the mistake this file exists to catch — a door drawn on one code and
  /// guarded by another passes every test where the reader happens to hold
  /// both, and fails in the hands of the one man who holds only the first.
  ///
  /// Written out rather than derived, like the owners table in
  /// `section_guards_test.dart`: a list generated from the same constants the
  /// code reads would grow a new code silently, which is exactly the edit
  /// somebody should have to make on purpose.
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

  group('homeDestinations', () {
    test('never draws a door the route would refuse', () {
      for (final (description, session) in sessions()) {
        for (final destination in homeDestinations(session, l)) {
          final guard = sectionGuards[destination.route];
          if (guard == null) continue;
          expect(
            guard(session),
            isTrue,
            reason:
                '${destination.route} was offered to $description, and the '
                'router would have sent them straight back home',
          );
        }
      }
    });

    test('a compose action never opens a door its own route would not', () {
      // The `?compose=1` shortcuts write something rather than merely opening
      // it, so they are the likelier place for a permission to be forgotten.
      // Each one has to land on the same path its card does.
      for (final (description, session) in sessions()) {
        for (final destination in homeDestinations(session, l)) {
          final action = destination.action;
          if (action == null) continue;
          expect(
            action.split('?').first,
            destination.route,
            reason:
                'the action on ${destination.title} left its own route, for '
                '$description',
          );
        }
      }
    });

    test('somebody holding nothing still gets their own work', () {
      // العام is not a set of grants. A file reaches its members by assignment,
      // an evaluation reaches its evaluator by name, and a task list is owned
      // by existing — so a brand-new approved account with no permission at all
      // must still land on a page with doors on it.
      final doors = homeDestinations(_holding({}), l);

      expect(
        doors.every((d) => d.group == HomeGroup.general),
        isTrue,
        reason: 'an administered section leaked to somebody holding nothing',
      );
      expect(
        doors.map((d) => d.route).toSet(),
        {
          Routes.modules,
          Routes.reports,
          Routes.evaluations,
          Routes.tasks,
          Routes.complaints,
          Routes.myCheckIns,
          Routes.myIncidents,
          // Where he is being sent, and when he comes home (0129). On the same
          // shelf and for the same reason as the rest of العام: it reaches him
          // by being about him, not by a grant.
          Routes.myJourney,
        },
        reason:
            'the doors that belong to everyone changed — which is either a '
            'section that was quietly opened, or one that was quietly closed',
      );
    });

    test('an admin is handed every shelf there is', () {
      final shelves = homeShelves(homeDestinations(_admin, l));

      expect(
        shelves.map((s) => s.group).toSet(),
        HomeGroup.values.toSet(),
        reason: 'a shelf came out empty for somebody who may open everything',
      );
      // The enum's own order, not the order the doors happen to be declared in
      // — the grid draws its shelves by walking it, and so does the rail.
      expect(shelves.map((s) => s.group).toList(), HomeGroup.values);
    });

    test('العام is always first, whatever else the reader holds', () {
      // A person is two things at once on this page — somebody with work and
      // somebody with authority — and the work comes first for everybody,
      // including the man who runs the Administration.
      for (final (description, session) in sessions()) {
        final shelves = homeShelves(homeDestinations(session, l));
        expect(
          shelves.first.group,
          HomeGroup.general,
          reason: 'الإدارة came before العام for $description',
        );
      }
    });

    test('no shelf comes back empty', () {
      // A heading with nothing under it is worse than a missing heading: it
      // tells a reader there is a section here that he cannot see into.
      for (final (description, session) in sessions()) {
        for (final shelf in homeShelves(homeDestinations(session, l))) {
          expect(
            shelf.destinations,
            isNotEmpty,
            reason: '${shelf.group.name} was drawn empty for $description',
          );
        }
      }
    });

    test('two doors never share a route', () {
      // Two entries onto one screen is what the evaluations register was once
      // drawn as, and what it looked like was a section with no way out
      // standing beside an orphan. It is back on this list now — on the
      // oversight shelf, once — and `/evaluations/manage` must stay the only
      // route that reaches it.
      for (final (description, session) in sessions()) {
        final routes = homeDestinations(
          session,
          l,
        ).map((d) => d.route).toList();
        expect(
          routes.length,
          routes.toSet().length,
          reason: 'the same route was offered twice to $description',
        );
      }
    });
  });
}
