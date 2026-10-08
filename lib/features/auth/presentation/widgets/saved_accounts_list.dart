import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../domain/saved_account.dart';

/// The accounts saved on this device, as tappable cards.
///
/// One widget for both places that offer them — the login screen, where a card
/// is the way in, and the settings page, where it is the way across. They show
/// the same thing for the same reason, and a person who learns the row in one
/// place should not have to learn it again in the other.
///
/// A card and not a line of text: an account is recognised by a face and a
/// name, and a column of similar-looking addresses is something you read rather
/// than something you spot.
class SavedAccountsList extends StatelessWidget {
  const SavedAccountsList({
    super.key,
    required this.accounts,
    required this.onSelect,
    this.onForget,
    this.currentUserId,
    this.busyUserId,
  });

  final List<SavedAccount> accounts;
  final ValueChanged<SavedAccount> onSelect;

  /// Omitted where there is nowhere to confirm the removal — the login screen
  /// offers the accounts, and managing them belongs on the settings page.
  final ValueChanged<SavedAccount>? onForget;

  /// The account already open, if any. It is shown rather than hidden: a
  /// switcher that leaves out the one you are on makes you count to work out
  /// where you are.
  final String? currentUserId;

  /// The account being switched to right now. Every card locks while one is in
  /// flight, because a second tap would start a second session change on top of
  /// the first.
  final String? busyUserId;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final account in accounts) ...[
          _AccountCard(
            account: account,
            isCurrent: account.userId == currentUserId,
            isBusy: account.userId == busyUserId,
            locked: busyUserId != null,
            onSelect: () => onSelect(account),
            // Not offered on the account that is open: forgetting it would
            // only undo itself — the signed-in account is re-remembered on
            // every profile load — and a button that promises what it cannot
            // keep teaches the reader not to trust the rest.
            onForget: (onForget == null || account.userId == currentUserId)
                ? null
                : () => onForget!(account),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.isCurrent,
    required this.isBusy,
    required this.locked,
    required this.onSelect,
    this.onForget,
  });

  final SavedAccount account;
  final bool isCurrent;
  final bool isBusy;
  final bool locked;
  final VoidCallback onSelect;
  final VoidCallback? onForget;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // The subtitle carries the address, so the title is free to be the name.
    // Where there is no name the two would be the same string twice, and the
    // second line is dropped instead of repeated.
    final subtitle = account.label == account.email ? null : account.email;

    return GlassCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      emphasised: isCurrent,
      onTap: (isCurrent || locked) ? null : onSelect,
      child: Row(
        children: [
          ProfileAvatar(
            photoUrl: account.photoUrl,
            name: account.name,
            radius: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (isCurrent)
                  Text(
                    l.accountsCurrent,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Trailing(
            isBusy: isBusy,
            isCurrent: isCurrent,
            locked: locked,
            onForget: onForget,
          ),
        ],
      ),
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({
    required this.isBusy,
    required this.isCurrent,
    required this.locked,
    this.onForget,
  });

  final bool isBusy;
  final bool isCurrent;
  final bool locked;
  final VoidCallback? onForget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (isBusy) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    }

    if (onForget != null) {
      return IconButton(
        onPressed: locked ? null : onForget,
        icon: const Icon(AppIcons.removeAccount, size: 20),
        tooltip: context.l10n.accountsRemove,
        color: scheme.onSurfaceVariant,
        visualDensity: VisualDensity.compact,
      );
    }

    // Nothing to do to the account you are on, and an arrow on it would say
    // there is.
    if (isCurrent) {
      return Icon(AppIcons.selected, size: 20, color: scheme.primary);
    }

    return Icon(AppIcons.switchAccount, size: 20, color: scheme.onSurfaceVariant);
  }
}
