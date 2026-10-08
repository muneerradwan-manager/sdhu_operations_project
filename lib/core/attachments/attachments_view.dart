import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_icons.dart';
import '../theme/glass_tokens.dart';
import '../widgets/glass.dart';
// For the icon and the kind's name, which come with the attachment itself.
import 'attachment_picker.dart';

/// Mints a short-lived link to a stored file. Every bucket in this app is
/// private, and each one has its own repository that knows how to sign for it —
/// so the view is handed the signing rather than a repository.
typedef AttachmentSigner =
    Future<String> Function(
      String path, {
      bool download,
      String? downloadName,
    });

/// Everything attached to one thing: the photos as a strip you can see without
/// opening anything, and the rest as rows.
class AttachmentsView extends StatelessWidget {
  const AttachmentsView({
    super.key,
    required this.attachments,
    required this.signer,
  });

  final List<StoredAttachment> attachments;
  final AttachmentSigner signer;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final images = attachments
        .where((a) => a.kind == AttachmentKind.image)
        .toList();
    final others = attachments
        .where((a) => a.kind != AttachmentKind.image)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) =>
                  _ImageThumb(attachment: images[i], all: images, signer: signer),
            ),
          ),
        ],
        for (final attachment in others) ...[
          const SizedBox(height: AppSpacing.sm),
          _AttachmentRow(attachment: attachment, signer: signer),
        ],
      ],
    );
  }
}

/// Opens the signed URL with whatever the device uses for it. Videos, voice
/// notes and documents are handed off rather than played in here: the platform
/// player already knows the codecs, the scrubbing and the volume keys.
Future<void> _openExternally(
  BuildContext context,
  AttachmentSigner signer,
  StoredAttachment attachment, {
  bool download = false,
}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final url = await signer(
      attachment.path,
      download: download,
      downloadName: attachment.name,
    );
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.attachmentOpenFailed)));
    }
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$e')));
  }
}

class _ImageThumb extends StatefulWidget {
  const _ImageThumb({
    required this.attachment,
    required this.all,
    required this.signer,
  });

  final StoredAttachment attachment;

  /// The other photos alongside it, so the viewer can be swiped through instead
  /// of backed out of and reopened.
  final List<StoredAttachment> all;

  final AttachmentSigner signer;

  @override
  State<_ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<_ImageThumb> {
  Future<String>? _url;

  @override
  void initState() {
    super.initState();
    _url = widget.signer(widget.attachment.path);
  }

  Future<void> _open() async {
    final urls = <String>[];
    for (final a in widget.all) {
      urls.add(await widget.signer(a.path));
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageViewer(
          attachments: widget.all,
          urls: urls,
          initialIndex: widget.all.indexOf(widget.attachment),
          signer: widget.signer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _open,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          width: 108,
          height: 108,
          child: FutureBuilder<String>(
            future: _url,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    AppIcons.image,
                    color: scheme.onSurfaceVariant,
                    size: 20,
                  ),
                );
              }
              return CachedNetworkImage(
                imageUrl: snapshot.data!,
                // Keyed on the storage path, not the URL: every signature is a
                // different URL, so without this the cache would never once hit
                // and the screen would re-download its photos on every rebuild.
                cacheKey: widget.attachment.path,
                fit: BoxFit.cover,
                errorWidget: (context, _, _) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(AppIcons.image, color: scheme.error, size: 20),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A video, a voice note or a document: what it is, how big, and the two things
/// you can do with it.
class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment, required this.signer});

  final StoredAttachment attachment;
  final AttachmentSigner signer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final size = attachment.readableSize;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _openExternally(context, signer, attachment),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              attachmentIcon(attachment.kind),
              size: 18,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  style: text.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    attachmentKindLabel(context, attachment.kind),
                    ?size,
                  ].join(' · '),
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.attachmentDownload,
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                _openExternally(context, signer, attachment, download: true),
            icon: const Icon(AppIcons.download, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Full-screen photos, zoomable and swipeable, with a download at the top.
class _ImageViewer extends StatefulWidget {
  const _ImageViewer({
    required this.attachments,
    required this.urls,
    required this.initialIndex,
    required this.signer,
  });

  final List<StoredAttachment> attachments;
  final List<String> urls;
  final int initialIndex;
  final AttachmentSigner signer;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = widget.attachments[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          current.name,
          style: const TextStyle(fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: l.attachmentDownload,
            onPressed: () =>
                _openExternally(context, widget.signer, current, download: true),
            icon: const Icon(AppIcons.download),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.urls[i],
              cacheKey: widget.attachments[i].path,
              fit: BoxFit.contain,
              progressIndicatorBuilder: (context, _, _) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, _, _) =>
                  Icon(AppIcons.image, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
