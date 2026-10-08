import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_icons.dart';
import '../theme/glass_tokens.dart';
import 'glass.dart';
import 'profile_avatar.dart';

/// A glass row representing an employee: avatar, name, job title, optional
/// external badge, and a customizable trailing widget.
///
/// Rendered without backdrop blur — these appear dozens at a time in scrolling
/// directories, and the translucent fill alone carries the material.
class EmployeeTile extends StatelessWidget {
  const EmployeeTile({
    super.key,
    required this.name,
    this.photoUrl,
    this.subtitle,
    this.isExternal = false,
    this.trailing,
    this.onTap,
  });

  final String name;
  final String? photoUrl;
  final String? subtitle;
  final bool isExternal;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          ProfileAvatar(photoUrl: photoUrl, name: name, radius: 23),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isEmpty ? '—' : name,
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isExternal) ...[
                      const SizedBox(width: AppSpacing.sm),
                      GlassBadge(
                        label: context.l10n.profileBadgeExternal,
                        color: scheme.tertiary,
                        icon: AppIcons.external,
                        dense: true,
                      ),
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
