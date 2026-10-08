import '../../../core/l10n/localized_name.dart';
import 'journey_leg.dart';
import 'journey_stay.dart';
import 'trip.dart';

/// One man's whole season of travel.
///
/// **The spine is where he STAYS; the legs are what carry him between.** That
/// inversion is the whole of 0135, and it is worth stating plainly because the
/// first version of this class had it the other way round: the timeline was
/// made of airports — مطار دمشق, مطار جدة, محطة مكة — every one of which is
/// somewhere a man stands for an hour holding a bag.
///
/// A season is thirty-five days: about thirty in مكة and five in المدينة, in a
/// hotel or a camp, with a few hours of aeroplane and train between them. So
/// the substantial thing on the page is «مكة المكرمة · 30 يوماً · فندق الصفوة»,
/// and the flight underneath it prints its terminals in small type, where a
/// terminal belongs.
///
/// What is DERIVED here and never stored — 0130's argument, which still stands:
/// where he is now, what is next, how many days until he flies home. What IS
/// stored is the stay ITSELF — its city and its dates — because a man with
/// `travels = false` has no legs at all and is certainly still somewhere. The
/// hotel is not stored either: it follows from his operational-file postings
/// (0136), and the file is the one record of where the mission houses him.
class Journey {
  Journey({
    required this.participantId,
    required List<JourneyLeg> legs,
    List<JourneyStay> stays = const [],
  }) : _all = List.unmodifiable(legs),
       stays = List.unmodifiable(stays);

  final String participantId;
  final List<JourneyLeg> _all;

  /// Where he was based, in order. Empty only before the spine has been built —
  /// `ensure_participant_stays` runs on every assignment.
  final List<JourneyStay> stays;

  /// Every leg ever recorded, superseded ones included.
  List<JourneyLeg> get allLegs => _all;

  /// The legs that still stand, in the order they happen.
  late final List<JourneyLeg> legs = _all
      .where((l) => l.status.isLive)
      .toList(growable: false);

  /// Nothing recorded at all — not an error, and the ordinary state of most of
  /// the roster until the flights are entered.
  bool get isEmpty => legs.isEmpty && stays.isEmpty;

  // ------------------------------------------------------------ where he is

  late final List<JourneyLeg> _done = legs
      .where((l) => l.status.isDone)
      .toList(growable: false);

  /// **Where he is based now** — the stay he has arrived at and not yet left.
  ///
  /// Read off the spine rather than off the last completed movement, which is
  /// the point of the spine existing: the last movement landed him at an
  /// airport, and he does not live in airports.
  JourneyStay? get currentStay {
    for (final stay in stays) {
      if (stay.isCurrent) return stay;
    }
    return null;
  }

  /// The city he is in, for the headline.
  LocalizedName? get currentPlace => currentStay?.city;

  /// The مسكن — the hotel the operational files post him to (0136). Null when
  /// they have not posted him anywhere in this city, which is a fact about the
  /// paperwork rather than a question for anybody.
  LocalizedName? get currentResidence => currentStay?.place;

  DateTime? get currentPlaceSince => currentStay?.arrivedAt;

  /// How long he has been where he is.
  int? get daysInCurrentStay => currentStay?.nights;

  bool get hasDeparted =>
      _done.isNotEmpty || legs.any((l) => l.actualDepartureAt != null);

  /// Whether the whole journey is behind him.
  bool get isHome =>
      _done.any((l) => l.role == LegRole.outbound && l.status.isDone);

  // --------------------------------------------------------- what is next

  JourneyLeg? get currentLeg => legs.where((l) => !l.status.isDone).firstOrNull;

  JourneyLeg? get nextLeg {
    final rest = legs.where((l) => !l.status.isDone).toList();
    return rest.length > 1 ? rest[1] : null;
  }

  // ---------------------------------------------------------- the way home

  /// His flight home, if one has been booked. **Null is the ordinary state**
  /// for most of the season — a charter return is very often set two days out —
  /// so the UI says so in the plain text colour, never as a warning.
  JourneyLeg? get returnLeg =>
      legs.where((l) => l.role == LegRole.outbound).firstOrNull;

  DateTime? get returnAt => returnLeg?.effectiveDepartureAt;

  JourneyLeg? get arrivalLeg =>
      legs.where((l) => l.role == LegRole.inbound).firstOrNull;

  DateTime? get arrivedAt {
    final leg = arrivalLeg;
    return leg != null && leg.status.isDone ? leg.effectiveArrivalAt : null;
  }

  /// Whole days until he flies home, counted by the calendar rather than by
  /// elapsed hours — nobody has ever meant "48 hours" by «بعد يومين».
  int? get daysToReturn {
    final at = returnAt;
    return at == null ? null : _wholeDaysBetween(DateTime.now(), at);
  }

  /// Which day of his season it is. 1 on the day he landed.
  ///
  /// Falls back to the first housed stay, so a man already resident in the
  /// Kingdom — who has no arrival flight and never will — still gets a count.
  int? get dayOfJourney {
    final from = arrivedAt ?? _firstHousedArrival;
    return from == null ? null : _wholeDaysBetween(from, DateTime.now()) + 1;
  }

  DateTime? get _firstHousedArrival {
    for (final stay in stays) {
      if (stay.kind.isHoused && stay.arrivedAt != null) return stay.arrivedAt;
    }
    return null;
  }

  /// How far through he is, 0 to 1. Provisional while [returnLeg] is null — a
  /// journey with no way home booked has no known end.
  double get progress {
    if (legs.isEmpty) return 0;
    return _done.length / legs.length;
  }

  bool get isProgressProvisional => returnLeg == null;

  // -------------------------------------------------------- what is missing

  List<JourneyLeg> get overdueLegs =>
      legs.where((l) => l.isOverdue).toList(growable: false);

  List<JourneyLeg> get awaitingHisWord =>
      legs.where((l) => l.needsManualConfirmation).toList(growable: false);

  // ------------------------------------------------------------ the drawing

  /// The journey as an ordered line: a place he stayed, the movement that took
  /// him on, the next place he stayed.
  late final List<JourneyEntry> line = _buildLine();

  List<JourneyEntry> _buildLine() {
    // No spine yet. The server builds it the moment anybody is assigned, so
    // this is a brief window rather than a supported shape — but the screen
    // should still say something true while it lasts.
    if (stays.isEmpty) {
      return List.unmodifiable([for (final leg in legs) JourneyMove(leg)]);
    }

    final byId = {for (final leg in legs) leg.id: leg};
    final out = <JourneyEntry>[];

    for (var i = 0; i < stays.length; i++) {
      final stay = stays[i];
      // The movement that brought him here goes above it, looked up by the
      // stay's own `arrival_leg_id` — so the two halves cannot drift out of
      // step the way two independently sorted lists would.
      if (i > 0) {
        final leg = byId[stay.arrivalLegId];
        if (leg != null) out.add(JourneyMove(leg));
      }
      out.add(JourneyStop(stay));
    }

    // Anything the spine does not account for — a movement recorded since the
    // last rebuild. Appended rather than dropped: a leg that exists is a fact,
    // and silently omitting it would be the drawing deciding what is true.
    final drawn = out.whereType<JourneyMove>().map((m) => m.leg.id).toSet();
    for (final leg in legs) {
      if (!drawn.contains(leg.id)) out.add(JourneyMove(leg));
    }

    return List.unmodifiable(out);
  }

  /// Whole calendar days from [from] to [to]. Date arithmetic and not
  /// `Duration.inDays`, because the second answers "how many 24-hour blocks"
  /// and nobody has ever meant that by «بعد يومين».
  static int _wholeDaysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static Journey fromRows(
    String participantId,
    List<Map<String, dynamic>> legRows, {
    List<Map<String, dynamic>> stayRows = const [],
  }) => Journey(
    participantId: participantId,
    legs: legRows.map(JourneyLeg.fromRow).toList(growable: false),
    stays: stayRows.map(JourneyStay.fromRow).toList(growable: false),
  );
}

/// One thing on the drawn line: a place he stayed, or a movement between two.
sealed class JourneyEntry {
  const JourneyEntry();
}

/// Somewhere he was based — the substantial thing on the page.
class JourneyStop extends JourneyEntry {
  const JourneyStop(this.stay);

  final JourneyStay stay;
}

/// A recorded movement between two stays.
///
/// Its terminals are printed small, underneath: مطار الملك عبدالعزيز is a
/// detail of the flight, not a destination. Drawing it as a destination is
/// exactly the mistake 0135 was written to undo.
class JourneyMove extends JourneyEntry {
  const JourneyMove(this.leg);

  final JourneyLeg leg;
}
