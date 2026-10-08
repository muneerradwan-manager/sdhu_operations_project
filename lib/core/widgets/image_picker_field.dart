import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../attachments/attachment_picker.dart' show isCameraCaptureSupported;
import '../l10n/l10n_extension.dart';
import '../logging/app_logger.dart';
import '../theme/app_icons.dart';
import '../theme/glass_tokens.dart';

/// A tappable field that lets the user pick an image (camera or gallery) and
/// previews the selection. Two shapes: a circular avatar or a rounded card.
class ImagePickerField extends StatelessWidget {
  const ImagePickerField({
    super.key,
    required this.label,
    required this.file,
    required this.onPicked,
    this.circular = false,
    this.errorText,
    this.existingUrl,
  });

  final String label;
  final File? file;
  final ValueChanged<File> onPicked;
  final bool circular;
  final String? errorText;

  /// Network URL of an already-uploaded image, shown when no new [file] is picked.
  final String? existingUrl;

  Future<void> _pick(BuildContext context) async {
    // No sheet at all where there is no camera to offer — see
    // [isCameraCaptureSupported]. A chooser with one thing in it is not a
    // choice; it is a tap the reader has to make before the tap they meant. On
    // a desktop this goes straight to the file dialog, which is the only answer
    // that was ever available there.
    final source = isCameraCaptureSupported
        ? await _chooseSource(context)
        : ImageSource.gallery;
    if (source == null) return;

    // The picker itself is not allowed to reach the zone handler. Until this
    // was gated, `ImageSource.camera` on Windows threw straight out of here —
    // `Bad state: … requires a "cameraDelegate"` — and what the reader saw was
    // the sheet closing and nothing else happening at all.
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (picked != null) onPicked(File(picked.path));
    } catch (e) {
      AppLogger.warn('images', 'pick failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.attachmentPickFailed)),
        );
    }
  }

  Future<ImageSource?> _chooseSource(BuildContext context) =>
      showModalBottomSheet<ImageSource>(
        context: context,
        // Over the rail as well as the page — see [showAppSheet].
        useRootNavigator: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(AppIcons.camera),
                title: Text(sheetContext.l10n.profileCamera),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(AppIcons.gallery),
                title: Text(sheetContext.l10n.profileGallery),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (circular) {
      final hasImage =
          file != null || (existingUrl != null && existingUrl!.isNotEmpty);
      return Column(
        children: [
          GestureDetector(
            onTap: () => _pick(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // The well token rather than a white at six per cent: an empty
                // picker is a hollow cut into whatever it stands on, and on
                // paper that surface is already white.
                color: context.glass.fillSubtle,
                // An empty picker glows in the brand colour so it reads as the
                // next thing to tap; once filled it settles to a quiet rim.
                border: Border.all(
                  color: errorText != null
                      ? scheme.error
                      : (hasImage
                            ? scheme.outlineVariant
                            : scheme.primary.withValues(alpha: 0.55)),
                  width: 2,
                ),
                boxShadow: hasImage || errorText != null
                    ? null
                    : [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                image: file != null
                    ? DecorationImage(
                        image: FileImage(file!),
                        fit: BoxFit.cover,
                      )
                    : (existingUrl != null && existingUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(existingUrl!),
                              fit: BoxFit.cover,
                            )
                          : null),
              ),
              child:
                  (file == null &&
                      (existingUrl == null || existingUrl!.isEmpty))
                  ? Icon(
                      AppIcons.addPhoto,
                      color: scheme.onSurfaceVariant,
                      size: 34,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: errorText != null ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: file != null
                  ? Image.file(file!, width: 52, height: 52, fit: BoxFit.cover)
                  : Container(
                      width: 52,
                      height: 52,
                      color: scheme.surfaceContainerHigh,
                      child: Icon(
                        AppIcons.image,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label)),
            Icon(
              file != null ? AppIcons.selected : AppIcons.upload,
              color: file != null ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
