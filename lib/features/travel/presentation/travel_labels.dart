import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_icons.dart';
import '../data/travel_repository.dart';
import '../domain/journey_leg.dart';
import '../domain/trip.dart';

/// How this feature says things, in one file, because four screens say most of
/// them and drift is what happens when they each say it themselves.
///
/// The colour rules here are the whole of BR-12 made concrete, and they are the
/// part of this feature most easily got wrong:
///
///   **Absence is never red.** A movement that was never recorded is not a
///   failure — most often it is the airport coach, which nobody tracks and
///   nobody needs to. Red belongs to `missed` and `cancelled`: to things that
///   HAPPENED and went badly. Everything merely unwritten is drawn in the
///   ordinary text colour with a button beside it, and «لم تُحدَّد رحلة العودة
///   بعد» is a plain sentence, not a warning.

IconData travelModeIcon(TravelMode mode) => switch (mode) {
  TravelMode.air => AppIcons.travelAir,
  TravelMode.rail => AppIcons.travelRail,
  TravelMode.road => AppIcons.travelRoad,
  TravelMode.other => AppIcons.travelOther,
};

String travelModeLabel(BuildContext context, TravelMode mode) {
  final l = context.l10n;
  return switch (mode) {
    TravelMode.air => l.travelModeAir,
    TravelMode.rail => l.travelModeRail,
    TravelMode.road => l.travelModeRoad,
    TravelMode.other => l.travelModeOther,
  };
}

String legRoleLabel(BuildContext context, LegRole role) {
  final l = context.l10n;
  return switch (role) {
    LegRole.inbound => l.travelRoleInbound,
    LegRole.internal => l.travelRoleInternal,
    LegRole.outbound => l.travelRoleOutbound,
  };
}

IconData legRoleIcon(LegRole role) => switch (role) {
  LegRole.inbound => AppIcons.travelAir,
  LegRole.internal => AppIcons.travel,
  LegRole.outbound => AppIcons.travelReturn,
};

/// The three parts of a season, each with its own accent so the board can be
/// read by colour before it is read by word.
Accent legRoleAccent(LegRole role) => switch (role) {
  LegRole.inbound => Accent.green,
  LegRole.internal => Accent.gold,
  LegRole.outbound => Accent.plum,
};

String legStatusLabel(BuildContext context, LegStatus status) {
  final l = context.l10n;
  return switch (status) {
    LegStatus.planned => l.travelLegPlanned,
    LegStatus.confirmed => l.travelLegConfirmed,
    LegStatus.completed => l.travelLegCompleted,
    LegStatus.missed => l.travelLegMissed,
    LegStatus.cancelled => l.travelLegCancelled,
    LegStatus.rebooked => l.travelLegRebooked,
  };
}

/// The colour of a movement's state.
///
/// Note what is NOT red: `planned` and `confirmed` are the ordinary
/// muted-text colour even when their hour has passed. A movement waiting on
/// somebody's word is a question, and a question is amber at its loudest —
/// see [travelPendingColor].
Color legStatusColor(BuildContext context, LegStatus status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    LegStatus.completed => Accent.green.of(context),
    LegStatus.confirmed => Accent.greenDeep.of(context),
    LegStatus.missed || LegStatus.cancelled => scheme.error,
    LegStatus.rebooked => scheme.onSurfaceVariant,
    LegStatus.planned => scheme.onSurfaceVariant,
  };
}

/// What an unanswered question is drawn in: gold, never the error colour.
/// «its hour passed and nobody said» is something to ask about, not something
/// that has gone wrong.
Color travelPendingColor(BuildContext context) => Accent.gold.of(context);

String tripStatusLabel(BuildContext context, TripStatus status) {
  final l = context.l10n;
  return switch (status) {
    TripStatus.scheduled => l.travelTripScheduled,
    TripStatus.delayed => l.travelTripDelayed,
    TripStatus.departed => l.travelTripDeparted,
    TripStatus.arrived => l.travelTripArrived,
    TripStatus.cancelled => l.travelTripCancelled,
  };
}

Color tripStatusColor(BuildContext context, TripStatus status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    TripStatus.scheduled => scheme.onSurfaceVariant,
    TripStatus.delayed => Accent.gold.of(context),
    TripStatus.departed => Accent.greenDeep.of(context),
    TripStatus.arrived => Accent.green.of(context),
    TripStatus.cancelled => scheme.error,
  };
}

String travelGapLabel(BuildContext context, TravelGapKind kind) {
  final l = context.l10n;
  return switch (kind) {
    TravelGapKind.noInbound => l.travelGapNoInbound,
    TravelGapKind.noOutbound => l.travelGapNoOutbound,
    TravelGapKind.unconfirmed => l.travelGapUnconfirmed,
    TravelGapKind.cancelledTrip => l.travelGapCancelledTrip,
  };
}

/// Only one kind of gap is an actual failure: a man still booked on a flight
/// that has been cancelled. The other three are questions.
Color travelGapColor(BuildContext context, TravelGapKind kind) =>
    kind == TravelGapKind.cancelledTrip
    ? Theme.of(context).colorScheme.error
    : travelPendingColor(context);

IconData travelGapIcon(TravelGapKind kind) => switch (kind) {
  TravelGapKind.noInbound => AppIcons.travelAir,
  TravelGapKind.noOutbound => AppIcons.travelReturn,
  TravelGapKind.unconfirmed => AppIcons.pending,
  TravelGapKind.cancelledTrip => AppIcons.warning,
};

/// «30 أبريل · 02:15» — when a movement happens.
///
/// Gregorian and localized, which is what every other date in this app shows
/// (`intl` with the active locale). The Hijri calendar is used here only where
/// it is used everywhere else — for naming a SEASON — because a flight is
/// booked, printed on a ticket and announced by an airline in the Gregorian
/// one, and a departure time that disagreed with the boarding pass beside it
/// would be worse than useless.
///
/// The year is dropped unless the date is not in the current one: a season runs
/// inside a few weeks, and «30 أبريل 2026» is three characters of noise on
/// every row of the board.
String travelWhen(BuildContext context, DateTime? at, {bool withTime = true}) {
  if (at == null) return '—';
  final locale = Localizations.localeOf(context).toString();
  final pattern = at.year == DateTime.now().year ? 'd MMMM' : 'd MMMM y';
  final date = DateFormat(pattern, locale).format(at);
  if (!withTime) return date;
  return '$date · ${TimeOfDay.fromDateTime(at).format(context)}';
}
