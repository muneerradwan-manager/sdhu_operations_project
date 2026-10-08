import '../../../core/l10n/localized_name.dart';

/// What sort of stay it is. Mirrors `stay_kind` (0135).
enum StayKind {
  /// Syria, before he leaves and after he returns.
  home,

  /// A hotel or a camp: where he is based for weeks at a time. The ordinary
  /// case, and the great majority of a season by any measure.
  residence,

  /// المشاعر — منى, عرفات, مزدلفة. Days rather than weeks, and a different kind
  /// of thing from a hotel: he is there for the rites, not based there.
  rites;

  static StayKind fromDb(String? value) => switch (value) {
    'home' => StayKind.home,
    'rites' => StayKind.rites,
    _ => StayKind.residence,
  };

  String get dbName => name;

  /// Whether this is somewhere the mission houses him — as against his own
  /// country at either end of the line.
  bool get isHoused => this != StayKind.home;
}

/// Where a man is BASED, and for how long.
///
/// The spine of a season. A journey is thirty-five days, and all but a few
/// hours of it are spent in one of these — the legs (0129) are what carry him
/// between them. The terminals a flight runs through are details of the flight,
/// not places he goes: he lands at مطار الملك عبدالعزيز and lives in مكة.
///
/// [place] is a `reference_items` row from a list somebody has declared to be
/// places (0098) — the same id `place_check_ins` points at, which is why
/// [checkInCount] can be answered without either feature knowing about the
/// other.
class JourneyStay {
  const JourneyStay({
    required this.id,
    required this.kind,
    this.cityItemId,
    this.city,
    this.placeItemId,
    this.place,
    this.arrivedAt,
    this.departedAt,
    this.arrivalLegId,
    this.departureLegId,
    this.note,
    this.nights,
    this.checkInCount = 0,
  });

  final String id;
  final StayKind kind;

  final String? cityItemId;

  /// مكة المكرمة, المدينة المنورة, دمشق. Falls back to the plain text the leg
  /// chain supplied when the city is in no reference list yet.
  final LocalizedName? city;

  final String? placeItemId;

  /// The مسكن itself — «فيوليت», «سنود الريان».
  ///
  /// **Derived, never entered.** It is the hotel an operational file posts him
  /// to in this city (`housing_for`, 0136): the file is the record of where a
  /// man is housed, and there is only one of it. Null means the files have not
  /// posted him anywhere in this city yet — which is a fact about the paperwork
  /// and not something to ask him about.
  final LocalizedName? place;

  final DateTime? arrivedAt;

  /// Null while he is still there — which is true of exactly one stay at a
  /// time, and is how [Journey.currentStay] finds it.
  final DateTime? departedAt;

  final String? arrivalLegId;
  final String? departureLegId;
  final String? note;

  /// Whole days, counted to now for a stay still running: «18 يوماً حتى الآن»
  /// is the true answer and a blank is not.
  final int? nights;

  /// How many arrivals the attendance register holds for this place over this
  /// stay's own window (§30). Nothing is written by either feature into the
  /// other; they simply agree about which row a hotel is.
  final int checkInCount;

  bool get isCurrent => arrivedAt != null && departedAt == null;
  bool get isPast => departedAt != null;
  bool get isFuture => arrivedAt == null;

  static JourneyStay fromRow(Map<String, dynamic> map) => JourneyStay(
    id: map['stay_id'] as String,
    kind: StayKind.fromDb(map['kind'] as String?),
    cityItemId: map['city_item_id'] as String?,
    city: map['city_ar'] == null
        ? null
        : LocalizedName(
            ar: map['city_ar'] as String,
            en: map['city_en'] as String?,
          ),
    placeItemId: map['place_item_id'] as String?,
    place: map['place_ar'] == null
        ? null
        : LocalizedName(
            ar: map['place_ar'] as String,
            en: map['place_en'] as String?,
          ),
    arrivedAt: _time(map['arrived_at']),
    departedAt: _time(map['departed_at']),
    arrivalLegId: map['arrival_leg_id'] as String?,
    departureLegId: map['departure_leg_id'] as String?,
    note: map['note'] as String?,
    nights: (map['nights'] as num?)?.toInt(),
    checkInCount: (map['check_in_count'] as num?)?.toInt() ?? 0,
  );

  static DateTime? _time(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;
}
