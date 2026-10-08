import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/glass_tokens.dart';
import 'glass.dart';
import 'photo_viewer.dart';
import 'profile_avatar.dart';

/// Identity block shared by "my profile" and the employee detail screen: a
/// gradient-ringed portrait, the person's name, their role, and any status
/// badges — presented on one pane so the person reads before the data.
class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.name,
    this.photoUrl,
    this.roleLabel,
    this.badges = const [],
  });

  final String name;
  final String? photoUrl;
  final String? roleLabel;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    final portrait = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ProfileAvatar(photoUrl: photoUrl, name: name, radius: 46),
    );

    return GlassCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          // Only where there is a photograph to enlarge. Initials on a coloured
          // disc are already at full size, and a tap that opens a black page
          // holding nothing teaches the wrong lesson about the gesture.
          if (!hasPhoto)
            portrait
          else
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => PhotoViewer.show(
                context,
                title: name.isEmpty ? '—' : name,
                url: photoUrl!,
              ),
              child: portrait,
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            name.isEmpty ? '—' : name,
            style: text.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (roleLabel != null && roleLabel!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            GlassBadge(
              label: roleLabel!,
              color: scheme.primary,
              icon: AppIcons.jobTitle,
            ),
          ],
          if (badges.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: badges,
            ),
          ],
        ],
      ),
    );
  }
}
