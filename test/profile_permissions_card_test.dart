import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/auth/application/session_cubit.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile_enums.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

/// The card on a man's own profile that says what he is allowed to do.
///
/// Two of its three states are the ones a naive version gets wrong, and both
/// are tested through [SessionState] rather than through the widget: the rule
/// being checked is about what the session MEANS, and the widget only draws it.
void main() {
  Profile profile({bool isAdmin = false}) => Profile(
    id: 'p1',
    accountStatus: AccountStatus.approved,
    isAdmin: isAdmin,
  );

  test('an admin holds everything and carries nothing', () {
    // The one account that can do anything has an EMPTY permission set: the
    // session short-circuits on isAdmin and never loads the rows. A card that
    // printed the set would tell the most powerful user in the system that he
    // has no permissions — which is why the card asks isAdmin first.
    const state = SessionState(status: SessionStatus.approved, permissions: {});
    final admin = state.copyWith(profile: profile(isAdmin: true));

    expect(admin.permissions, isEmpty);
    expect(admin.isAdmin, isTrue);
    expect(admin.can('permissions.manage'), isTrue);
  });

  test('holding nothing is the ordinary case, not a fault', () {
    final ordinary = const SessionState(
      status: SessionStatus.approved,
    ).copyWith(profile: profile());

    expect(ordinary.isAdmin, isFalse);
    expect(ordinary.permissions, isEmpty);
    // And he still has work: a file reaches its members by assignment, which
    // is the sentence the empty card prints.
    expect(ordinary.can('modules.manage'), isFalse);
  });

  test('a code groups under the section it belongs to', () {
    const state = SessionState(
      status: SessionStatus.approved,
      permissions: {
        'employees',
        'employees.view',
        'employees.create',
        'approvals',
        'approvals.decide',
        // A section granted with no action under it is itself a grant — it is
        // what opens the screen — and must not be dropped for having no
        // children.
        'notifications',
      },
    );

    final grouped = <String, List<String>>{};
    for (final code in state.permissions) {
      final parts = code.split('.');
      grouped.putIfAbsent(parts.first, () => <String>[]);
      if (parts.length > 1) grouped[parts.first]!.add(code);
    }

    expect(grouped.keys.toSet(), {'employees', 'approvals', 'notifications'});
    expect(grouped['employees']!.toSet(), {
      'employees.view',
      'employees.create',
    });
    expect(grouped['notifications'], isEmpty);
  });

  testWidgets('the profile is reachable in both languages', (tester) async {
    // The card's three strings exist in both ARBs; a missing one is a build
    // error at gen-l10n, but a missing PLURAL is only a runtime one.
    for (final locale in [const Locale('ar'), const Locale('en')]) {
      final l = await AppLocalizations.delegate.load(locale);
      expect(l.profileSectionPermissions, isNotEmpty);
      expect(l.profilePermissionsAdmin, isNotEmpty);
      expect(l.profilePermissionsNone, isNotEmpty);
      expect(l.profilePermissionsNoneHint, isNotEmpty);
      for (final n in [1, 2, 3, 11]) {
        expect(l.profilePermissionsCount(n), contains(RegExp(r'\S')));
      }
    }
  });
}
