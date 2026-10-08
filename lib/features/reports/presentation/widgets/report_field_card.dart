import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../modules/domain/module_type.dart';

/// Kinds that are something to DO rather than something to read, and so get a
/// card of their own instead of a row in the report's header.
bool isActionableReportField(ModuleFieldKind kind) =>
    kind == ModuleFieldKind.url ||
    kind == ModuleFieldKind.qr ||
    kind == ModuleFieldKind.pdf ||
    kind == ModuleFieldKind.location;

/// A link to follow, or a code to hold up.
///
/// Shared by the report's header fields and by a written report's blocks: a
/// link is a link whether the type declared it or somebody wrote it into the
/// middle of a notice.
class ReportFieldCard extends StatelessWidget {
  const ReportFieldCard({
    super.key,
    required this.label,
    required this.value,
    required this.kind,
  });

  final String label;
  final String value;
  final ModuleFieldKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (kind == ModuleFieldKind.qr) {
      return GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(label, style: text.titleSmall),
            const SizedBox(height: AppSpacing.md),
            // On white, in both themes. A camera looks for dark modules on a
            // light field; drawn on the dark theme's surface it scans slowly or
            // not at all.
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: QrImageView(
                data: value,
                size: 180,
                backgroundColor: Colors.white,
                // Says so, rather than drawing the red X nobody can read.
                errorStateBuilder: (context, _) => SizedBox(
                  width: 180,
                  height: 180,
                  child: Center(
                    child: Text(
                      context.l10n.reportQrFailed,
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final uri = Uri.tryParse(value);
    return GlassCard(
      onTap: uri == null
          ? null
          : () => launchUrl(uri, mode: LaunchMode.externalApplication),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(
            kind == ModuleFieldKind.pdf ? AppIcons.pdf : AppIcons.link,
            color: scheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.titleSmall),
                Text(
                  value,
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
    );
  }
}
