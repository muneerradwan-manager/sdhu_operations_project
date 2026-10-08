import 'package:flutter/material.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/blocking_progress.dart';
import '../../../core/widgets/creator_page.dart';
import '../../../core/widgets/glass.dart';
import '../application/check_in_cubit.dart';
import '../domain/check_in.dart';
import 'scan_check_in_screen.dart';

/// Reporting that you have arrived somewhere.
///
/// Outside the operational files, and that is the whole shape of it. Presence
/// used to be a fact about a file — the sheet opened from the file page, and
/// what it recorded was "somebody arrived at the file". A place stopped being
/// part of a file in 0095, and this followed in 0098: what is recorded is that
/// a man was at a HOTEL or a CAMP, which is true whoever asks and whichever
/// file happens to mention it this season.
///
/// One way in, deliberately. The old sheet had two buttons — scan, or say you
/// are here — and the second is what made the register worth doubting. There is
/// no "I am here" now: the code proves you are looking at the sticker and the
/// position proves the sticker is not in your pocket, and neither alone proves
/// anything.
///
/// Opened from «سجلّ حضوري» and from nowhere else, the way the task editor is
/// opened from «مهامي» — it is that list's [CreatorPage], and it pops `true`
/// onto it when an arrival was filed. The link the other way, an icon in this
/// bar pointing at the record, is gone with the reason for it: the record is no
/// longer somewhere else, it is what is underneath.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final code = await Navigator.of(context).push<PlaceCode>(
      MaterialPageRoute(builder: (_) => const ScanCheckInScreen()),
    );
    if (code == null || !mounted) return;

    // Sealed while it runs: taking a fix can take a few seconds outdoors, and a
    // second press in that gap would file the arrival twice.
    final result = await runBlocking(
      context,
      () => CheckIn.arrive(
        code: code,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
      message: l.checkInTitle,
    );
    if (!mounted) return;

    final message = switch (result) {
      (outcome: final o, receipt: final r?) when o.ok => l.checkInDoneAt(
        r.placeName,
        r.distanceM.round().toString(),
      ),
      (outcome: final o, receipt: _) when o.queued => l.checkInQueued,
      (outcome: final o, receipt: _) when o.ok => l.checkInDone,
      (outcome: final o, receipt: _) => friendlyErrorL(l, o.error),
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

    // Only on success. A refused arrival leaves the note where it was, because
    // he is about to try again and retyping it is the small insult on top.
    //
    // `true` is the whole contract with the list underneath: it reloads, and
    // the line just written is the first thing on it. A queued arrival is `ok`
    // too — the man's part is finished either way, and keeping him on this
    // page over a signal problem invites the second scan that files it twice.
    if (result.outcome.ok) {
      _note.clear();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    // Reachable directly by URL, so it answers for itself rather than trusting
    // the list to have hidden its button — see [isPlaceScannerSupported].
    final canScan = isPlaceScannerSupported;

    return CreatorPage(
      title: l.checkInTitle,
      submitLabel: l.checkInScan,
      submitIcon: AppIcons.qrCode,
      onSubmit: canScan ? _scan : null,
      children: [
        FadeSlideIn(
          child: GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  AppIcons.qrCode,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  canScan ? l.checkInSubtitle : l.checkInPhoneOnly,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        // No note field where there is nothing to attach it to. It is the
        // second half of an act whose first half cannot happen here.
        if (canScan) ...[
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _note,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l.checkInNoteHint),
          ),
        ],
      ],
    );
  }
}
