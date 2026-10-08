import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_icons.dart';
import '../theme/glass_tokens.dart';
import 'glass.dart';

/// Says that what is on screen came off the disk, and when it was true.
///
/// The whole value of a saved copy rests on the reader knowing it is one. A
/// roster shown silently from yesterday is worse than an error: an error sends
/// somebody to a telephone, and a stale list that looks live sends them to a
/// tent that was reassigned this morning.
///
/// So it names the TIME, not merely the fact. "A saved copy" leaves the reader
/// to guess how old — an hour? the last time they had signal? last week? —
/// and standing at a gate with no bars, how old it is is the only input to the
/// only decision they have: act on this, or go and ask somebody.
///
/// Deliberately not an error colour. Nothing has gone wrong that the reader can
/// fix, and painting it red trains them to ignore red. It is information, in
/// the colour information is in.
class SavedCopyBanner extends StatelessWidget {
  const SavedCopyBanner({super.key, required this.savedAt});

  /// When the shown data was last true. Null means it is live, and the banner
  /// draws nothing — so a screen can hand its state's field straight in without
  /// an `if` at the call site.
  final DateTime? savedAt;

  @override
  Widget build(BuildContext context) {
    final at = savedAt;
    if (at == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final local = at.toLocal();
    // Time alone for something saved today, date and time otherwise. A bare
    // "14:32" on a copy from three days ago reads as half an hour ago, which is
    // the one misreading this banner exists to prevent.
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final pattern = sameDay ? 'HH:mm' : 'yyyy/MM/dd HH:mm';
    final when = DateFormat(
      pattern,
      Localizations.localeOf(context).toString(),
    ).format(local);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassSurface(
        subtle: true,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // The outbox's own icon — a cloud with a line through it. The queue
            // and this banner are the two faces of the same condition, so a
            // reader who has learned one has learned the other.
            Icon(AppIcons.outbox, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.l10n.offlineShowingSaved(when),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
