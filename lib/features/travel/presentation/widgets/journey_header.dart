import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_accents.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../domain/journey.dart';
import '../travel_labels.dart';

/// The four things a man wants from this screen before he reads anything else:
/// where he is, how long he has been there, when he goes home, and how far
/// through it he is.
///
/// The return line is the one to be careful with. For most of a season it says
/// «لم تُحدَّد رحلة العودة بعد», and that is the ordinary, expected state — a
/// charter return is booked days before it flies. It is therefore set in the
/// plain muted text colour with no icon of alarm: a man who opens the app on
/// the eighth of ذو القعدة and is shown a warning about his return has been
/// told something false about his own situation.
class JourneyHeader extends StatelessWidget {
  const JourneyHeader({super.key, required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final green = Accent.green.of(context);

    final place = journey.currentPlace?.of(context);
    final headline = journey.isHome
        ? l.travelJourneyComplete
        : !journey.hasDeparted
        ? l.travelNotDepartedYet
        : place == null
        ? l.travelNotDepartedYet
        : l.travelCurrentlyIn(place);

    return GlassCard(
      emphasised: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.location, size: 20, color: green),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  headline,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          // The مسكن under the city. This is the line the room actually wants —
          // «مكة المكرمة» says which half of the season he is in, «فندق الصفوة»
          // says where to find him tonight.
          if (journey.currentResidence case final residence?) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 28),
              child: Row(
                children: [
                  Icon(
                    AppIcons.organization,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      residence.of(context),
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          // Stacked rather than run together on one line: two short facts
          // beside each other — one of them sometimes bold and gold with an
          // urgent countdown — read as a cluttered line when they share it.
          // Each on its own row is the same two facts, just given room to be
          // read one at a time instead of raced through together.
          Wrap(
            direction: Axis.vertical,
            spacing: AppSpacing.sm,
            children: [
              if (journey.daysInCurrentStay case final days?
                  when days > 0 && journey.currentStay?.kind.isHoused == true)
                _Fact(icon: AppIcons.travelWhen, label: l.travelDaysSoFar(days))
              else if (journey.dayOfJourney case final day? when day > 0)
                _Fact(icon: AppIcons.travelWhen, label: l.travelDayOf(day)),
              _ReturnFact(journey: journey),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: journey.progress,
              minHeight: 6,
              backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(green),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnFact extends StatelessWidget {
  const _ReturnFact({required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    if (journey.isHome) return const SizedBox.shrink();

    final days = journey.daysToReturn;
    if (days == null) {
      // Not booked. A statement, not a warning — see the class comment.
      return _Fact(
        icon: AppIcons.travelReturn,
        label: l.travelNoReturnYet,
        muted: true,
      );
    }

    final label = switch (days) {
      < 0 => l.travelReturnPassed,
      0 => l.travelReturnToday,
      1 => l.travelReturnTomorrow,
      _ => l.travelReturnIn(days),
    };

    // Inside two days the countdown is the most important thing on the page,
    // so it stops being one fact among several and takes a colour. This is the
    // same 48-hour threshold the server sends its reminder at (0131), and they
    // agree deliberately: a man told by a notification and then shown a plain
    // grey line would think the app disagreed with itself.
    final urgent = days <= 2;
    return _Fact(
      icon: AppIcons.travelReturn,
      label: label,
      color: urgent ? Accent.gold.of(context) : null,
      strong: urgent,
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    this.color,
    this.muted = false,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final bool muted;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = color ?? (muted ? scheme.onSurfaceVariant : scheme.onSurface);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: tone),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tone,
            fontWeight: strong ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
  }
}

/// The journey squeezed onto one line, for the employee page and anywhere else
/// that has room for a summary and not for a timeline.
class JourneyStrip extends StatelessWidget {
  const JourneyStrip({super.key, required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final legs = journey.legs;
    if (legs.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < legs.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: legs[i - 1].status.isDone
                    ? Accent.green.of(context)
                    : scheme.outlineVariant,
              ),
            ),
          Icon(
            travelModeIcon(legs[i].mode),
            size: 18,
            color: legs[i].status.isDone
                ? Accent.green.of(context)
                : legs[i].status.isFailure
                ? scheme.error
                : scheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }
}
