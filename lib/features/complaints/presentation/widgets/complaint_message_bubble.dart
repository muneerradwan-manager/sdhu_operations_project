import 'package:flutter/material.dart';

import '../../../../core/attachments/attachments_view.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/info_section.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../domain/complaint.dart';
import 'complaint_labels.dart';

/// One message in a thread — the complaint itself, or a reply.
///
/// A bubble whose writer this reader may not know shows a shield instead of a
/// face and its writer's SIDE instead of a name. That is the visible half of
/// the anonymity; the half that matters is that the name never left the server.
class ComplaintMessageBubble extends StatelessWidget {
  const ComplaintMessageBubble({
    super.key,
    required this.message,
    required this.signer,
  });

  final ComplaintMessage message;
  final AttachmentSigner signer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final name = message.isAnonymous
        ? complaintRoleLabel(l, message.role)
        : (message.authorName ?? complaintRoleLabel(l, message.role));

    return GlassCard(
      // The complaint itself carries more weight than the answers to it, and
      // the reader should be able to tell which one they are looking at without
      // scrolling to the top to check.
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      emphasised: message.isHead,
      tint: message.isMine ? scheme.primary : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (message.isAnonymous)
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Icon(
                    AppIcons.shield,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                ProfileAvatar(
                  photoUrl: message.authorPhotoUrl,
                  name: name,
                  radius: 18,
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.titleSmall),
                    Text(
                      formatDate(message.createdAt),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Said on every bubble, not only the nameless ones: in a thread
              // where three sides speak, "who is this" is the first question
              // and a name alone does not answer it.
              GlassBadge(
                label: complaintRoleLabel(l, message.role),
                dense: true,
                color: switch (message.role) {
                  ComplaintRole.accused => scheme.error,
                  ComplaintRole.manager => scheme.tertiary,
                  ComplaintRole.complainant => scheme.secondary,
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(message.body, style: text.bodyMedium),
          if (message.attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AttachmentsView(attachments: message.attachments, signer: signer),
          ],
        ],
      ),
    );
  }
}
