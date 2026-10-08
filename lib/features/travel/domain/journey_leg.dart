import '../../../core/l10n/localized_name.dart';
import 'trip.dart';

/// A fact about ONE MAN on one movement. Mirrors `leg_status` (0129).
///
/// Deliberately a different list from [TripStatus]. The aeroplane landing and
/// this man having been on it are two different claims, and nothing in this
/// feature turns the first into the second automatically — see BR-6.
enum LegStatus {
  /// Booked. Nobody has said anything about it yet.
  planned,

  /// He is going, or he boarded.
  confirmed,

  /// He arrived. **This is the status that moves him on the map** — every
  /// derivation in [Journey] keys off it and no other.
  completed,

  /// He did not travel on it.
  missed,

  /// The movement is off and nothing replaces it.
  cancelled,

  /// Superseded by another leg. Kept, never deleted (BR-5), so that "he was on
  /// SR441 and was moved" survives in the rows themselves.
  rebooked;

  static LegStatus fromDb(String? value) => switch (value) {
    'confirmed' => LegStatus.confirmed,
    'completed' => LegStatus.completed,
    'missed' => LegStatus.missed,
    'cancelled' => LegStatus.cancelled,
    'rebooked' => LegStatus.rebooked,
    _ => LegStatus.planned,
  };

  String get dbName => name;

  /// Whether this leg still stands. The three live statuses are the ones the
  /// unique index counts (BR-10) and the ones the gaps board asks about.
  bool get isLive =>
      this == LegStatus.planned ||
      this == LegStatus.confirmed ||
      this == LegStatus.completed;

  bool get isDone => this == LegStatus.completed;

  /// Whether this is a movement that HAPPENED and went wrong — as opposed to
  /// one that was merely never written down. The distinction is the whole of
  /// BR-12: only these two are ever drawn in red.
  bool get isFailure => this == LegStatus.missed || this == LegStatus.cancelled;

  /// Whether it is still waiting on somebody to say what happened.
  bool get awaitsConfirmation =>
      this == LegStatus.planned || this == LegStatus.confirmed;
}

/// One movement of one participant, with the trip's half and his own half
/// already merged — which is what `employee_journey` (0130) returns.
///
/// [selfArranged] is the flag the whole feature turns on. It means there was no
/// trip behind this movement: he took a private car, or a lift, or anything the
/// mission did not book. It is **not** a missing booking and is never drawn as
/// one. What it does mean is that nothing in the world except the man himself
/// can say whether he arrived — hence [needsManualConfirmation].
class JourneyLeg {
  const JourneyLeg({
    required this.id,
    required this.role,
    required this.mode,
    required this.status,
    required this.selfArranged,
    this.tripId,
    this.fromPointId,
    this.fromPoint,
    this.toPointId,
    this.toPoint,
    this.tripNumber,
    this.plannedDepartureAt,
    this.plannedArrivalAt,
    this.actualDepartureAt,
    this.actualArrivalAt,
    this.vehicleStatus,
    this.ticketRef,
    this.seat,
    this.note,
    this.replacesLegId,
    this.confirmedById,
    this.confirmedByName,
    this.confirmedAt,
    this.attachmentCount = 0,
  });

  final String id;
  final String? tripId;
  final LegRole role;
  final TravelMode mode;
  final LegStatus status;

  /// True when [tripId] is null. A first-class movement, drawn on the timeline
  /// exactly like a flight, with a car for an icon.
  final bool selfArranged;

  final String? fromPointId;
  final LocalizedName? fromPoint;
  final String? toPointId;
  final LocalizedName? toPoint;

  final String? tripNumber;

  /// Resolved by the database: from the trip when there is one, from the leg
  /// when there is not (BR-4). The app never has to ask which.
  final DateTime? plannedDepartureAt;
  final DateTime? plannedArrivalAt;

  /// What actually happened to THIS man. Sixty people share a departure time
  /// and not one of them shares an arrival.
  final DateTime? actualDepartureAt;
  final DateTime? actualArrivalAt;

  /// The vehicle's own status. Null for a self-arranged movement, and that is
  /// the honest answer: a private car has no timetable to be late against.
  final TripStatus? vehicleStatus;

  final String? ticketRef;
  final String? seat;
  final String? note;
  final String? replacesLegId;

  final String? confirmedById;
  final String? confirmedByName;
  final DateTime? confirmedAt;

  final int attachmentCount;

  /// When this movement is reckoned to happen — the actual time once there is
  /// one, the plan until then. What the timeline sorts and dates by.
  DateTime? get effectiveDepartureAt => actualDepartureAt ?? plannedDepartureAt;
  DateTime? get effectiveArrivalAt => actualArrivalAt ?? plannedArrivalAt;

  /// Whether the plan and the event disagree — what makes the UI show the
  /// planned time struck through beside the real one.
  bool get departedLate {
    final planned = plannedDepartureAt;
    final actual = actualDepartureAt;
    if (planned == null || actual == null) return false;
    return actual.difference(planned).abs() >= const Duration(minutes: 15);
  }

  /// Nothing but a person can close this one out. True for a private car, and
  /// for anything else with no vehicle behind it: there is no airline feed, no
  /// gate and no manifest, so the app must ASK rather than wait.
  bool get needsManualConfirmation => selfArranged && status.awaitsConfirmation;

  /// Its hour came and went with nobody saying what happened. Drives the amber
  /// prompt on the timeline and the `unconfirmed` row on the gaps board.
  bool get isOverdue {
    final at = plannedDepartureAt;
    if (at == null || !status.awaitsConfirmation) return false;
    return at.isBefore(DateTime.now());
  }

  /// «SR441», or nothing at all for a private car — which is correct, and is
  /// why the UI must not reserve a row for it.
  String? get carrierLabel =>
      (tripNumber == null || tripNumber!.isEmpty) ? null : tripNumber;

  static JourneyLeg fromRow(Map<String, dynamic> map) => JourneyLeg(
    id: map['leg_id'] as String,
    tripId: map['trip_id'] as String?,
    role: LegRole.fromDb(map['role'] as String?),
    mode: TravelMode.fromDb(map['mode'] as String?),
    status: LegStatus.fromDb(map['status'] as String?),
    selfArranged: (map['self_arranged'] as bool?) ?? map['trip_id'] == null,
    fromPointId: map['from_point_id'] as String?,
    fromPoint: map['from_point_ar'] == null
        ? null
        : LocalizedName(
            ar: map['from_point_ar'] as String,
            en: map['from_point_en'] as String?,
          ),
    toPointId: map['to_point_id'] as String?,
    toPoint: map['to_point_ar'] == null
        ? null
        : LocalizedName(
            ar: map['to_point_ar'] as String,
            en: map['to_point_en'] as String?,
          ),
    tripNumber: map['trip_number'] as String?,
    plannedDepartureAt: _time(map['planned_departure_at']),
    plannedArrivalAt: _time(map['planned_arrival_at']),
    actualDepartureAt: _time(map['actual_departure_at']),
    actualArrivalAt: _time(map['actual_arrival_at']),
    vehicleStatus: map['vehicle_status'] == null
        ? null
        : TripStatus.fromDb(map['vehicle_status'] as String?),
    ticketRef: map['ticket_ref'] as String?,
    seat: map['seat'] as String?,
    note: map['note'] as String?,
    replacesLegId: map['replaces_leg_id'] as String?,
    confirmedById: map['confirmed_by'] as String?,
    confirmedByName: map['confirmed_by_name'] as String?,
    confirmedAt: _time(map['confirmed_at']),
    attachmentCount: (map['attachment_count'] as num?)?.toInt() ?? 0,
  );

  static DateTime? _time(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;
}

/// A self-arranged movement being recorded, before it has an id.
///
/// There is no trip, so this carries its own plan — which is exactly what the
/// one-source rule (BR-4) requires of a leg with no trip behind it.
class SelfLegDraft {
  const SelfLegDraft({
    required this.role,
    required this.mode,
    required this.fromPointId,
    required this.toPointId,
    required this.departureAt,
    this.arrivalAt,
    this.note,
    this.completed = true,
  });

  final LegRole role;
  final TravelMode mode;
  final String fromPointId;
  final String toPointId;
  final DateTime departureAt;
  final DateTime? arrivalAt;
  final String? note;

  /// Whether this already happened. The common case is true — a man records the
  /// drive to المدينة after making it, not before — so the sheet defaults to it.
  final bool completed;
}
