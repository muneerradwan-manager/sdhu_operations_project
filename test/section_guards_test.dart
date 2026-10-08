import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/constants/permission_codes.dart';
import 'package:sdhu_operations_project/core/router/app_router.dart';
import 'package:sdhu_operations_project/features/auth/application/session_cubit.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile_enums.dart';

/// The sections of الإدارة are hidden from whoever does not hold them, and this
/// is what makes that a rule rather than a decoration: the route refuses too.
///
/// A hidden card and an open route look identical while you are testing as an
/// admin. The difference shows up as a link somebody was sent, or a location
/// restored from the last run, opening a page that person was never meant to
/// reach.
SessionState _holding(Set<String> permissions) =>
    SessionState(status: SessionStatus.approved, permissions: permissions);

void main() {
  group('sectionGuards', () {
    test('every administered section refuses somebody holding nothing', () {
      final open = SessionState(status: SessionStatus.approved);
      for (final entry in sectionGuards.entries) {
        expect(
          entry.value(open),
          isFalse,
          reason: '${entry.key} let in a user with no permissions',
        );
      }
    });

    test('each section is opened by its own permission and no other', () {
      // The pairs the home screen draws its cards by, written out again so
      // that changing one without the other fails here rather than in the
      // hands of somebody who should not have seen the page.
      const owners = {
        '/seasons': PermissionCodes.seasonsView,
        '/modules/manage': PermissionCodes.modulesViewAll,
        '/reports/manage': PermissionCodes.reportsViewAll,
        '/employees': PermissionCodes.employeesView,
        '/approvals': PermissionCodes.approvalsView,
        '/permissions': PermissionCodes.permissionsView,
        '/reference-data': PermissionCodes.referenceView,
        '/audit-log': PermissionCodes.auditView,
        '/complaints/manage': PermissionCodes.complaintsView,
        '/evaluations/manage': PermissionCodes.evaluationsView,
      };

      owners.forEach((route, code) {
        final guard = sectionGuards[route];
        expect(guard, isNotNull, reason: '$route has no guard at all');

        expect(
          guard!(_holding({code})),
          isTrue,
          reason: '$route refused the permission that owns it',
        );

        // Holding every OTHER permission is not enough. This is the half that
        // catches a guard copy-pasted from the line above it and left asking
        // for the wrong code — which passes a "the right person gets in" test
        // and lets the whole mission in.
        final others = owners.values.where((c) => c != code).toSet();
        expect(
          guard(_holding(others)),
          isFalse,
          reason: '$route opened for a permission that does not own it',
        );
      });
    });

    test('إدارة التقييم opens for either of its two codes', () {
      // The one door in the table that takes two, and deliberately. It is where
      // a form is written AND where an evaluation is opened on one — the
      // register issues nothing — so closing it to `evaluations.assign` would
      // leave that permission with no way to be exercised at all.
      //
      // Which is exactly why it cannot sit in the one-owner map above, and why
      // it needs this test instead: the half that matters is still that
      // everything ELSE is refused.
      final guard = sectionGuards['/evaluations/forms']!;

      for (final code in [
        PermissionCodes.evaluationsTemplates,
        PermissionCodes.evaluationsAssign,
      ]) {
        expect(
          guard(_holding({code})),
          isTrue,
          reason: '/evaluations/forms refused $code',
        );
      }

      // Reading the register is not writing the paper and not issuing the
      // errand. Holding view alone — which both of the two above require as a
      // prerequisite, so it is the likeliest thing to be held on its own —
      // opens nothing here.
      expect(
        guard(_holding({
          PermissionCodes.evaluationsView,
          PermissionCodes.evaluationsDelete,
          PermissionCodes.complaintsView,
          PermissionCodes.employeesView,
        })),
        isFalse,
        reason: '/evaluations/forms opened for a permission that does not own it',
      );
    });

    test('the seasons door opens for seasons.view alone', () {
      // Every other seasons action names seasons.view as a prerequisite and
      // the DB refuses a grant without it (0073), so the guard needs only the
      // one code.
      final guard = sectionGuards['/seasons']!;
      expect(
        guard(_holding({PermissionCodes.seasonsView})),
        isTrue,
        reason: 'seasons.view was refused',
      );
    });

    test('an admin is admitted everywhere without holding a single code', () {
      // Admin is a property of the profile, not a row in the permission table,
      // and every guard has to go through `can` for that to hold.
      final admin = SessionState(
        status: SessionStatus.approved,
        profile: const Profile(
          id: 'admin',
          accountStatus: AccountStatus.approved,
          isAdmin: true,
        ),
      );
      for (final entry in sectionGuards.entries) {
        expect(
          entry.value(admin),
          isTrue,
          reason: '${entry.key} refused an admin',
        );
      }
    });

    test('the guarded set is exactly what we mean to guard', () {
      // Written out so that dropping a guard is an edit somebody has to make
      // on purpose, in two places, rather than a line quietly deleted.
      expect(sectionGuards.keys.toSet(), {
        '/seasons',
        '/modules/manage',
        '/reports/manage',
        '/employees',
        '/approvals',
        '/permissions',
        '/reference-data',
        '/audit-log',
        '/complaints/manage',
        '/evaluations/manage',
        '/evaluations/forms',
        // The operations room's register of urgent reports. RAISING one is
        // `/incident` and is deliberately NOT here — see the open list below.
        '/incidents',
        // Who is present, across the season. FILING your own arrival is
        // `/check-in` and is deliberately not here, for the same reason.
        '/presence',
        // Both were open until 0100. The export is the one that matters:
        // `export.data` widens the row policies themselves, so that door now
        // leads somewhere its holder could not otherwise go.
        '/export',
        '/map',
        // Writing tasks onto OTHER people's lists (0105). A person's own list
        // is `/tasks` and is deliberately not here — see the open list below.
        '/tasks/manage',
        // The season's flights and who is on them (0129). A man's own route
        // home is `/my-journey` and is deliberately not here, for the same
        // reason `/tasks` is not: reading where you yourself are being sent is
        // not a privilege anybody grants.
        '/travel',
      });
    });

    test('what everyone may reach is not guarded', () {
      // /modules is a person's own assigned work and /reports is what the
      // whole mission reads — guarding either would lock ordinary members out
      // of their own files. /dashboard answers for itself section by section
      // on the server, so anyone holding any part of it may open it.
      // /complaints is a person's own: filing one is not a permission and
      // neither is reading what you filed. Closing it would mean an ordinary
      // member could complain and then never see the answer.
      // /evaluations is the same shape for the same reason: an evaluation
      // reaches its evaluator by NAME, so there is no permission to fill one
      // and nothing to guard the list of your own errands with. Closing it
      // would mean somebody could be assigned work they could not open.
      // /incident is raising one, and it is the most important entry on this
      // list: a system in which only certain people may report that a bus has
      // broken down is a system that does not find out about the bus. Reading
      // everyone's is `/incidents`, and that one IS guarded.
      // /check-in is the same argument said about presence: a system in which
      // only certain people may report where they are is a system that does not
      // know where anybody is. What stands in the way there is physical — the
      // code on the wall and the phone's own position (0098) — and a grant on
      // top of that would only stop the honest. Reading everyone's is
      // `/presence`, and that one IS guarded.
      // /tasks is a person's own list, and owning one is not a permission
      // somebody grants: everybody has one by existing, and what was assigned
      // to them arrived by NAME. Writing onto other people's lists is
      // `/tasks/manage`, and that one IS guarded.
      // /my-journey is where a man is being sent and when he comes home. RLS
      // says the same thing in 0129 — his own legs are readable by him with no
      // code held — and a record of a man's own travel that he cannot open is
      // not a record worth keeping. The season's whole board is `/travel`, and
      // that one IS guarded.
      for (final open in [
        '/modules',
        '/reports',
        '/dashboard',
        '/complaints',
        '/evaluations',
        '/incident',
        '/check-in',
        '/tasks',
        '/my-journey',
        '/',
      ]) {
        expect(
          sectionGuards.containsKey(open),
          isFalse,
          reason: '$open was closed, and it belongs to everyone',
        );
      }
    });

    test('a guard matches its own path only, never by prefix', () {
      // An employee's page is opened from inside an operational file, by people
      // who run files and may not keep the directory. It is pushed rather than
      // routed for that reason, and nothing here may reach past /employees to
      // close it.
      expect(sectionGuards.containsKey('/employees/some-id'), isFalse);
      expect(sectionGuards.containsKey('/modules/some-id'), isFalse);
    });
  });
}
