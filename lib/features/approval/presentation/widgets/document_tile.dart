import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../../data/approval_repository.dart';

/// A row for a private document. Resolves a signed URL lazily and opens a
/// full-screen zoomable viewer when tapped.
class DocumentTile extends StatefulWidget {
  const DocumentTile({
    super.key,
    required this.label,
    required this.path,
    required this.repo,
  });

  final String label;
  final String? path;
  final ApprovalRepository repo;

  @override
  State<DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<DocumentTile> {
  bool _loading = false;

  Future<void> _open() async {
    if (widget.path == null) return;
    setState(() => _loading = true);
    try {
      final url = await widget.repo.signedDocumentUrl(widget.path!);
      if (!mounted) return;
      PhotoViewer.show(context, title: widget.label, url: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final has = widget.path != null && widget.path!.isNotEmpty;

    return InkWell(
      onTap: has ? _open : null,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (has ? scheme.primary : scheme.outline).withValues(
                  alpha: 0.10,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                has ? AppIcons.document : AppIcons.documentEmpty,
                size: 16,
                color: has ? scheme.primary : scheme.outline,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (_loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  strokeCap: StrokeCap.round,
                  color: scheme.primary,
                ),
              )
            else if (has)
              Icon(AppIcons.view, size: 20, color: scheme.onSurfaceVariant)
            else
              Text(
                context.l10n.profileFieldNotProvided,
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
