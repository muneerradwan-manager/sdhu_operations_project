import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/notifications/alarm_sound.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../application/incident_alarm.dart';

/// Puts the urgent-report alarm on screen, wherever the reader happens to be.
///
/// It sits in `MaterialApp.router`'s builder rather than on any page, and that
/// is the whole point: an emergency is not something you have to be looking at
/// the right screen to be told about. The dialog is opened on the ROOT
/// navigator through the router's own key — the builder's context is above
/// every Navigator in the app, so there is nothing there to `showDialog` on.
///
/// Draws nothing itself. [child] passes straight through.
class IncidentAlarmHost extends StatefulWidget {
  const IncidentAlarmHost({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<IncidentAlarmHost> createState() => _IncidentAlarmHostState();
}

class _IncidentAlarmHostState extends State<IncidentAlarmHost> {
  final _alarm = IncidentAlarm.instance;

  /// One dialog at a time. Reports that arrive while it is up join the queue
  /// behind it and are counted in its subtitle, rather than stacking a second
  /// dialog on top of the first — which would need two dismissals for one look,
  /// and leave the alarm sounding behind a dialog already answered.
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _alarm.pending.addListener(_onPending);
  }

  @override
  void dispose() {
    _alarm.pending.removeListener(_onPending);
    super.dispose();
  }

  void _onPending() {
    if (!mounted || _showing) return;
    if (_alarm.pending.value.isEmpty) return;
    // After the frame: this fires from a stream callback that can land mid-build
    // (the inbox snapshot arrives while the first page is still laying out), and
    // pushing a route during a build is an assertion, not a dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  Future<void> _show() async {
    if (_showing) return;
    final alerts = _alarm.pending.value;
    if (alerts.isEmpty) return;

    _showing = true;
    await AlarmSoundBridge.instance.start();

    // Taken AFTER the sound, not before: the platform call is an await, and a
    // navigator read across it is a context that may have gone. Read here, it
    // is the one the dialog is about to be put on.
    final navigator = widget.router.routerDelegate.navigatorKey.currentContext;
    if (!mounted || navigator == null || !navigator.mounted) {
      await AlarmSoundBridge.instance.stop();
      _showing = false;
      return;
    }

    final open = await showDialog<bool>(
      context: navigator,
      // Nothing gets past it. A barrier tap and the back gesture both dismiss
      // an ordinary dialog, and both are things a person does without reading —
      // which for this dialog means silencing an emergency by reflex.
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: _AlarmDialog(alerts: alerts),
      ),
    );

    await AlarmSoundBridge.instance.stop();
    _alarm.clear();
    _showing = false;

    if (open ?? false) widget.router.push(Routes.incidents);

    // Anything that arrived while it was up: ring again, once, for those.
    if (_alarm.pending.value.isNotEmpty) unawaited(_show());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Deliberately loud, and deliberately not glass.
///
/// Every other surface in this app is translucent and quiet. This one is drawn
/// in the error colour on an opaque card with a filled icon at the top, because
/// it has to be recognisable across a room from somebody who has not read a word
/// of it yet.
class _AlarmDialog extends StatelessWidget {
  const _AlarmDialog({required this.alerts});

  final List<IncidentAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final first = alerts.first;

    return AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: .15),
          shape: BoxShape.circle,
        ),
        child: Icon(AppIcons.warning, size: 32, color: scheme.error),
      ),
      title: Text(
        l.incidentAlarmTitle,
        textAlign: TextAlign.center,
        style: text.titleLarge?.copyWith(color: scheme.error),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The body the database wrote: who sent it, where he was, and the
          // first hundred and twenty characters of what he said. That line is
          // the only thing here somebody can act on without opening anything.
          Text(
            first.body?.trim().isNotEmpty ?? false ? first.body! : first.title,
            textAlign: TextAlign.center,
            style: text.bodyLarge,
          ),
          if (alerts.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.incidentAlarmMore(alerts.length - 1),
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        // The way out, which the reader asked for and which every alarm needs:
        // the man woken by this may be four hours' drive away and the wrong
        // person entirely, and a dialog he cannot close is one he silences by
        // force-quitting the app — which is how he stops receiving the next one.
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.incidentAlarmDismiss),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: scheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(AppIcons.warning, size: 18),
          label: Text(l.incidentAlarmOpen),
        ),
      ],
    );
  }
}
