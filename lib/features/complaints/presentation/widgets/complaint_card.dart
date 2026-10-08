import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/info_section.dart';
import '../../domain/complaint.dart';
import 'complaint_labels.dart';

/// One complaint as a row in either register.
class ComplaintCard extends StatelessWidget {
  const ComplaintCard({super.key, required this.complaint, this.onOpen});

  final Complaint complaint;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // A dismissed complaint is not deleted and not hidden — it is greyed, the
    // way a struck line stays legible.
    final muted = complaint.isDismissed;
    final title = (complaint.targetLabel ?? '').trim().isEmpty
        ? complaintTargetLabel(l, complaint.target)
        : complaint.targetLabel!;

    final tone = muted ? scheme.onSurfaceVariant : scheme.primary;

    return GlassCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The kind's glyph in a tinted frame — the treatment every card
              // in the app leads with.
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: tone.withValues(alpha: 0.18)),
                ),
                child: Icon(
                  complaintTargetIcon(complaint.target),
                  size: 22,
                  color: tone,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: muted ? scheme.onSurfaceVariant : null,
                        decoration: muted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // The kind and the date in one quiet line — identity, not
                    // status, so it is text and not a row of pills.
                    Text(
                      '${complaintTargetLabel(l, complaint.target)}'
                      ' · ${l.complaintFiledOn(formatDate(complaint.createdAt))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const NavChevron(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            complaint.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          // Counters as quiet figures, pills only for what changes how the
          // thread behaves — locked, dismissed.
          if (complaint.replyCount > 0 ||
              complaint.attachmentCount > 0 ||
              complaint.isLocked ||
              complaint.isDismissed) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (complaint.replyCount > 0)
                  _Counter(
                    icon: AppIcons.complaints,
                    label: l.complaintReplyCount(complaint.replyCount),
                  ),
                if (complaint.attachmentCount > 0)
                  _Counter(
                    icon: AppIcons.attach,
                    label: '${complaint.attachmentCount}',
                  ),
                if (complaint.isLocked)
                  GlassBadge(
                    label: l.complaintLocked,
                    icon: AppIcons.complaintLocked,
                    color: scheme.onSurfaceVariant,
                    dense: true,
                  ),
                if (complaint.isDismissed)
                  GlassBadge(
                    label: l.complaintDismissed,
                    icon: AppIcons.complaintDismissed,
                    color: scheme.error,
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

/// A small figure with its glyph — "how many" said quietly, where a pill
/// would be one more coloured thing shouting on the card.
class _Counter extends StatelessWidget {
  const _Counter({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
