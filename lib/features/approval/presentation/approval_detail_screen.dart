import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/enum_labels.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../../../core/widgets/profile_hero.dart';
import '../../../core/widgets/responsive.dart';
import '../../profile/domain/profile.dart';
import '../application/approval_cubit.dart';
import '../data/approval_repository.dart';
import 'widgets/document_tile.dart';

class ApprovalDetailScreen extends StatelessWidget {
  const ApprovalDetailScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final repo = ApprovalRepository();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(l.approvalDetailTitle)),
      body: Builder(
        // See HomeScreen: the padding must come from a context inside the body.
        builder: (context) => ResponsivePage(
          builder: (context, size) {
            final hero = ProfileHero(
              name: profile.fullName,
              photoUrl: profile.photoUrl,
              roleLabel: profile.jobTitleName?.of(context),
              badges: [
                if (profile.isExternal)
                  GlassBadge(
                    label: l.profileBadgeExternal,
                    color: scheme.tertiary,
                    icon: AppIcons.external,
                  ),
              ],
            );

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
                  // The address the account signs in with — worth checking
                  // before approving it.
                  InfoRow(
                    icon: AppIcons.email,
                    label: l.profileEmail,
                    value: profile.email,
                    action: InfoAction.email,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              InfoSection(
                title: l.profileSectionDocuments,
                icon: AppIcons.document,
                children: [
                  DocumentTile(
                    label: l.profilePassportPhoto,
                    path: profile.passportImageUrl,
                    repo: repo,
                  ),
                  DocumentTile(
                    label: l.profileVisaPhoto,
                    path: profile.visaImageUrl,
                    repo: repo,
                  ),
                  DocumentTile(
                    label: l.profileNusukPhoto,
                    path: profile.nusukCardImageUrl,
                    repo: repo,
                  ),
                ],
              ),
            ];

            // Deciding about a person means reading their file against their
            // face; on a window with the room, the face stays on the glass
            // while the file scrolls rather than leaving the moment it is
            // scrolled past.
            return size.isAtLeast(WindowSize.expanded)
                ? TwoPaneLayout(
                    gutter: size.gutter,
                    // Extra bottom room so the action bar never covers the
                    // last row.
                    bottom: AppSpacing.xxl,
                    panel: FadeSlideIn(child: hero),
                    children: staggered(details),
                  )
                : SinglePaneLayout(
                    gutter: size.gutter,
                    bottom: AppSpacing.xxl,
                    children: staggered([
                      hero,
                      const SizedBox(height: AppSpacing.lg),
                      ...details,
                    ]),
                  );
          },
        ),
      ),
      bottomNavigationBar: _ActionBar(profile: profile),
    );
  }
}

/// Approve / reject, pinned to the bottom on its own frosted bar so the
/// decision is always one reach away regardless of scroll position.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.profile});

  final Profile profile;

  Future<void> _reject(BuildContext context) async {
    final l = context.l10n;
    final controller = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.approvalRejectReasonTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: l.approvalRejectReasonHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l.approvalReject),
          ),
        ],
      ),
    );
    if (reason == null) return; // cancelled
    if (!context.mounted) return;
    final ok = await context.read<ApprovalCubit>().reject(profile.id, reason);
    if (ok && context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.approvalRejected)));
    }
  }

  Future<void> _approve(BuildContext context) async {
    final l = context.l10n;
    final ok = await context.read<ApprovalCubit>().approve(profile.id);
    if (ok && context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.approvalApproved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final processing = context.select<ApprovalCubit, bool>(
      (c) => c.state.processingIds.contains(profile.id),
    );

    return GlassSurface(
      radius: 0,
      strong: true,
      shadow: false,
      bordered: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: processing ? null : () => _reject(context),
                  icon: const Icon(AppIcons.reject, size: 20),
                  label: Text(l.approvalReject),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(
                      color: scheme.error.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: processing ? null : () => _approve(context),
                  icon: processing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            strokeCap: StrokeCap.round,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Icon(AppIcons.approve, size: 20),
                  label: Text(l.approvalApprove),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
