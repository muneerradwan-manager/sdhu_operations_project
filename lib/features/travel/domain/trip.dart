import '../../../core/l10n/localized_name.dart';
import 'journey_leg.dart';

/// What carries a movement. Mirrors `travel_mode` (0129).
///
/// Adding one is a three-line migration and one arm of [travelModeIcon] — that
/// is the whole cost, and it is the reason this feature does not have a table
/// per kind of journey.
enum TravelMode {
  air,
  rail,
  road,
  other;

  static TravelMode fromDb(String? value) => switch (value) {
    'air' => TravelMode.air,
    'rail' => TravelMode.rail,
    'road' => TravelMode.road,
    _ => TravelMode.other,
  };

  String get dbName => name;
}

/// What a movement is FOR, which is not the same as what carries it: the return
/// may be a flight one year and something else the next, and it is still the
/// return. Mirrors `leg_role` (0129).
enum LegRole {
  /// Home to the Kingdom. The journey opens with it.
  inbound,

  /// Inside the Kingdom — مكة to المدينة and back. May happen any number of
  /// times, or not at all, and neither is a defect.
  internal,

  /// The Kingdom to home. The one the countdown counts to.
  outbound;

  static LegRole fromDb(String? value) => switch (value) {
    'inbound' => LegRole.inbound,
    'outbound' => LegRole.outbound,
    _ => LegRole.internal,
  };

  String get dbName => name;

  /// Whether at most one of these may be live at a time (BR-10). An internal
  /// movement repeats; the two bookends do not.
  bool get isBookend => this != LegRole.internal;
}

/// A fact about the VEHICLE, shared by everybody on it. Mirrors `trip_status`.
///
/// Deliberately a different list from [LegStatus]: an aeroplane can land with
/// everybody aboard except one man, and `arrived` here must never be able to
/// say anything about him. See BR-6.
enum TripStatus {
  scheduled,
  delayed,
  departed,
  arrived,
  cancelled;

  static TripStatus fromDb(String? value) => switch (value) {
    'delayed' => TripStatus.delayed,
    'departed' => TripStatus.departed,
    'arrived' => TripStatus.arrived,
    'cancelled' => TripStatus.cancelled,
    _ => TripStatus.scheduled,
  };

  String get dbName => name;

  bool get isCancelled => this == TripStatus.cancelled;
}

/// What sort of place a travel point is. Mirrors the `point_kind` field held to
/// its three values by the trigger in 0133.
enum TravelPointKind {
  airport,
  station,
  city;

  static TravelPointKind fromDb(String? value) => switch (value) {
    'airport' => TravelPointKind.airport,
    'station' => TravelPointKind.station,
    _ => TravelPointKind.city,
  };
}

/// Somewhere a journey touches the ground: an airport, a station, a city.
///
/// An entry of the `travel_points` reference list, which is why adding one
/// needs no migration and no code — a row in master data and it is in every
/// picker in the feature.
class TravelPoint {
  const TravelPoint({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.kind,
    this.city,
  });

  final String id;
  final LocalizedName name;

  /// `SY` or `SA`. Held to those two by a trigger (0133), because the app
  /// reasons about it: a value miskept as `SAU` would silently drop مطار الملك
  /// عبدالعزيز out of every arrival form.
  final String countryCode;

  final TravelPointKind kind;

  /// Which city it is in, so a journey can be read as a line of PLACES rather
  /// than a line of terminals — and, since 0133, what decides whether a point
  /// may stand at either end of a تنقّل داخلي.
  final String? city;

  bool get isSyrian => countryCode == 'SY';
  bool get isSaudi => countryCode == 'SA';
  bool get isAirport => kind == TravelPointKind.airport;

  static TravelPoint fromMap(Map<String, dynamic> map) {
    final data = (map['data'] as Map<String, dynamic>?) ?? const {};
    return TravelPoint(
      id: map['id'] as String,
      name: LocalizedName.fromMap(map),
      countryCode: (data['country_code'] as String?) ?? '',
      kind: TravelPointKind.fromDb(data['point_kind'] as String?),
      city: data['city'] as String?,
    );
  }
}

/// One vehicle and its schedule, within one season.
///
/// Knows nothing about who is on it — that is [JourneyLeg]. It exists before
/// anybody is assigned, which is exactly what makes bulk assignment possible:
/// the room enters the flight once and then puts sixty people on it.
class Trip {
  const Trip({
    required this.id,
    required this.seasonId,
    required this.mode,
    required this.role,
    required this.fromPointId,
    required this.fromPoint,
    required this.toPointId,
    required this.toPoint,
    required this.plannedDepartureAt,
    required this.status,
    this.tripNumber,
    this.plannedArrivalAt,
    this.note,
    this.assignedCount = 0,
    this.completedCount = 0,
    this.attachmentCount = 0,
  });

  final String id;
  final String seasonId;
  final TravelMode mode;
  final LegRole role;

  final String fromPointId;
  final LocalizedName fromPoint;
  final String toPointId;
  final LocalizedName toPoint;

  /// «SR441». The number is what identifies a flight — it is what the ticket
  /// prints, what the airport board shows and what the office says out loud.
  /// The operating airline was a second field here until 0134 and earned its
  /// removal: the room asks which flight, never which company.
  final String? tripNumber;

  /// Never null, and that is what defines a trip: it is a SCHEDULED departure.
  /// A movement whose time is unknown is an intention, and the schema refuses
  /// to record it as a trip — see 0129.
  final DateTime plannedDepartureAt;
  final DateTime? plannedArrivalAt;

  final TripStatus status;
  final String? note;

  /// Live passengers — those moved off it are not counted. The number the board
  /// lives by: a flight is interesting when it is full and alarming when it is
  /// empty two days out.
  final int assignedCount;

  /// How many of them have been confirmed as having actually arrived.
  final int completedCount;

  final int attachmentCount;

  /// «SR441», or nothing at all — a coach laid on by the office has no number
  /// and should not be given an empty row where one would be.
  String? get label =>
      (tripNumber == null || tripNumber!.isEmpty) ? null : tripNumber;

  bool get hasDeparted =>
      status == TripStatus.departed || status == TripStatus.arrived;

  /// Whether anybody is still waiting on this one. Drives the "N passengers
  /// unconfirmed" prompt the board offers after a flight lands — an OFFER, and
  /// never a write (BR-6).
  int get unconfirmedCount => assignedCount - completedCount;

  static Trip fromRow(Map<String, dynamic> map) => Trip(
    id: map['id'] as String,
    seasonId: map['season_id'] as String,
    mode: TravelMode.fromDb(map['mode'] as String?),
    role: LegRole.fromDb(map['role'] as String?),
    fromPointId: (map['from_point_id'] as String?) ?? '',
    fromPoint: LocalizedName(
      ar: (map['from_point_ar'] as String?) ?? '',
      en: map['from_point_en'] as String?,
    ),
    toPointId: (map['to_point_id'] as String?) ?? '',
    toPoint: LocalizedName(
      ar: (map['to_point_ar'] as String?) ?? '',
      en: map['to_point_en'] as String?,
    ),
    tripNumber: map['trip_number'] as String?,
    plannedDepartureAt:
        DateTime.tryParse(
          map['planned_departure_at'] as String? ?? '',
        )?.toLocal() ??
        DateTime.now(),
    plannedArrivalAt: DateTime.tryParse(
      map['planned_arrival_at'] as String? ?? '',
    )?.toLocal(),
    status: TripStatus.fromDb(map['status'] as String?),
    note: map['note'] as String?,
    assignedCount: (map['assigned_count'] as num?)?.toInt() ?? 0,
    completedCount: (map['completed_count'] as num?)?.toInt() ?? 0,
    attachmentCount: (map['attachment_count'] as num?)?.toInt() ?? 0,
  );
}

/// A trip being written, before it has an id.
class TripDraft {
  const TripDraft({
    required this.mode,
    required this.role,
    required this.fromPointId,
    required this.toPointId,
    required this.plannedDepartureAt,
    this.tripNumber,
    this.plannedArrivalAt,
    this.note,
  });

  final TravelMode mode;
  final LegRole role;
  final String fromPointId;
  final String toPointId;
  final DateTime plannedDepartureAt;

  /// «SR441». The number is what identifies a flight — it is what the ticket
  /// prints, what the airport board shows and what the office says out loud.
  /// The operating airline was a second field here until 0134 and earned its
  /// removal: the room asks which flight, never which company.
  final String? tripNumber;
  final DateTime? plannedArrivalAt;
  final String? note;

  Map<String, dynamic> toInsert(String seasonId) => {
    'season_id': seasonId,
    'mode': mode.dbName,
    'role': role.dbName,
    'from_point_id': fromPointId,
    'to_point_id': toPointId,
    'trip_number': _trimmed(tripNumber),
    // UTC on the wire, always — §1.1 of the backend contract.
    'planned_departure_at': plannedDepartureAt.toUtc().toIso8601String(),
    'planned_arrival_at': plannedArrivalAt?.toUtc().toIso8601String(),
    'note': _trimmed(note),
  };

  static String? _trimmed(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}

/// One passenger on a trip, as the manifest reads it back.
class TripPassenger {
  const TripPassenger({
    required this.legId,
    required this.participantId,
    required this.profileId,
    required this.fullName,
    required this.status,
    this.photoUrl,
    this.jobTitle,
    this.ticketRef,
    this.seat,
    this.actualDepartureAt,
    this.actualArrivalAt,
    this.confirmedAt,
  });

  final String legId;
  final String participantId;
  final String profileId;
  final String fullName;
  final String? photoUrl;
  final LocalizedName? jobTitle;
  final LegStatus status;
  final String? ticketRef;
  final String? seat;
  final DateTime? actualDepartureAt;
  final DateTime? actualArrivalAt;
  final DateTime? confirmedAt;

  bool get isConfirmed => confirmedAt != null;

  static TripPassenger fromRow(Map<String, dynamic> map) => TripPassenger(
    legId: map['leg_id'] as String,
    participantId: map['participant_id'] as String,
    profileId: map['profile_id'] as String,
    fullName: (map['full_name'] as String?) ?? '',
    photoUrl: map['photo_url'] as String?,
    jobTitle: map['job_title_ar'] == null
        ? null
        : LocalizedName(
            ar: map['job_title_ar'] as String,
            en: map['job_title_en'] as String?,
          ),
    status: LegStatus.fromDb(map['status'] as String?),
    ticketRef: map['ticket_ref'] as String?,
    seat: map['seat'] as String?,
    actualDepartureAt: DateTime.tryParse(
      map['actual_departure_at'] as String? ?? '',
    )?.toLocal(),
    actualArrivalAt: DateTime.tryParse(
      map['actual_arrival_at'] as String? ?? '',
    )?.toLocal(),
    confirmedAt: DateTime.tryParse(
      map['confirmed_at'] as String? ?? '',
    )?.toLocal(),
  );
}
