import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/constants/permission_codes.dart';
import 'package:sdhu_operations_project/features/auth/application/session_cubit.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile_enums.dart';

/// Which season the Administration is working through, and who takes part in
/// it, is the Administration's to set. The dashboard showed that section to
/// every approved user — the one card in the list with no permission on it —
/// and the route had no opinion at all.
///
/// Both now ask [SessionState.canSeeSeasons], so this is the single place the
/// rule can be got wrong.
void main() {
  SessionState session({Set<String> permissions = const {}, bool admin = false}) {
    return SessionState(
      status: SessionStatus.approved,
      profile: Profile(
        id: 'p1',
        isAdmin: admin,
        accountStatus: AccountStatus.approved,
      ),
      permissions: permissions,
    );
  }

  test('an ordinary member does not see seasons', () {
    expect(session().canSeeSeasons, isFalse);
  });

  test('holding an unrelated permission is not enough', () {
    expect(
      session(permissions: {PermissionCodes.employeesView}).canSeeSeasons,
      isFalse,
    );
  });

  test('seasons.view is the door', () {
    // Every other seasons action requires seasons.view as a prerequisite —
    // the DB refuses a grant without it (0073) — so the door only ever needs
    // to ask for the one code.
    expect(
      session(permissions: {PermissionCodes.seasonsView}).canSeeSeasons,
      isTrue,
    );
  });

  test('an admin sees everything, as everywhere else', () {
    expect(session(admin: true).canSeeSeasons, isTrue);
  });
}
