import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/share/save_to_device.dart';
import '../../../core/share/shareable.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../../../core/widgets/overflow_menu.dart';
import '../application/place_code_cubit.dart';
import '../data/check_in_repository.dart';
import 'place_code_screen.dart';

/// The code fixed to one place, on that place's own page.
///
/// This is where it belongs now. It used to be a list hanging off an
/// operational file — print the codes for this file's towers — which was the
/// right place while a tower was part of a file. Since 0095 a hotel is an entry
/// of a list and belongs to the season rather than to any one file, and since
/// 0098 the code belongs to the entry. So the code is on the hotel's page, and
/// the batch print is on the list's.
class PlaceCodeCard extends StatelessWidget {
  const PlaceCodeCard({
    super.key,
    required this.itemId,
    required this.placeName,
    this.subtitle,
  });

  final String itemId;
  final String placeName;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PlaceCodeCubit(CheckInRepository(), itemId),
    child: _Card(placeName: placeName, subtitle: subtitle),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.placeName, this.subtitle});

  final String placeName;
  final String? subtitle;

  Future<void> _print(BuildContext context, String payload) =>
      Printing.layoutPdf(
        onLayout: (format) => placeCodeSheet(
          format: format,
          payload: payload,
          placeName: placeName,
          subtitle: subtitle,
        ),
        name: 'place-code',
      );

  /// Hands the poster to whatever the platform shares with.
  ///
  /// Guarded, because this can fail for reasons the presser can do nothing
  /// about and is entitled to hear: a Windows older than 10 RS5 has no share
  /// sheet that takes files at all and `share_plus` says so by throwing, and a
  /// desktop with nothing registered to receive a PDF is a sheet that opens
  /// onto nothing. Unguarded, the menu item simply did nothing and the failure
  /// went to the crash log, where the man holding the phone cannot read it.
  ///
  /// The message points at the printer, because that is the way out: printing
  /// is what this poster is FOR, and it goes through a different path that does
  /// not depend on the share sheet existing.
  Future<void> _share(BuildContext context, String payload) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await placeCodeSheet(
        format: PdfPageFormat.a4,
        payload: payload,
        placeName: placeName,
        subtitle: subtitle,
      );
      final file = await asShareable(
        bytes,
        name: 'place-code.pdf',
        mimeType: 'application/pdf',
      );
      await SharePlus.instance.share(
        ShareParams(files: [file], title: placeName),
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.checkInQrShareFailed)));
    }
  }

  /// Puts the poster somewhere the person chooses and keeps.
  ///
  /// Printing wants a printer attached and sharing wants something registered
  /// to receive a PDF; this wants neither, which is what makes it the one that
  /// always works on an operations-room machine. The forty posters for a list
  /// can be put in a folder and taken to whatever prints them.
  ///
  /// It used to be desktop-only, because [saveToDevice] was. It is not any
  /// more — the phone opens its own document picker — and this screen inherited
  /// that without asking for it, which is right: a man photographing posters to
  /// print at a shop wanted the file, not a share sheet.
  Future<void> _save(BuildContext context, String payload) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await placeCodeSheet(
        format: PdfPageFormat.a4,
        payload: payload,
        placeName: placeName,
        subtitle: subtitle,
      );
      final result = await saveToDevice(
        bytes,
        // Named after the place, because the point of saving forty of these is
        // being able to tell them apart in a folder afterwards.
        suggestedName: '${_fileName(placeName)}.pdf',
        label: 'PDF',
        extension: 'pdf',
        mimeType: 'application/pdf',
      );

      final message = switch (result.outcome) {
        // Closing the dialog is an answer, and answering it is not an event.
        SaveOutcome.cancelled => null,
        // Android answers with a document URI rather than a path anybody
        // would recognise, and sometimes with nothing at all. "Saved to " with
        // an empty tail is worse than "saved".
        SaveOutcome.saved =>
          (result.path?.isNotEmpty ?? false)
              ? l.checkInQrSaved(result.path!)
              : l.checkInQrSavedPlain,
        SaveOutcome.failed => l.checkInQrSaveFailed,
      };
      if (message == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.checkInQrSaveFailed)));
    }
  }

  /// The place's name reduced to something every filesystem will take.
  ///
  /// Arabic is kept — Windows, macOS and Linux all store it — and only the
  /// characters that are structure rather than text go. A name that is nothing
  /// but those falls back, because a file called ".pdf" is a hidden file.
  static String _fileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'place-code' : cleaned;
  }

  /// Names what it destroys rather than asking whether you are sure.
  ///
  /// "Are you sure" is a question nobody reads. What matters here is a fact the
  /// presser may not have: there are printed copies of this code on a wall
  /// somewhere, they all stop working the moment this returns, and until the
  /// new one is printed and stuck up NOBODY CAN CHECK IN AT THIS PLACE. That is
  /// worth a sentence, and it is why the success path offers the printer
  /// immediately — the wall is wrong now and should be fixed in the same trip.
  Future<void> _rotate(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<PlaceCodeCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.checkInQrRotate),
        content: Text(l.checkInQrRotateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.checkInQrRotate),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final failure = await cubit.rotate();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failure == null ? l.checkInQrRotated : friendlyErrorL(l, failure),
          ),
        ),
      );
    if (failure != null) return;

    final payload = cubit.state.code?.encode();
    if (payload != null && context.mounted) await _print(context, payload);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return BlocBuilder<PlaceCodeCubit, PlaceCodeState>(
      builder: (context, state) {
        // Nothing at all for somebody without the permission. A card explaining
        // that he may not see the code is a card telling him there is one.
        if (state.status == PlaceCodeStatus.denied) {
          return const SizedBox.shrink();
        }
        final code = state.code;
        if (code == null) return const SizedBox.shrink();
        final payload = code.encode();

        return FadeSlideIn(
          child: GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.qrCode, size: 18, color: scheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l.checkInQrCard,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    OverflowMenu(
                      actions: [
                        MenuAction(
                          icon: AppIcons.qrCode,
                          label: l.checkInQrPrint,
                          onSelected: () => _print(context, payload),
                        ),
                        MenuAction(
                          icon: AppIcons.send,
                          label: l.checkInQrShare,
                          onSelected: () => _share(context, payload),
                        ),
                        // Everywhere but the browser — see
                        // [isSaveToDeviceSupported].
                        if (isSaveToDeviceSupported)
                          MenuAction(
                            icon: AppIcons.download,
                            label: l.checkInQrSave,
                            onSelected: () => _save(context, payload),
                          ),
                        MenuAction(
                          icon: AppIcons.retry,
                          label: l.checkInQrRotate,
                          isDestructive: true,
                          onSelected: () => _rotate(context),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      fadeThroughRoute(
                        (_) => PlaceCodeScreen(
                          code: code,
                          placeName: placeName,
                          subtitle: subtitle,
                        ),
                      ),
                    ),
                    // White behind the code in both themes: a QR is read by
                    // contrast, and a dark-mode negative is one no phone scans
                    // and no printer reproduces.
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: QrImageView(
                        data: payload,
                        size: 132,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (state.rotatedAt != null)
                  Text(
                    l.checkInQrRotatedAt(formatDate(state.rotatedAt)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                // When the schedule (0114) will do it by itself. Said plainly
                // while it is far off and as a warning once it is near, because
                // the day it happens every printed copy of this code stops
                // working — and the person who can prevent that is the one
                // reading this card.
                if (state.dueAt case final due?) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        AppIcons.pending,
                        size: 16,
                        color: state.isRotatingSoon
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          state.isRotatingSoon
                              ? l.checkInQrRotatesSoon(formatDate(due))
                              : l.checkInQrRotatesOn(formatDate(due)),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: state.isRotatingSoon
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
                // A place with no pin refuses every arrival since 0098. Said
                // here, where somebody who can fix it is standing, rather than
                // left to be found out by a man at the gate.
                if (state.isUnpinned) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(AppIcons.pending, size: 16, color: scheme.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l.checkInQrNoLocation,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
