import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/enum_labels.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/l10n/permission_labels.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../../../core/widgets/profile_hero.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../../complaints/presentation/widgets/complaints_against_section.dart';
import '../../evaluations/presentation/widgets/evaluations_about_section.dart';
import '../domain/profile.dart';
import 'profile_completion_screen.dart';
import 'widgets/change_email_sheet.dart';
import 'widgets/change_password_sheet.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profile = context.watch<SessionCubit>().state.profile;

    if (profile == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(title: Text(l.navMyProfile)),
        body: const AppLoader(),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(l.navMyProfile)),
      body: Builder(
        // See HomeScreen: the padding must come from a context inside the body.
        builder: (context) => ResponsivePage(
          builder: (context, size) {
            // Who this is, and the two things you can do about it. A tall,
            // narrow block by nature — a portrait over a name over two rows —
            // which is why it becomes the standing panel as soon as there is a
            // column to stand it in.
            final identity = <Widget>[
              ProfileHero(
                name: profile.fullName,
                photoUrl: profile.photoUrl,
                roleLabel: profile.jobTitleName?.of(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ActionsCard(profile: profile),
            ];

            final details = <Widget>[
              InfoSection(
                title: l.profileSectionPersonal,
                icon: AppIcons.firstName,
                children: [
                  InfoRow(
                    icon: AppIcons.firstName,
                    label: l.profileFirstName,
                    value: profile.firstName,
                  ),
                  InfoRow(
                    icon: AppIcons.fatherName,
                    label: l.profileFatherName,
                    value: profile.fatherName,
                  ),
                  InfoRow(
                    icon: AppIcons.surname,
                    label: l.profileSurname,
                    value: profile.surname,
                  ),
                  InfoRow(
                    icon: AppIcons.location,
                    label: l.profileCity,
                    value: profile.cityName?.of(context),
                  ),
                  InfoRow(
                    icon: AppIcons.gender,
                    label: l.profileGender,
                    value: profile.gender?.label(l),
                  ),
                  InfoRow(
                    icon: AppIcons.mission,
                    label: l.profileMissionType,
                    value: profile.missionTypeName?.of(context),
                  ),
                  InfoRow(
                    icon: AppIcons.dateOfBirth,
                    label: l.profileDateOfBirth,
                    value: formatDate(profile.dateOfBirth),
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
                    value: profile.phoneSy,
                    action: InfoAction.call,
                  ),
                  InfoRow(
                    icon: AppIcons.phoneSa,
                    label: l.profilePhoneSa,
                    value: profile.phoneSa,
                    action: InfoAction.call,
                  ),
                  InfoRow(
                    icon: AppIcons.email,
                    label: l.profileEmail,
                    value: profile.email,
                    action: InfoAction.email,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _PermissionsCard(session: context.watch<SessionCubit>().state),
              // What is being said about him, at the foot of his own page — the
              // words and the files and the way to answer them, and never the
              // name of whoever filed it. This is the only door in the app that
              // hands a man his own case.
              const SizedBox(height: AppSpacing.lg),
              const ComplaintsAgainstSection(),
              // And the marks, beside the words, for the same reason and
              // through the same kind of door: `evaluations_about_me` does not
              // select the evaluator's column, so what arrives here is a title,
              // a date and a score and there is no name in it to withhold.
              const SizedBox(height: AppSpacing.lg),
              const EvaluationsAboutSection(),
            ];

            Future<void> refresh() => context.read<SessionCubit>().reload();

            // The panel arrives one step earlier here than on the dashboard.
            // There, the split has to wait until the tiles beside it can still
            // hold two columns; here the content is fields, which read fine in
            // one column, so the moment the identity block has a column of its
            // own is the moment it should take it.
            return size.isAtLeast(WindowSize.expanded)
                ? TwoPaneLayout(
                    gutter: size.gutter,
                    panel: FadeSlideIn(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: identity,
                      ),
                    ),
                    onRefresh: refresh,
                    children: staggered(details),
                  )
                : SinglePaneLayout(
                    gutter: size.gutter,
                    onRefresh: refresh,
                    children: staggered([
                      ...identity,
                      const SizedBox(height: AppSpacing.lg),
                      ...details,
                    ]),
                  );
          },
        ),
      ),
    );
  }
}

/// What this person is allowed to do, and nothing about what they have done.
///
/// It belongs on the profile for the same reason the job title does: a
/// permission is part of what somebody IS here. And it answers, without anybody
/// having to be asked, the question that otherwise reaches an administrator by
/// phone — why a screen somebody was told about has no button on it.
///
/// Two cases the naive version gets wrong:
///
///   * An ADMIN holds every permission and carries none. [SessionState.can]
///     short-circuits on `isAdmin`, so the set is empty for the one account
///     that can do everything — printing it would tell the most powerful user
///     in the system that he has no permissions at all.
///   * NOTHING granted is the ordinary case, not a fault. Most of the mission
///     holds no administrative permission and needs none: a file reaches its
///     members by assignment. Said plainly here, so an empty card does not read
///     as something having gone wrong.
class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Grouped under the section each belongs to — "employees.view" under
    // "employees" — because a flat list of fourteen codes is a list nobody
    // reads. The section's own code is dropped from its group: it is the
    // heading, and repeating it as its own first chip says nothing.
    final grouped = <String, List<String>>{};
    for (final code in session.permissions) {
      final parts = code.split('.');
      grouped.putIfAbsent(parts.first, () => <String>[]);
      if (parts.length > 1) grouped[parts.first]!.add(code);
    }
    for (final actions in grouped.values) {
      actions.sort();
    }

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.shield, size: 17, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l.profileSectionPermissions,
                  style: text.titleMedium,
                ),
              ),
              if (!session.isAdmin && session.permissions.isNotEmpty)
                Text(
                  l.profilePermissionsCount(session.permissions.length),
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (session.isAdmin)
            GlassBadge(
              label: l.profilePermissionsAdmin,
              color: scheme.primary,
              icon: AppIcons.shield,
            )
          else if (grouped.isEmpty) ...[
            Text(
              l.profilePermissionsNone,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.profilePermissionsNoneHint,
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                height: 1.4,
              ),
            ),
          ] else
            for (final section in grouped.keys) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  permissionLabel(l, section),
                  style: text.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // The section on its own, with no action under it, is itself a
              // grant — it is what opens the screen. Said so, rather than left
              // as a heading over nothing.
              if (grouped[section]!.isEmpty)
                GlassBadge(
                  label: permissionLabel(l, section),
                  color: scheme.primary,
                  dense: true,
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final code in grouped[section]!)
                      GlassBadge(
                        label: permissionLabel(l, code),
                        color: scheme.primary,
                        icon: AppIcons.selected,
                        dense: true,
                      ),
                  ],
                ),
            ],
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          _ActionRow(
            icon: AppIcons.edit,
            label: l.myProfileEdit,
            onTap: () => Navigator.of(context).push(
              fadeThroughRoute(
                (_) => ProfileCompletionScreen(existing: profile),
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 60,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          _ActionRow(
            icon: AppIcons.password,
            label: l.myProfileChangePassword,
            onTap: () => showChangePasswordSheet(context),
          ),
          Divider(
            height: 1,
            indent: 60,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          _ActionRow(
            icon: AppIcons.email,
            label: l.myProfileChangeEmail,
            onTap: () => showChangeEmailSheet(context),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
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
              child: Icon(icon, size: 16, color: scheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            const NavChevron(),
          ],
        ),
      ),
    );
  }
}
