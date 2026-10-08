import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_accents.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/info_section.dart';
import '../../application/prayer_alerts_cubit.dart';
import '../../data/prayer_notifications.dart';
import '../../domain/prayer_alerts.dart';
import '../../domain/prayer_day.dart';
import '../../domain/prayer_text.dart';

/// Puts one [PrayerAlertsCubit] over everything below it, so the page laying
/// the pane out does not have to know what state it reads.
class PrayerAlertsScope extends StatelessWidget {
  const PrayerAlertsScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (_) => PrayerAlertsCubit(), child: child);
}

/// What the phone announces: the switch, which prayers, and how long before.
///
/// Must sit under a [PrayerAlertsScope], and only where [available].
class PrayerAlertsSection extends StatelessWidget {
  const PrayerAlertsSection({super.key});

  /// Whether this platform can announce a prayer at all.
  ///
  /// Dropped rather than shown-and-explained: a pane whose every control is
  /// dead is not made honest by a line of text under it, it is just a dead
  /// pane with a caption. A reader on Windows is better served by a settings
  /// page that offers only what Windows can do.
  ///
  /// Pure, and asked before the pane is built — see
  /// [PrayerNotifications.supported].
  static bool get available => PrayerNotifications.supported;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<PrayerAlertsCubit>();
    final state = context.watch<PrayerAlertsCubit>().state;
    final alerts = state.alerts;

    return InfoSection(
      title: l.prayerAlertsTitle,
      icon: AppIcons.prayerTimes,
      // One column: this pane is a switch followed by things that only make
      // sense underneath it, and a grid would set the answers beside the
      // question they belong to.
      maxColumns: 1,
      // And no rules between them, for the same reason. At one column every
      // child below is its own row, so the pane came out with a hairline
      // between the master switch and the notice under it, between each label
      // and the chips it labels, and on both sides of the two spacers — seven
      // lines through what is one continuous setting.
      separated: false,
      children: [
        SwitchListTile(
          value: alerts.enabled,
          contentPadding: EdgeInsets.zero,
          title: Text(l.prayerAlertsEnable),
          subtitle: _hint(context, l.prayerAlertsHint),
          onChanged:
              state.loaded &&
                  state.readiness != PrayerAlertReadiness.unsupported
              ? cubit.setEnabled
              : null,
        ),

        // Said whether or not the switch is on, and the only notice that is.
        //
        // Where the system cannot announce anything the switch can never BE on
        // — [PrayerAlertsCubit.setEnabled] forces it back off — so a line shown
        // only underneath a live switch is one nobody in that state can ever
        // read. A platform that cannot do this at all does not reach here now
        // ([available] keeps the whole pane off the page); what is left for
        // this line is the device that says it is Android and then resolves no
        // plugin, which would otherwise be a switch that bounces in silence.
        if (state.readiness == PrayerAlertReadiness.unsupported)
          _Notice(
            message: l.prayerAlertsUnsupported,
            tone: Theme.of(context).colorScheme.onSurfaceVariant,
          ),

        // Everything below only exists while the switch is on. It is removed
        // rather than greyed out: a disabled row of five prayers invites the
        // reader to press it and learn nothing.
        if (alerts.enabled) ...[
          ?_notice(context, state),
          const SizedBox(height: AppSpacing.sm),
          _Label(l.prayerAlertsWhich), //
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final slot in PrayerSlot.values)
                if (slot.isPrayer)
                  FilterChip(
                    label: Text(slotName(l, slot)),
                    selected: alerts.announcing(slot),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => cubit.toggleSlot(slot),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Label(l.prayerAlertsBefore),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final minutes in PrayerAlerts.reminderChoices)
                ChoiceChip(
                  label: Text(
                    minutes == 0
                        ? l.prayerAlertsBeforeOff
                        : l.prayerAlertsMinutes(minutes),
                  ),
                  selected: alerts.reminderMinutes == minutes,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => cubit.setReminderMinutes(minutes),
                ),
            ],
          ),
          SwitchListTile(
            value: alerts.silent,
            contentPadding: EdgeInsets.zero,
            title: Text(l.prayerAlertsSilent),
            subtitle: _hint(context, l.prayerAlertsSilentHint),
            onChanged: cubit.setSilent,
          ),
        ],
      ],
    );
  }

  /// The one thing standing between this switch and a phone that actually goes
  /// off, when there is one. At most one is ever shown, worst first.
  Widget? _notice(BuildContext context, PrayerAlertsState state) {
    final l = context.l10n;
    return switch (state.readiness) {
      PrayerAlertReadiness.blocked => _Notice(
        message: l.prayerAlertsBlocked,
        tone: Accent.red.of(context),
      ),
      // Shown above the switch instead of under it, because it is the one
      // notice that has to survive the switch being off. See the note there.
      PrayerAlertReadiness.unsupported => null,
      // A position is worth more than an exact alarm: without one nothing is
      // announced at all, where an inexact alarm is only late.
      _ when !state.locatable => _Notice(
        message: l.prayerAlertsNeedLocation,
        tone: Accent.gold.of(context),
      ),
      PrayerAlertReadiness.inexact => _Notice(
        message: l.prayerAlertsInexact,
        tone: Accent.gold.of(context),
        action: l.prayerAlertsGrantExact,
        onAction: context.read<PrayerAlertsCubit>().grantExactAlarms,
      ),
      PrayerAlertReadiness.ready => null,
    };
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// A line saying what will not work, and — where there is one — the button that
/// fixes it.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.message,
    required this.tone,
    this.action,
    this.onAction,
  });

  final String message;
  final Color tone;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.warning, size: 16, color: tone),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
          if (action != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: tone),
                child: Text(action!),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _hint(BuildContext context, String text) => Text(
  text,
  style: Theme.of(context).textTheme.bodySmall?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    height: 1.35,
  ),
);
