import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/modules/domain/module_type.dart';

/// فريق الكوسترات is one team, not three headings.
///
/// The roles a type holds on the FILE — the ones with no `level_id` — were a
/// flat list, and both screens drew a card per role. On تشكيل فرق المشاعر that
/// came out as four headings for two teams: the manager, his deputy and the
/// members are one team with three posts in it, and the page said they were
/// three separate groups of people who happen to have similar names.
///
/// The grouping is DECLARED (0115), never worked out. The codes do share a
/// prefix — `coasters_manager`, `coasters_deputy`, `coasters_member` — and
/// grouping on it would work today and be wrong the first time somebody adds a
/// role that merely starts the same way.
///
/// Two things matter as much as the grouping itself: a role that names no team
/// must come out exactly as it did before, because ten of the fifteen types
/// have none; and a role must never be dropped, whatever its `team_id` says.
void main() {
  LocalizedName n(String s) => LocalizedName(ar: s, en: s);

  ModuleTeam team(String code) =>
      ModuleTeam(id: 'team-$code', code: code, name: n('فريق $code'));

  ModuleRole role(String code, {String? teamId, String? levelId}) => ModuleRole(
    id: 'role-$code',
    code: code,
    name: n(code),
    teamId: teamId,
    levelId: levelId,
  );

  ModuleType typeOf({
    List<ModuleRole> roles = const [],
    List<ModuleTeam> teams = const [],
  }) => ModuleType(
    id: 't',
    code: 'c',
    name: n('t'),
    roles: roles,
    teams: teams,
  );

  group('a type that declares no teams', () {
    test('is one group per post, in the order it declared them', () {
      // الطوافة والنقل and the nine others like it. Whatever this does, it
      // must not change what those files look like.
      final groups = typeOf(
        roles: [role('supervisor'), role('member')],
      ).roleGroups;

      expect(groups, hasLength(2));
      expect(groups[0].roles.single.code, 'supervisor');
      expect(groups[1].roles.single.code, 'member');
      expect(groups[0].team, isNull);
    });

    test('a group of one is named by its post and names nothing inside', () {
      final group = typeOf(roles: [role('supervisor')]).roleGroups.single;

      expect(group.name.ar, 'supervisor');
      expect(group.id, 'role-supervisor');
      // Repeating the heading on every tile beneath it says the same word
      // twenty times.
      expect(group.namesItsPosts, isFalse);
    });
  });

  group('تشكيل فرق المشاعر — four posts, two teams', () {
    final coasters = team('coasters');
    final catering = team('catering');

    ModuleType mashaaer() => typeOf(
      teams: [coasters, catering],
      roles: [
        role('coasters_manager', teamId: coasters.id),
        role('coasters_deputy', teamId: coasters.id),
        role('coasters_member', teamId: coasters.id),
        role('catering_monitor', teamId: catering.id),
      ],
    );

    test('comes out as two cards, not four', () {
      final groups = mashaaer().roleGroups;

      expect(groups, hasLength(2));
      expect(groups[0].team?.code, 'coasters');
      expect(groups[1].team?.code, 'catering');
    });

    test('the three posts are inside the one team, in their own order', () {
      final coastersGroup = mashaaer().roleGroups.first;

      expect(coastersGroup.roles.map((r) => r.code), [
        'coasters_manager',
        'coasters_deputy',
        'coasters_member',
      ]);
      expect(coastersGroup.name.ar, 'فريق coasters');
      // With three posts under one heading, each man's tile has to say which
      // post he is here under.
      expect(coastersGroup.namesItsPosts, isTrue);
    });

    test('a team of one post still reads as the team', () {
      // «فريق مراقبة إعاشة المشاعر» is the group; «عضو فريق مراقبة إعاشة
      // المشاعر» is the post. The card is the team.
      final cateringGroup = mashaaer().roleGroups[1];

      expect(cateringGroup.team?.code, 'catering');
      expect(cateringGroup.name.ar, 'فريق catering');
      expect(cateringGroup.namesItsPosts, isFalse);
    });

    test('folding is keyed by the team, not by a post inside it', () {
      // Otherwise closing a team would be remembered against whichever post
      // happened to be first, and reordering the roles would silently reopen
      // every group the reader had shut.
      expect(mashaaer().roleGroups.first.id, 'team-coasters');
    });
  });

  group('order and stragglers', () {
    test('a team takes the place of its FIRST post', () {
      final coasters = team('coasters');
      final groups = typeOf(
        teams: [coasters],
        roles: [
          role('alone_first'),
          role('coasters_manager', teamId: coasters.id),
          role('coasters_member', teamId: coasters.id),
          role('alone_last'),
        ],
      ).roleGroups;

      expect(groups.map((g) => g.name.ar), [
        'alone_first',
        'فريق coasters',
        'alone_last',
      ]);
    });

    test('posts of a team scattered among others still gather', () {
      // The type may declare them out of order, and the card must not appear
      // twice for one team.
      final coasters = team('coasters');
      final groups = typeOf(
        teams: [coasters],
        roles: [
          role('coasters_manager', teamId: coasters.id),
          role('someone_else'),
          role('coasters_member', teamId: coasters.id),
        ],
      ).roleGroups;

      expect(groups, hasLength(2));
      expect(groups.first.roles.map((r) => r.code), [
        'coasters_manager',
        'coasters_member',
      ]);
    });

    test('a post naming a team the type does not declare is not lost', () {
      // Whatever the data says, a post must reach the page: a role that
      // vanishes is a post nobody knows is unfilled.
      final groups = typeOf(
        roles: [role('orphan', teamId: 'team-that-went-away')],
      ).roleGroups;

      expect(groups, hasLength(1));
      expect(groups.single.team, isNull);
      expect(groups.single.roles.single.code, 'orphan');
    });
  });

  group('read off the database', () {
    test('teams and the post that names one are parsed', () {
      final type = ModuleType.fromMap({
        'id': 't',
        'code': 'mashaaer_teams',
        'name_ar': 'تشكيل فرق المشاعر',
        'module_type_teams': [
          {'id': 'tm-1', 'code': 'coasters', 'name_ar': 'فريق الكوسترات'},
        ],
        'module_type_roles': [
          {
            'id': 'r-1',
            'code': 'coasters_manager',
            'name_ar': 'مدير فريق الكوسترات',
            'team_id': 'tm-1',
            'sort_order': 1,
          },
          {
            'id': 'r-2',
            'code': 'coasters_member',
            'name_ar': 'عضو فريق الكوسترات',
            'team_id': 'tm-1',
            'sort_order': 2,
          },
        ],
      });

      expect(type.teams.single.code, 'coasters');
      expect(type.roleGroups.single.name.ar, 'فريق الكوسترات');
      expect(type.roleGroups.single.roles, hasLength(2));
    });

    test('a database without 0115 groups nothing, and loses nothing', () {
      // The embed is absent rather than empty there, and every post keeps the
      // card it has always had.
      final type = ModuleType.fromMap({
        'id': 't',
        'code': 'makkah_tawafa_transport',
        'name_ar': 'الطوافة والنقل',
        'module_type_roles': [
          {'id': 'r-1', 'code': 'a', 'name_ar': 'أ', 'sort_order': 1},
          {'id': 'r-2', 'code': 'b', 'name_ar': 'ب', 'sort_order': 2},
        ],
      });

      expect(type.teams, isEmpty);
      expect(type.roleGroups, hasLength(2));
      expect(type.roleGroups.every((g) => g.team == null), isTrue);
    });

    test('a role held at a level is grouped by its node, never by a team', () {
      // `roles` is the file's own only. A sector supervisor belongs under his
      // sector, and pulling him into a team card would take him out of it.
      final type = ModuleType.fromMap({
        'id': 't',
        'code': 'mina_camp_assignment',
        'name_ar': 'مخيمات منى',
        'module_type_levels': [
          {'id': 'lv-1', 'code': 'center', 'name_ar': 'المركز', 'depth': 1},
        ],
        'module_type_teams': [
          {'id': 'tm-1', 'code': 'coasters', 'name_ar': 'فريق الكوسترات'},
        ],
        'module_type_roles': [
          {
            'id': 'r-1',
            'code': 'center_supervisor',
            'name_ar': 'مشرف المركز',
            'level_id': 'lv-1',
            // Set, and it must still be ignored: the level decides.
            'team_id': 'tm-1',
            'sort_order': 1,
          },
          {
            'id': 'r-2',
            'code': 'coasters_member',
            'name_ar': 'عضو فريق الكوسترات',
            'team_id': 'tm-1',
            'sort_order': 2,
          },
        ],
      });

      expect(type.roleGroups, hasLength(1));
      expect(type.roleGroups.single.roles.single.code, 'coasters_member');
      expect(type.levels.single.roles.single.code, 'center_supervisor');
    });
  });
}
