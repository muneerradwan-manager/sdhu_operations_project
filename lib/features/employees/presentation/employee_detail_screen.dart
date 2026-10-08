import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/enum_labels.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/l10n/permission_labels.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../../../core/widgets/overflow_menu.dart';
import '../../../core/widgets/profile_hero.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/application/session_cubit.dart';
import '../../complaints/presentation/widgets/complaints_against_section.dart';
import '../../evaluations/domain/evaluation.dart';
import '../../evaluations/presentation/widgets/evaluations_about_section.dart';
import '../../modules/data/modules_repository.dart';
import '../../permissions/data/permissions_repository.dart';
import '../../permissions/domain/permission.dart';
import '../../permissions/presentation/permission_editor_screen.dart';
import '../../modules/domain/operational_module.dart';
import '../../modules/presentation/module_detail_screen.dart';
import '../../profile/domain/profile.dart';
import '../../seasons/data/seasons_repository.dart';
import '../../travel/presentation/widgets/travel_section.dart';
import '../../notifications/presentation/send_notification_sheet.dart';
import '../application/employee_manage_cubit.dart';
import '../data/employees_repository.dart';
import 'widgets/employee_edit_sheet.dart';
import 'widgets/employee_email_sheet.dart';
import 'widgets/employee_password_sheet.dart';
import 'widgets/external_edit_sheet.dart';

class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({super.key, required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EmployeeManageCubit(
        EmployeesRepository(),
        SeasonsRepository(),
        profile,
      ),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  /// Ask before removing someone, and say plainly what goes with them.
  ///
  /// The confirmation names the person: a delete button on a screen you reached
  /// by tapping a row is exactly where the wrong row gets deleted.
  Future<void> _confirmDelete(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<EmployeeManageCubit>();
    final profile = cubit.state.profile;

    // An admin is refused by the function too; saying so here saves a round
    // trip and explains what to do instead.
    if (profile.isAdmin) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.employeeDeleteAdminBlocked)));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.employeeDeleteConfirmTitle),
        content: Text(l.employeeDeleteConfirmBody(profile.fullName)),
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
            child: Text(l.employeeDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final gone = await cubit.deleteEmployee();
    if (!gone) return; // the cubit already surfaced the error
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.employeeDeleted)));
    // Nothing is left to show on this screen.
    if (navigator.canPop()) navigator.pop();
  }

  /// Open the password sheet, unless this is an administrator's account and the
  /// viewer is not one.
  ///
  /// The function refuses that combination too; saying so here saves a round
  /// trip and, more to the point, saves the reader from typing a password that
  /// was never going to be set.
  void _changePassword(BuildContext context, {required bool viewerIsAdmin}) {
    final cubit = context.read<EmployeeManageCubit>();
    final profile = cubit.state.profile;

    if (profile.isAdmin && !viewerIsAdmin) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.employeePasswordAdminBlocked)),
        );
      return;
    }
    showEmployeePasswordSheet(context, cubit, profile);
  }

  /// Open the email sheet, with the same admin guard as the password: the
  /// address is the login, and an administrator's login moves only under an
  /// administrator's hand.
  void _changeEmail(BuildContext context, {required bool viewerIsAdmin}) {
    final cubit = context.read<EmployeeManageCubit>();
    final profile = cubit.state.profile;

    if (profile.isAdmin && !viewerIsAdmin) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.employeeEmailAdminBlocked)),
        );
      return;
    }
    showEmployeeEmailSheet(context, cubit, profile);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.watch<SessionCubit>().state;
    final canSuspend = session.can(PermissionCodes.employeesSuspend);
    final canExternal = session.can(PermissionCodes.employeesExternal);
    final canEdit = session.can(PermissionCodes.employeesEdit);
    final canDelete = session.can(PermissionCodes.employeesDelete);
    final canSetPassword = session.can(PermissionCodes.employeesPassword);
    final canSetEmail = session.can(PermissionCodes.employeesEmail);
    final canSeePermissions = session.can(PermissionCodes.permissionsView);
    final canManagePermissions = session.can(PermissionCodes.permissionsManage);
    final canSeeParticipation = session.can(
      PermissionCodes.seasonsParticipantsView,
    );
    final canManageParticipants = session.can(
      PermissionCodes.seasonsParticipantsManage,
    );
    final canNotify = session.can(PermissionCodes.notificationsSend);
    final canSeeModules =
        session.can(PermissionCodes.modulesViewAll) ||
        session.can(PermissionCodes.modulesMembers);
    final canSeeComplaints = session.can(PermissionCodes.complaintsView);
    final canSeeEvaluations = session.can(PermissionCodes.evaluationsView);
    final canSeeTravel = session.can(PermissionCodes.travelView);
    final showManagement = canSuspend || canExternal || canManageParticipants;

    return Scaffold(
      appBar: GlassAppBar(
        title: Text(l.employeeDetailTitle),
        actions: [
          // Editing and deleting behind one overflow. Sending a notification
          // is not an act on this RECORD, so it is not in here with them — it
          // is a button in the page, beside the person it writes to.
          OverflowMenu(
            actions: [
              if (canEdit)
                MenuAction(
                  icon: AppIcons.edit,
                  label: l.employeeEdit,
                  onSelected: () {
                    final cubit = context.read<EmployeeManageCubit>();
                    showEmployeeEditSheet(context, cubit, cubit.state.profile);
                  },
                ),
              if (canSetPassword)
                MenuAction(
                  icon: AppIcons.password,
                  label: l.employeePassword,
                  onSelected: () =>
                      _changePassword(context, viewerIsAdmin: session.isAdmin),
                ),
              if (canSetEmail)
                MenuAction(
                  icon: AppIcons.email,
                  label: l.employeeEmail,
                  onSelected: () =>
                      _changeEmail(context, viewerIsAdmin: session.isAdmin),
                ),
              if (canDelete)
                MenuAction(
                  icon: AppIcons.delete,
                  label: l.employeeDelete,
                  isDestructive: true,
                  onSelected: () => _confirmDelete(context),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<EmployeeManageCubit, EmployeeManageState>(
          listenWhen: (p, c) => c.error != null && p.error != c.error,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(friendlyError(context, state.error))),
              );
          },
          builder: (context, state) {
            final p = state.profile;

            // Who this is, and — for whoever is allowed to change it — the
            // switches that decide what they are. Both belong to the person
            // rather than to any one section below, so on a wide window they
            // stand together in the panel while the record scrolls past.
            final identity = <Widget>[
              ProfileHero(
                name: p.fullName,
                photoUrl: p.photoUrl,
                roleLabel: p.jobTitleName?.of(context),
                badges: [
                  if (p.isAdmin)
                    GlassBadge(
                      label: l.profileBadgeAdmin,
                      color: Theme.of(context).colorScheme.secondary,
                      icon: AppIcons.shield,
                    ),
                  if (p.isExternal)
                    GlassBadge(
                      label: l.profileBadgeExternal,
                      color: Theme.of(context).colorScheme.tertiary,
                      icon: AppIcons.external,
                    ),
                  if (p.isSuspended)
                    GlassBadge(
                      label: l.statusSuspendedTitle,
                      color: Theme.of(context).colorScheme.error,
                      icon: AppIcons.suspend,
                    ),
                ],
              ),
              // Writing to this person is a thing you DO with the page open,
              // not an action on their record — so it stands in the page under
              // their name, where the reader is already looking, rather than as
              // a glyph in the bar.
              if (canNotify) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      showSendNotificationSheet(context, recipientId: p.id),
                  icon: const Icon(AppIcons.send),
                  label: Text(l.employeeNotify),
                ),
              ],
              if (showManagement) ...[
                const SizedBox(height: AppSpacing.lg),
                _ManagementCard(
                  state: state,
                  canSuspend: canSuspend,
                  canExternal: canExternal,
                  canManageParticipants: canManageParticipants,
                ),
              ],
            ];

            final details = <Widget>[
              InfoSection(
                title: l.profileSectionPersonal,
                icon: AppIcons.firstName,
                children: [
                  InfoRow(
                    icon: AppIcons.firstName,
                    label: l.profileFirstName,
                    value: p.firstName,
                  ),
                  InfoRow(
                    icon: AppIcons.fatherName,
                    label: l.profileFatherName,
                    value: p.fatherName,
                  ),
                  InfoRow(
                    icon: AppIcons.surname,
                    label: l.profileSurname,
                    value: p.surname,
                  ),
                  InfoRow(
                    icon: AppIcons.location,
                    label: l.profileCity,
                    value: p.cityName?.of(context),
                  ),
                  InfoRow(
                    icon: AppIcons.gender,
                    label: l.profileGender,
                    value: p.gender?.label(l),
                  ),
                  InfoRow(
                    icon: AppIcons.mission,
                    label: l.profileMissionType,
                    value: p.missionTypeName?.of(context),
                  ),
                  InfoRow(
                    icon: AppIcons.dateOfBirth,
                    label: l.profileDateOfBirth,
                    value: formatDate(p.dateOfBirth),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              InfoSection(
                title: l.profileSectionContact,
                icon: AppIcons.phoneSy,
                children: [
                  InfoRow(
                    icon: AppIcons.phoneSy,
                    label: l.profilePhoneSy,
                    value: p.phoneSy,
                    action: InfoAction.call,
                  ),
                  InfoRow(
                    icon: AppIcons.phoneSa,
                    label: l.profilePhoneSa,
                    value: p.phoneSa,
                    action: InfoAction.call,
                  ),
                  InfoRow(
                    icon: AppIcons.email,
                    label: l.profileEmail,
                    value: p.email,
                    action: InfoAction.email,
                  ),
                ],
              ),
              // Reading another employee's participation rows is its own
              // permission now, so gate on it rather than render an empty
              // list the viewer cannot see into.
              if (canSeeParticipation) ...[
                const SizedBox(height: AppSpacing.lg),
                _SeasonHistorySection(state: state),
              ],
              // Shown to anyone who got this far — reading what an employee
              // is responsible for is the point of opening their page. Only
              // the empty state is held back: RLS hides other people's
              // memberships from a viewer without one of these permissions,
              // and "assigned to nothing" would be a lie rather than a gap.
              const SizedBox(height: AppSpacing.lg),
              _ModuleAssignmentsSection(
                profileId: p.id,
                showWhenEmpty: canSeeModules,
              ),
              // What this person is ALLOWED to do, for whoever may read grant
              // sheets: seeing is permissions.view, changing is
              // permissions.manage — and for whoever holds the second, the
              // card is also the way into this person's own grant sheet.
              if (canSeePermissions) ...[
                const SizedBox(height: AppSpacing.lg),
                _GrantedPermissionsSection(
                  profile: p,
                  canManage: canManagePermissions,
                ),
              ],
              if (p.isExternal) ...[
                const SizedBox(height: AppSpacing.lg),
                InfoSection(
                  title: l.employeeSectionOrganization,
                  icon: AppIcons.organization,
                  children: [
                    InfoRow(
                      icon: AppIcons.organization,
                      label: l.employeeOrganization,
                      value: p.externalOrganization,
                    ),
                  ],
                ),
              ],
              // Where he is and when he goes home. High on the page rather than
              // at the foot with the registers, because it is a fact ABOUT the
              // man in the same way his telephone number is — not a judgement
              // recorded against him.
              if (canSeeTravel) ...[
                const SizedBox(height: AppSpacing.lg),
                TravelSection(profileId: p.id, canRead: canSeeTravel),
              ],
              // Last, and only for whoever keeps the register. What is being
              // said about a person belongs at the foot of their page rather
              // than in the middle of it — and the complainants' names are not
              // in it either way, because the counts are all the server sends.
              const SizedBox(height: AppSpacing.lg),
              ComplaintsAgainstSection(
                profileId: p.id,
                canReadRegister: canSeeComplaints,
              ),
              const SizedBox(height: AppSpacing.lg),
              EvaluationsAboutSection(
                profileId: p.id,
                target: EvaluationTarget.employee,
                targetId: p.id,
                canReadRegister: canSeeEvaluations,
                canReopen: session.can(PermissionCodes.evaluationsAssign),
              ),
            ];

            final bottom =
                AppSpacing.xl + MediaQuery.viewPaddingOf(context).bottom;

            return ResponsivePage(
              builder: (context, size) => size.isAtLeast(WindowSize.expanded)
                  ? TwoPaneLayout(
                      gutter: size.gutter,
                      bottom: bottom,
                      panel: FadeSlideIn(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: identity,
                        ),
                      ),
                      children: staggered(details),
                    )
                  : SinglePaneLayout(
                      gutter: size.gutter,
                      bottom: bottom,
                      children: staggered([
                        ...identity,
                        const SizedBox(height: AppSpacing.lg),
                        ...details,
                      ]),
                    ),
            );
          },
        ),
      ),
    );
  }
}

/// The seasons this employee has taken part in, newest first, with the season
/// currently under way marked so it stands out from the historical ones.
class _SeasonHistorySection extends StatelessWidget {
  const _SeasonHistorySection({required this.state});

  final EmployeeManageState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InfoSection(
      title: l.employeeSeasonsSection,
      icon: AppIcons.seasons,
      children: [
        if (state.loadingSeason)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (state.seasonHistory.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              l.employeeSeasonsEmpty,
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          for (final s in state.seasonHistory)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      AppIcons.seasons,
                      size: 16,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.seasonHijriYear(s.hijriYear),
                          style: text.bodyLarge,
                        ),
                        if (s.gregorianLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            s.gregorianLabel!,
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (s.id == state.currentSeason?.id)
                    GlassBadge(
                      label: l.employeeSeasonBadgeCurrent,
                      color: scheme.secondary,
                      dense: true,
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

/// The permissions this employee has been granted, grouped by the section they
/// belong to.
///
/// Only what was actually granted. The full catalog with everything unticked is
/// the permission EDITOR's job; here the question is "what may this person do",
/// and a list of ninety greyed-out rows is a worse answer than seven.
///
/// An administrator is a special case worth stating outright rather than
/// listing: `is_admin` outranks the whole table, so printing his handful of
/// explicit grants would understate what he can do.
class _GrantedPermissionsSection extends StatefulWidget {
  const _GrantedPermissionsSection({
    required this.profile,
    this.canManage = false,
  });

  final Profile profile;

  /// Whether the reader may CHANGE the grants — `permissions.manage`. It turns
  /// the card from a summary into a door: the button below opens this
  /// employee's own sheet in the permission editor, so granting no longer
  /// means walking to الإدارة ← الصلاحيات and finding the same name again.
  final bool canManage;

  @override
  State<_GrantedPermissionsSection> createState() =>
      _GrantedPermissionsSectionState();
}

class _GrantedPermissionsSectionState
    extends State<_GrantedPermissionsSection> {
  late Future<(List<Permission>, Set<String>)> _data = _load();

  Future<(List<Permission>, Set<String>)> _load() async {
    final repo = PermissionsRepository();
    final catalog = await repo.fetchCatalog();
    final granted = await repo.fetchGranted(widget.profile.id);
    return (catalog, granted);
  }

  /// Into this person's own grant sheet, and re-read on the way back: what was
  /// granted or revoked in there is exactly what this card lists.
  Future<void> _openEditor() async {
    await Navigator.of(context).push(
      fadeThroughRoute(
        (_) => PermissionEditorScreen(
          userId: widget.profile.id,
          employeeName: widget.profile.fullName,
        ),
      ),
    );
    if (mounted) setState(() => _data = _load());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget note(String message) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        message,
        style: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
        ),
      ),
    );

    // One child, deliberately: [InfoSection] lays its children into columns on
    // a wide window, and the edit button must stand under the grants, not
    // beside them in a column of its own.
    return InfoSection(
      title: l.employeePermissionsSection,
      icon: AppIcons.shield,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.profile.isAdmin)
              note(l.employeePermissionsAdmin)
            else ...[
              _grants(context, note),
              // No editor door on an administrator: is_admin outranks the
              // whole table, so a sheet of switches would change nothing.
              if (widget.canManage)
                TextButton.icon(
                  onPressed: _openEditor,
                  icon: const Icon(AppIcons.permissions, size: 18),
                  label: Text(l.employeePermissionsEdit),
                ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _grants(BuildContext context, Widget Function(String) note) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return FutureBuilder<(List<Permission>, Set<String>)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text('${snapshot.error}', style: text.bodySmall),
          );
        }
        final (catalog, granted) = snapshot.data!;
        final byId = {for (final p in catalog) p.id: p};
        final held =
            catalog.where((p) => granted.contains(p.id) && !p.isParent).toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        if (held.isEmpty) return note(l.employeePermissionsEmpty);

        // Group the actions under their section, in catalog order, so
        // the card reads the way the permission editor is laid out.
        final sections = <String, List<Permission>>{};
        for (final p in held) {
          final parent = byId[p.parentId]?.code ?? '';
          sections.putIfAbsent(parent, () => []).add(p);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in sections.entries) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  permissionLabel(l, entry.key),
                  style: text.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final p in entry.value)
                    GlassBadge(
                      label: permissionLabel(l, p.code),
                      color: scheme.secondary,
                      icon: AppIcons.selected,
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
        );
      },
    );
  }
}

/// The operational modules this employee is assigned to, and the role they hold
/// in each. One person commonly serves in several — a sector supervisor covers
/// more than one tower — so every assignment is listed, newest season first.
class _ModuleAssignmentsSection extends StatefulWidget {
  const _ModuleAssignmentsSection({
    required this.profileId,
    this.showWhenEmpty = true,
  });

  final String profileId;

  /// Whether "not assigned to anything" is worth saying. It only is when the
  /// viewer would have been shown the assignments had there been any.
  final bool showWhenEmpty;

  @override
  State<_ModuleAssignmentsSection> createState() =>
      _ModuleAssignmentsSectionState();
}

class _ModuleAssignmentsSectionState extends State<_ModuleAssignmentsSection> {
  late final Future<List<ModuleAssignment>> _assignments = ModulesRepository()
      .fetchAssignmentsForProfile(widget.profileId);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return FutureBuilder<List<ModuleAssignment>>(
      future: _assignments,
      builder: (context, snapshot) {
        final empty = (snapshot.data ?? const []).isEmpty;
        if (!widget.showWhenEmpty &&
            empty &&
            snapshot.connectionState != ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        return InfoSection(
          title: l.employeeModulesSection,
          icon: AppIcons.modules,
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('${snapshot.error}', style: text.bodySmall),
              )
            else if (empty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  l.employeeModulesEmpty,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              for (final assignment in snapshot.data!)
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    fadeThroughRoute(
                      // Opened from this employee's page, so the file shows
                      // THEIR role and duties — not the reader's own.
                      (_) => ModuleDetailScreen(
                        moduleId: assignment.module.id,
                        viewAsProfileId: widget.profileId,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            AppIcons.modules,
                            size: 16,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                assignment.module.moduleTypeName?.of(context) ??
                                    '—',
                                style: text.bodyLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Where in the file the role is held — one person
                              // may run three towers under the same file.
                              if ((assignment.placeName ?? '').isNotEmpty)
                                Text(
                                  assignment.placeName!,
                                  style: text.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  GlassBadge(
                                    label: assignment.roleName.of(context),
                                    icon: AppIcons.roles,
                                    dense: true,
                                  ),
                                  if (assignment.module.seasonHijriYear != null)
                                    GlassBadge(
                                      label: l.seasonHijriYear(
                                        assignment.module.seasonHijriYear!,
                                      ),
                                      color: scheme.secondary,
                                      icon: AppIcons.seasons,
                                      dense: true,
                                    ),
                                  if (!assignment.module.isRunning)
                                    GlassBadge(
                                      label: l.moduleBadgeDraft,
                                      color: scheme.tertiary,
                                      icon: AppIcons.edit,
                                      dense: true,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const NavChevron(),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({
    required this.state,
    required this.canSuspend,
    required this.canExternal,
    required this.canManageParticipants,
  });

  final EmployeeManageState state;
  final bool canSuspend;
  final bool canExternal;
  final bool canManageParticipants;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<EmployeeManageCubit>();
    final p = state.profile;

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          if (canManageParticipants && state.currentSeason != null)
            SwitchListTile(
              secondary: const Icon(AppIcons.seasons),
              title: Text(l.seasonHijriYear(state.currentSeason!.hijriYear)),
              subtitle: Text(l.seasonManageParticipants),
              value: state.inCurrentSeason,
              onChanged: state.busy ? null : (_) => cubit.toggleCurrentSeason(),
            ),
          if (canSuspend)
            SwitchListTile(
              secondary: Icon(
                AppIcons.suspend,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l.statusSuspendedTitle),
              value: p.isSuspended,
              onChanged: state.busy ? null : (_) => cubit.toggleSuspended(),
            ),
          if (canExternal)
            ListTile(
              leading: const Icon(AppIcons.external),
              title: Text(l.employeeEditExternalTitle),
              subtitle: Text(
                p.isExternal
                    ? (p.externalOrganization ?? l.employeeIsExternal)
                    : '—',
              ),
              trailing: const NavChevron(),
              onTap: state.busy
                  ? null
                  : () => showExternalEditSheet(context, cubit, p),
            ),
        ],
      ),
    );
  }
}
