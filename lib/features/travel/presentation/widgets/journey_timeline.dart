import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_accents.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../domain/journey.dart';
import '../../domain/journey_leg.dart';
import '../../domain/journey_stay.dart';
import '../travel_labels.dart';

/// A man's season drawn as a short stack of PLACES HE LIVED, each card joined
/// to the next by the movement that carried him there.
///
/// The proportions are the point. A season is thirty-five days — about thirty
/// in مكة and five in المدينة — and a few hours of aeroplane and train. So a
/// stay is a card carrying its city, its مسكن and its length, and a movement
/// is a caption inside the card it delivered him to.
///
/// **The movement is folded into the stay.** That is the change this version
/// makes, and it halves the page: the earlier drawing gave a flight its own
/// row on a spine, so a four-stay season was eight blocks of near-identical
/// weight and the eye had nothing to hold on to. But a flight is not a place
/// he went — «وصل بـ SR441 في ٢٥ يوليو» is a fact ABOUT arriving in مكة, and
/// the schema already says so: `stays.arrival_leg_id` names the very leg. One
/// card per place, the flight written inside it in small type, is the same
/// information in half the blocks.
///
/// The exception is a movement that needs somebody to DO something — waiting
/// on his word, running late, or gone wrong. Those keep a card of their own,
/// because being impossible to scroll past is the entire job of that card.
///
/// Two rules still govern every colour, both from 0129:
///
///   * **A movement he arranged himself is drawn exactly like a booked one** —
///     same weight, a car for an icon. «بسيارة خاصة» is a complete answer.
///   * **Absence is never red.** A stay whose مسكن the files have not resolved
///     simply omits the line; a return not yet booked is plain text. Red
///     belongs to `missed` and `cancelled` — movements that happened and went
///     wrong.
class JourneyTimeline extends StatelessWidget {
  const JourneyTimeline({
    super.key,
    required this.journey,
    this.busyLegId,
    this.onConfirm,
    this.onOpenLeg,
  });

  final Journey journey;

  /// The leg mid-write, so its card alone shows a spinner.
  final String? busyLegId;

  /// Offered on a movement waiting for somebody's word. Null when this reader
  /// may not confirm anything — the card then simply states its status.
  final void Function(JourneyLeg leg)? onConfirm;

  final void Function(JourneyLeg leg)? onOpenLeg;

  /// Whether this movement has anything the reader must DO or NOTICE beyond
  /// the plain fact of it. Everything else — the great majority of a season's
  /// legs, which simply happened as planned — is a caption, not a card.
  bool _needsAttention(JourneyLeg leg) =>
      busyLegId == leg.id ||
      (leg.needsManualConfirmation && onConfirm != null) ||
      (leg.isOverdue && onConfirm != null) ||
      leg.status.isFailure;

  @override
  Widget build(BuildContext context) {
    final entries = journey.line;
    if (entries.isEmpty) return const SizedBox.shrink();

    // Walk the line pairing each movement with the stay it delivered him to.
    // [Journey.line] already emits them in that order — the move, then the
    // stop it leads into — and already looked the pairing up by
    // `arrival_leg_id`, so nothing is re-derived here.
    //
    // `reached` travels with each card because the connector ABOVE it is
    // drawn in the mission's green only where he has actually got that far.
    final blocks = <({Widget card, bool reached})>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (entry is JourneyMove) {
        final next = i + 1 < entries.length ? entries[i + 1] : null;
        if (next is JourneyStop && !_needsAttention(entry.leg)) {
          blocks.add((
            card: _StayCard(
              stay: next.stay,
              arrival: entry.leg,
              onOpenLeg: onOpenLeg,
            ),
            reached: !next.stay.isFuture,
          ));
          i++;
          continue;
        }
        blocks.add((
          card: _MoveCard(
            leg: entry.leg,
            busy: busyLegId == entry.leg.id,
            onConfirm: onConfirm,
            onOpen: onOpenLeg,
          ),
          reached: entry.leg.status.isDone,
        ));
        continue;
      }

      if (entry is JourneyStop) {
        blocks.add((
          card: _StayCard(stay: entry.stay, onOpenLeg: onOpenLeg),
          reached: !entry.stay.isFuture,
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) _Connector(reached: blocks[i].reached),
          blocks[i].card,
        ],
      ],
    );
  }
}

/// Where the medallion's centre falls: the card's own padding plus half the
/// medallion. The connector is drawn to this line so the joins run straight
/// down through every card's icon rather than wandering with the text.
const double _medallion = 40;
const double _spineOffset = AppSpacing.lg + _medallion / 2;

/// The line between two cards.
///
/// Short, and it is the whole of what used to be a 44-pixel gutter running the
/// full height of every row inside an [IntrinsicHeight]. The cards carry the
/// content; the line only has to say "and then".
class _Connector extends StatelessWidget {
  const _Connector({required this.reached});

  final bool reached;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: _spineOffset - 1.5),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: reached ? Accent.green.of(context) : scheme.outlineVariant,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}

/// Where he was based: the city, the مسكن, how long — and, in small type at
/// the foot, what carried him here.
class _StayCard extends StatelessWidget {
  const _StayCard({required this.stay, this.arrival, this.onOpenLeg});

  final JourneyStay stay;
  final JourneyLeg? arrival;
  final void Function(JourneyLeg leg)? onOpenLeg;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final green = Accent.green.of(context);

    final icon = switch (stay.kind) {
      StayKind.home => AppIcons.myProfile,
      StayKind.rites => AppIcons.checkIn,
      StayKind.residence => AppIcons.organization,
    };

    // Reached or not, and nothing in between: a city still ahead of him is
    // drawn quiet, a city he has left or is in is drawn in the mission's
    // green. Never red — a stay cannot go wrong, it can only not have
    // happened yet.
    final tone = stay.isFuture ? scheme.onSurfaceVariant : green;
    final nights = stay.nights;

    return GlassCard(
      emphasised: stay.isCurrent,
      tint: stay.isCurrent ? green : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _medallion,
                height: _medallion,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone.withValues(alpha: stay.isPast ? 0.16 : 0.10),
                  border: Border.all(
                    color: tone.withValues(alpha: stay.isCurrent ? 0.9 : 0.24),
                    width: stay.isCurrent ? 2 : 1,
                  ),
                ),
                child: Icon(icon, size: 18, color: tone),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stay.city?.of(context) ?? '—',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: stay.isFuture
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // The مسكن. Never asked for here: nobody types a hotel,
                    // and a stay with none resolved simply omits the line —
                    // that is a fact about the paperwork (0136), not a blank
                    // the traveller should be handed.
                    if (stay.place case final place?) ...[
                      const SizedBox(height: 2),
                      _Line(
                        icon: AppIcons.organization,
                        label: place.of(context),
                      ),
                    ],
                    if (stay.arrivedAt != null) ...[
                      const SizedBox(height: 2),
                      _Line(
                        icon: AppIcons.travelWhen,
                        label: stay.departedAt == null
                            ? l.travelSince(
                                travelWhen(
                                  context,
                                  stay.arrivedAt,
                                  withTime: false,
                                ),
                              )
                            : '${travelWhen(context, stay.arrivedAt, withTime: false)}'
                                  ' — '
                                  '${travelWhen(context, stay.departedAt, withTime: false)}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // How long he was there — the number this whole arrangement
              // exists to put on the page, and the one the chart above ranks
              // the cities by.
              if (nights != null && (nights > 0 || stay.isCurrent))
                GlassBadge(
                  label: stay.isCurrent
                      ? l.travelDaysSoFar(nights)
                      : l.travelDays(nights),
                  color: stay.isCurrent ? green : scheme.onSurfaceVariant,
                  dense: true,
                ),
            ],
          ),
          if (stay.isCurrent) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              // Under the city, not under the medallion: the text column
              // starts past the medallion and the gap after it.
              padding: const EdgeInsetsDirectional.only(
                start: _medallion + AppSpacing.md,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: GlassBadge(
                  label: l.travelHereNow,
                  icon: AppIcons.location,
                  color: green,
                ),
              ),
            ),
          ],
          // What carried him here, in small type at the foot — a detail of
          // the arrival, not a destination. Drawing a terminal as a place he
          // went is exactly what 0135 was written to undo.
          if (arrival case final leg?) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: AppSpacing.sm),
            _ArrivalCaption(leg: leg, onOpen: onOpenLeg),
          ],
        ],
      ),
    );
  }
}

/// «✈ SR441 · مطار دمشق ← مطار الملك عبدالعزيز · وصل ٢٥ يوليو» — one line,
/// and the only place a flight appears when it has nothing to answer for.
class _ArrivalCaption extends StatelessWidget {
  const _ArrivalCaption({required this.leg, this.onOpen});

  final JourneyLeg leg;
  final void Function(JourneyLeg leg)? onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // A flight number when it had one, the plain name of the way he travelled
    // when it did not. A private car gets «برّاً · ترتيب ذاتي» and no empty
    // carrier row.
    final title =
        leg.carrierLabel ??
        (leg.selfArranged
            ? '${travelModeLabel(context, leg.mode)} · ${l.travelSelfArranged}'
            : travelModeLabel(context, leg.mode));

    final at = leg.actualArrivalAt ?? leg.plannedArrivalAt;
    final when = at == null
        ? null
        : l.travelArrivedAt(travelWhen(context, at, withTime: false));

    return InkWell(
      onTap: onOpen == null ? null : () => onOpen!(leg),
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Row(
        children: [
          // The car and the aeroplane are drawn identically. That is the
          // point.
          Icon(
            travelModeIcon(leg.mode),
            size: 15,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              [title, ?when].join(' · '),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// One movement standing on its own — which now happens only when it needs
/// somebody: waiting on his word, running late, or gone wrong.
///
/// It keeps a card of its own and the full account — what carried him, when,
/// the terminals, and the button that closes it out — because being
/// impossible to scroll past is the entire job of this card.
class _MoveCard extends StatelessWidget {
  const _MoveCard({
    required this.leg,
    required this.busy,
    this.onConfirm,
    this.onOpen,
  });

  final JourneyLeg leg;
  final bool busy;
  final void Function(JourneyLeg leg)? onConfirm;
  final void Function(JourneyLeg leg)? onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Red for what happened and went wrong; gold for a question nobody has
    // answered. The two are never swapped — BR-12 is the whole of it.
    final tone = leg.status.isFailure
        ? scheme.error
        : travelPendingColor(context);

    final title =
        leg.carrierLabel ??
        (leg.selfArranged
            ? '${travelModeLabel(context, leg.mode)} · ${l.travelSelfArranged}'
            : travelModeLabel(context, leg.mode));

    final when = leg.actualDepartureAt ?? leg.plannedDepartureAt;
    final from = leg.fromPoint?.of(context);
    final to = leg.toPoint?.of(context);

    return GlassCard(
      tint: tone,
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onOpen == null ? null : () => onOpen!(leg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _medallion,
                height: _medallion,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone.withValues(alpha: 0.12),
                  border: Border.all(color: tone.withValues(alpha: 0.3)),
                ),
                child: Icon(travelModeIcon(leg.mode), size: 18, color: tone),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (from != null && to != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$from ← $to',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    _Line(
                      icon: AppIcons.travelWhen,
                      label: travelWhen(context, when, withTime: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (leg.status.isFailure)
                GlassBadge(
                  label: legStatusLabel(context, leg.status),
                  color: legStatusColor(context, leg.status),
                  dense: true,
                ),
            ],
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (leg.needsManualConfirmation && onConfirm != null) ...[
            const SizedBox(height: AppSpacing.md),
            // Said in words, because it is not obvious: for a private car
            // there IS no airline feed and no gate. If he does not say he
            // arrived, nothing ever will.
            Text(
              l.travelNeedsYourWord,
              style: text.bodySmall?.copyWith(
                color: travelPendingColor(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: () => onConfirm!(leg),
                icon: const Icon(AppIcons.approve, size: 18),
                label: Text(l.travelConfirmArrival),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ] else if (leg.isOverdue && onConfirm != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: () => onConfirm!(leg),
                icon: const Icon(AppIcons.approve, size: 18),
                label: Text(l.travelConfirmArrival),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small icon and a line of quiet text — the shape every secondary fact on
/// a card here takes, so they line up with each other down the page.
class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
