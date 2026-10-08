import 'journey_leg.dart';
import 'trip.dart';

/// What shape a movement of each kind may take.
///
/// The office's own rules, and there are only three of them:
///
///   رحلة القدوم    طيران، من مطار سوري إلى مطار سعودي
///   رحلة العودة    طيران، من مطار سعودي إلى مطار سوري
///   تنقّل داخلي     قطار أو سيارة أو وسيلة أخرى — never a flight — بين مكة
///                  المكرمة والمدينة المنورة
///
/// ------------------------------------------------------- written twice, on purpose
///
/// These same rules are enforced by `travel_shape_is_sane` in migration 0133,
/// and this file is the second copy. That is a cost paid deliberately, and it
/// is the arrangement [CheckInRules] already makes for the proximity
/// arithmetic: the SERVER is what makes the rule true, and the CLIENT needs to
/// know it in order to offer only valid choices in the first place.
///
/// A form that lets a man pick «القدوم بالقطار» and then hands him a Postgres
/// error is a worse form than one that never offered the train — and asking the
/// server what may be picked, field by field, would be a round trip per
/// keystroke on the worst network of the year.
///
/// `test/travel_rules_test.dart` holds the two together.
abstract final class TravelRules {
  const TravelRules._();

  /// The cities a تنقّل داخلي runs between. The Arabic names as master data
  /// spells them, matching `is_internal_travel_point` in 0133.
  static const internalCities = {'مكة المكرمة', 'المدينة المنورة'};

  /// What may carry a movement of this kind.
  ///
  /// Between the two countries there is one way to travel and the mission has
  /// never used another. Inside the Kingdom there is every way EXCEPT that one:
  /// nobody flies مكة to المدينة, and offering it would put an aeroplane on a
  /// timeline where a car belongs.
  static List<TravelMode> modesFor(LegRole role) => switch (role) {
    LegRole.inbound || LegRole.outbound => const [TravelMode.air],
    LegRole.internal => const [
      TravelMode.rail,
      TravelMode.road,
      TravelMode.other,
    ],
  };

  /// Whether a point may stand at either end of an internal movement.
  ///
  /// Airports are excluded even when they stand in the right city, and مطار
  /// الأمير محمد بن عبدالعزيز is exactly why: it IS in المدينة المنورة, so a
  /// rule that asked only about the city would offer it as the destination of a
  /// car from مكة. An internal movement of this mission ends at the station or
  /// in the city — a man heading for that airport is starting his رحلة العودة,
  /// which is a different row under different rules. Mirrors
  /// `is_internal_travel_point` in 0133.
  static bool isInternalPoint(TravelPoint point) =>
      point.isSaudi && !point.isAirport && internalCities.contains(point.city);

  /// Where a movement of this kind may START.
  static List<TravelPoint> originsFor(
    LegRole role,
    List<TravelPoint> points,
  ) => switch (role) {
    LegRole.inbound => points.where((p) => p.isSyrian && p.isAirport).toList(),
    LegRole.outbound => points.where((p) => p.isSaudi && p.isAirport).toList(),
    LegRole.internal => points.where(isInternalPoint).toList(),
  };

  /// Where it may END. The mirror of [originsFor] for the two bookends, and the
  /// same list for an internal movement — which runs both ways, and does so
  /// twice in a season for anybody posted to both cities.
  static List<TravelPoint> destinationsFor(
    LegRole role,
    List<TravelPoint> points,
  ) => switch (role) {
    LegRole.inbound => points.where((p) => p.isSaudi && p.isAirport).toList(),
    LegRole.outbound => points.where((p) => p.isSyrian && p.isAirport).toList(),
    LegRole.internal => points.where(isInternalPoint).toList(),
  };

  /// The mode to fall back on when the role changes under a half-filled form.
  static TravelMode defaultModeFor(LegRole role) => modesFor(role).first;

  // ─────────────────────────── where the man actually is ──────────────────
  //
  // Everything above judges ONE movement against the office's rules and could
  // be decided with the form in front of you. The two below judge it against
  // the movements ALREADY RECORDED, which the form cannot do on its own and
  // which nothing else was doing either.
  //
  // The season that produced this: a man flew دمشق → جدة, took the train مكة →
  // المدينة, and then a second مكة → المدينة was recorded for him while he was
  // already in المدينة. Every movement passed `travel_shape_is_sane` on its
  // own — each one is a legal train between the two holy cities — and the
  // chain they made was impossible. `ensure_participant_stays` (0135) names a
  // stay by where the NEXT movement sets out from, so the impossible chain
  // came back as «مكة ٢٠ يوماً» followed by «مكة ١٠ أيام» with no movement
  // between them that could have brought him back. The register said he was in
  // two places, and it said it in the one voice the office trusts.
  //
  // There is no twin for these on the server yet, and that is stated rather
  // than hidden: `travel_shape_is_sane` judges a movement in isolation and
  // knows nothing of the participant's other legs. So this pair narrows the
  // FORM — it cannot stop a contradictory leg arriving by another road.

  /// Where a تنقّل داخلي departing at [at] must set out from: the city the
  /// movement before it left him in.
  ///
  /// Null means unconstrained, and it means it for three different honest
  /// reasons — nothing recorded before [at] (this is his first movement),
  /// the previous movement names no destination, or that destination is a
  /// point master data has no city for. A rule that cannot be evaluated must
  /// not narrow anything: an empty picker is a worse answer than a wide one.
  ///
  /// Keyed on [at] rather than simply taking the last leg, because a movement
  /// is very often written down after the fact — a man recording the drive he
  /// made last Tuesday must be judged against where he was last Tuesday, not
  /// against where he is standing while he types.
  static String? internalOriginCity({
    required List<JourneyLeg> legs,
    required List<TravelPoint> points,
    required DateTime at,
  }) {
    JourneyLeg? previous;
    DateTime? previousAt;
    for (final leg in legs) {
      final departs = leg.effectiveDepartureAt;
      if (departs == null || departs.isAfter(at)) continue;
      if (previousAt == null || departs.isAfter(previousAt)) {
        previous = leg;
        previousAt = departs;
      }
    }

    final toId = previous?.toPointId;
    if (toId == null) return null;
    for (final point in points) {
      if (point.id == toId) return point.city;
    }
    return null;
  }

  /// Whether [point] may start a تنقّل داخلي for a man the record puts in
  /// [city]. A null [city] is "unknown, so do not narrow" — see
  /// [internalOriginCity].
  static bool canDepartFrom(TravelPoint point, String? city) =>
      city == null || point.city == city;

  /// Whether a chosen combination could be saved at all. Not a substitute for
  /// the server's refusal — it is what stops the form ever asking.
  static bool isValid({
    required LegRole role,
    required TravelMode mode,
    required TravelPoint? from,
    required TravelPoint? to,
  }) {
    if (from == null || to == null || from.id == to.id) return false;
    if (!modesFor(role).contains(mode)) return false;
    return originsFor(role, [from]).isNotEmpty &&
        destinationsFor(role, [to]).isNotEmpty;
  }
}
