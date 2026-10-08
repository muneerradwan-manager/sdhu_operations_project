import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_icons.dart';
import '../theme/glass_tokens.dart';

/// One entry of an [OverflowMenu].
class MenuAction {
  const MenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;

  /// Drawn in the error colour and placed under a divider. Deleting is not the
  /// same kind of act as editing, and a menu that presents them identically
  /// invites the tap it should be guarding against.
  final bool isDestructive;
}

/// The three-dot menu that stands in for a row of icon buttons.
///
/// An app bar carrying an edit button beside a delete button asks the reader to
/// tell two small glyphs apart, on a target the width of a thumb, where one of
/// them is destructive. Behind one overflow icon the same two actions are
/// labelled in words, and the dangerous one is set apart and reached
/// deliberately.
///
/// Actions that are not permitted should be left OUT of [actions] rather than
/// disabled: a greyed-out Delete tells a reader the file can be deleted and
/// that they are the wrong person, which is more than the screen means to say.
class OverflowMenu extends StatelessWidget {
  const OverflowMenu({super.key, required this.actions, this.tooltip});

  final List<MenuAction> actions;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    // A single action does not need a menu to hide behind.
    if (actions.length == 1) {
      final only = actions.single;
      return IconButton(
        tooltip: only.label,
        onPressed: only.onSelected,
        icon: Icon(
          only.icon,
          color: only.isDestructive ? scheme.error : null,
        ),
      );
    }

    final safe = actions.where((a) => !a.isDestructive).toList();
    final destructive = actions.where((a) => a.isDestructive).toList();

    return PopupMenuButton<MenuAction>(
      tooltip: tooltip ?? context.l10n.commonMore,
      icon: const Icon(AppIcons.more),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (a) => a.onSelected(),
      itemBuilder: (context) => [
        for (final a in safe)
          PopupMenuItem<MenuAction>(
            value: a,
            child: Row(
              children: [
                Icon(a.icon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.md),
                Text(a.label),
              ],
            ),
          ),
        if (safe.isNotEmpty && destructive.isNotEmpty)
          const PopupMenuDivider(),
        for (final a in destructive)
          PopupMenuItem<MenuAction>(
            value: a,
            child: Row(
              children: [
                Icon(a.icon, size: 18, color: scheme.error),
                const SizedBox(width: AppSpacing.md),
                Text(a.label, style: TextStyle(color: scheme.error)),
              ],
            ),
          ),
      ],
    );
  }
}
