import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/travel/domain/journey.dart';
import 'package:sdhu_operations_project/features/travel/domain/journey_leg.dart';
import 'package:sdhu_operations_project/features/travel/domain/journey_stay.dart';
import 'package:sdhu_operations_project/features/travel/domain/trip.dart';

/// [Journey] is the one place in this feature where "where is he, and when does
/// he come back" is answered, and it is answered by ARITHMETIC over a list of
/// legs rather than by a column anybody maintains. That is the whole reason it
/// can be tested here, with no database and no widget — and the reason it must
/// be, because every screen in the feature reads its answers.
///
/// The cases below are the ones the design was argued over:
///
///   * a private car is a movement, not a missing booking
///   * a return that has not been booked yet is NORMAL, not an error
///   * two legs that do not join up produce a neutral gap, not a failure
///   * an empty journey is a sentence, not a broken screen

int _id = 0;

JourneyLeg _leg({
  required LegRole role,
  required String from,
  required String to,
  LegStatus status = LegStatus.planned,
  TravelMode mode = TravelMode.air,
  bool selfArranged = false,
  DateTime? plannedDeparture,
  DateTime? actualDeparture,
  DateTime? actualArrival,
  String? tripNumber,
}) => JourneyLeg(
  id: 'leg${_id++}',
  tripId: selfArranged ? null : 'trip$_id',
  role: role,
  mode: mode,
  status: status,
  selfArranged: selfArranged,
  fromPointId: from,
  fromPoint: LocalizedName(ar: from),
  toPointId: to,
  toPoint: LocalizedName(ar: to),
  tripNumber: tripNumber,
  plannedDepartureAt: plannedDeparture,
  actualDepartureAt: actualDeparture,
  actualArrivalAt: actualArrival,
);

JourneyStay _stay({
  required String city,
  StayKind kind = StayKind.residence,
  String? place,
  DateTime? arrived,
  DateTime? departed,
  String? arrivalLegId,
  int? nights,
}) => JourneyStay(
  id: 'stay${_id++}',
  kind: kind,
  cityItemId: city,
  city: LocalizedName(ar: city),
  placeItemId: place,
  place: place == null ? null : LocalizedName(ar: place),
  arrivedAt: arrived,
  departedAt: departed,
  arrivalLegId: arrivalLegId,
  nights: nights,
);

Journey _journey(List<JourneyLeg> legs, {List<JourneyStay> stays = const []}) =>
    Journey(participantId: 'p1', legs: legs, stays: stays);

void main() {
  final now = DateTime.now();
  final aWeekAgo = now.subtract(const Duration(days: 7));
  final inTwelveDays = now.add(const Duration(days: 12));

  group('an empty journey', () {
    test('is empty rather than broken', () {
      final j = _journey([]);
      expect(j.isEmpty, isTrue);
      expect(j.currentPlace, isNull);
      expect(j.line, isEmpty);
      expect(j.progress, 0);
      // The absence of a return is not an error even here.
      expect(j.returnLeg, isNull);
      expect(j.daysToReturn, isNull);
    });
  });

  group('where he is', () {
    test('is the city of the stay he has arrived at and not left', () {
      // Not the destination of the last movement — that is an airport. 0135.
      final inbound = _leg(
        role: LegRole.inbound,
        from: 'مطار دمشق',
        to: 'مطار جدة',
        status: LegStatus.completed,
        actualDeparture: aWeekAgo,
        actualArrival: aWeekAgo.add(const Duration(hours: 3)),
      );
      final j = _journey(
        [inbound],
        stays: [
          _stay(city: 'دمشق', kind: StayKind.home, departed: aWeekAgo),
          _stay(
            city: 'مكة المكرمة',
            arrived: aWeekAgo,
            arrivalLegId: inbound.id,
            nights: 7,
          ),
        ],
      );
      expect(j.currentPlace?.ar, 'مكة المكرمة');
      expect(j.hasDeparted, isTrue);
      expect(j.isHome, isFalse);
    });

    test('is nowhere in particular before he has set off', () {
      // The home stay has not been left, so it IS the current one.
      final j = _journey(
        [
          _leg(
            role: LegRole.inbound,
            from: 'مطار دمشق',
            to: 'مطار جدة',
            plannedDeparture: now.add(const Duration(days: 3)),
          ),
        ],
        stays: [_stay(city: 'دمشق', kind: StayKind.home, arrived: aWeekAgo)],
      );
      expect(j.currentPlace?.ar, 'دمشق');
      expect(j.hasDeparted, isFalse);
    });

    test('a completed return means he is home', () {
      final j = _journey([
        _leg(
          role: LegRole.inbound,
          from: 'مطار دمشق',
          to: 'مطار جدة',
          status: LegStatus.completed,
          actualArrival: aWeekAgo,
        ),
        _leg(
          role: LegRole.outbound,
          from: 'مطار المدينة',
          to: 'مطار دمشق',
          status: LegStatus.completed,
          actualArrival: now,
        ),
      ]);
      expect(j.isHome, isTrue);
      expect(j.progress, 1.0);
    });
  });

  group('the way home', () {
    test('an unbooked return is null and NOT a failure', () {
      final j = _journey([
        _leg(
          role: LegRole.inbound,
          from: 'دمشق',
          to: 'جدة',
          status: LegStatus.completed,
          actualArrival: aWeekAgo,
        ),
      ]);
      expect(j.returnLeg, isNull);
      expect(j.daysToReturn, isNull);
      // Progress over what is KNOWN, and flagged as provisional so no screen
      // presents "100%" to a man with no flight home.
      expect(j.isProgressProvisional, isTrue);
      expect(j.legs.every((l) => !l.status.isFailure), isTrue);
    });

    test('counts whole calendar days, not 24-hour blocks', () {
      final j = _journey([
        _leg(
          role: LegRole.outbound,
          from: 'جدة',
          to: 'دمشق',
          plannedDeparture: inTwelveDays,
        ),
      ]);
      expect(j.daysToReturn, 12);
      expect(j.isProgressProvisional, isFalse);
    });

    test('a return late tonight still reads as tomorrow, not as today', () {
      final today = DateTime(now.year, now.month, now.day);
      final j = _journey([
        _leg(
          role: LegRole.outbound,
          from: 'جدة',
          to: 'دمشق',
          plannedDeparture: today.add(const Duration(days: 1, hours: 1)),
        ),
      ]);
      expect(j.daysToReturn, 1);
    });
  });

  group('a movement he arranged himself', () {
    test('is a leg like any other, and asks HIM to confirm it', () {
      final car = _leg(
        role: LegRole.internal,
        from: 'مكة',
        to: 'المدينة',
        mode: TravelMode.road,
        selfArranged: true,
        plannedDeparture: now.subtract(const Duration(days: 1)),
      );
      final j = _journey([car]);

      expect(car.selfArranged, isTrue);
      // The thing the whole requirement turned on: it is not a failure.
      expect(car.status.isFailure, isFalse);
      expect(car.carrierLabel, isNull, reason: 'a private car has no carrier row');
      expect(car.needsManualConfirmation, isTrue);
      expect(j.awaitingHisWord, hasLength(1));
      // Its hour has passed, so the board may ask — but only ask.
      expect(car.isOverdue, isTrue);
      expect(j.overdueLegs, hasLength(1));
    });

    test('once completed it moves him, exactly like a flight', () {
      final car = _leg(
        role: LegRole.internal,
        from: 'مكة المكرمة',
        to: 'المدينة المنورة',
        mode: TravelMode.road,
        selfArranged: true,
        status: LegStatus.completed,
        actualArrival: now.subtract(const Duration(days: 1)),
      );
      final j = _journey(
        [car],
        stays: [
          _stay(
            city: 'مكة المكرمة',
            departed: now.subtract(const Duration(days: 1)),
          ),
          _stay(
            city: 'المدينة المنورة',
            arrived: now.subtract(const Duration(days: 1)),
            arrivalLegId: car.id,
            nights: 1,
          ),
        ],
      );
      expect(j.currentPlace?.ar, 'المدينة المنورة');
      expect(j.overdueLegs, isEmpty);
    });
  });

  group('superseded legs', () {
    test('are kept but do not stand', () {
      final j = _journey([
        _leg(
          role: LegRole.inbound,
          from: 'دمشق',
          to: 'جدة',
          status: LegStatus.rebooked,
          tripNumber: 'SR441',
        ),
        _leg(
          role: LegRole.inbound,
          from: 'دمشق',
          to: 'جدة',
          status: LegStatus.completed,
          tripNumber: 'SR447',
          actualArrival: aWeekAgo,
        ),
      ]);
      expect(j.allLegs, hasLength(2), reason: 'history is not deleted');
      expect(j.legs, hasLength(1), reason: 'only one still stands');
      expect(j.legs.single.tripNumber, 'SR447');
      expect(j.progress, 1.0);
    });
  });

  group('the drawn line', () {
    test('is a line of PLACES HE STAYED, joined by movements', () {
      // The correction 0135 exists for. He lands at مطار الملك عبدالعزيز and
      // lives in مكة; the airport belongs to the flight, not to the spine.
      final inbound = _leg(
        role: LegRole.inbound,
        from: 'مطار دمشق',
        to: 'مطار جدة',
        status: LegStatus.completed,
        actualArrival: aWeekAgo,
      );
      final outbound = _leg(
        role: LegRole.outbound,
        from: 'مطار المدينة',
        to: 'مطار دمشق',
        plannedDeparture: inTwelveDays,
      );
      final j = _journey(
        [inbound, outbound],
        stays: [
          _stay(city: 'دمشق', kind: StayKind.home, departed: aWeekAgo),
          _stay(
            city: 'مكة المكرمة',
            place: 'فندق الصفوة',
            arrived: aWeekAgo,
            arrivalLegId: inbound.id,
            nights: 7,
          ),
          _stay(
            city: 'دمشق',
            kind: StayKind.home,
            arrived: inTwelveDays,
            arrivalLegId: outbound.id,
          ),
        ],
      );

      expect(j.line[0], isA<JourneyStop>());
      expect(j.line[1], isA<JourneyMove>());
      expect(j.line[2], isA<JourneyStop>());

      // Not one airport among the nodes.
      expect(
        j.line.whereType<JourneyStop>().map((s) => s.stay.city?.ar),
        ['دمشق', 'مكة المكرمة', 'دمشق'],
      );
    });

    test('the current stay is where he is, and it names the hotel', () {
      final inbound = _leg(
        role: LegRole.inbound,
        from: 'مطار دمشق',
        to: 'مطار جدة',
        status: LegStatus.completed,
        actualArrival: aWeekAgo,
      );
      final j = _journey(
        [inbound],
        stays: [
          _stay(city: 'دمشق', kind: StayKind.home, departed: aWeekAgo),
          _stay(
            city: 'مكة المكرمة',
            place: 'فندق الصفوة',
            arrived: aWeekAgo,
            arrivalLegId: inbound.id,
            nights: 7,
          ),
        ],
      );

      expect(j.currentPlace?.ar, 'مكة المكرمة');
      expect(j.currentResidence?.ar, 'فندق الصفوة');
      expect(j.daysInCurrentStay, 7);
      expect(j.currentStay?.isCurrent, isTrue);
    });

    test('the مسكن comes from the files, and its absence is silent', () {
      // 0136: nobody types a hotel. It is the place an operational file posts
      // him to, resolved on every read — so a stay without one is a statement
      // about the paperwork and the card simply omits the line.
      final j = _journey(
        [],
        stays: [
          _stay(
            city: 'مكة المكرمة',
            place: 'فيوليت',
            arrived: aWeekAgo,
            nights: 7,
          ),
          _stay(city: 'المدينة المنورة', arrived: now),
        ],
      );
      expect(j.currentResidence?.ar, 'فيوليت');
      expect(j.stays.last.place, isNull);
      // And nothing anywhere treats the missing one as a failure.
      expect(j.stays.last.kind.isHoused, isTrue);
    });

    test('a man who never travels still has a spine', () {
      // travels = false: no legs at all, and certainly still somewhere. This is
      // the case that settled stays being stored rather than derived.
      final j = _journey(
        [],
        stays: [
          _stay(
            city: 'مكة المكرمة',
            place: 'فندق الصفوة',
            arrived: aWeekAgo,
            nights: 7,
          ),
        ],
      );
      expect(j.isEmpty, isFalse);
      expect(j.legs, isEmpty);
      expect(j.currentPlace?.ar, 'مكة المكرمة');
      expect(j.line.whereType<JourneyStop>(), hasLength(1));
      expect(j.dayOfJourney, 8);
    });

    test('falls back to the movements when no spine has been built yet', () {
      final j = _journey([
        _leg(role: LegRole.inbound, from: 'مطار دمشق', to: 'مطار جدة'),
      ]);
      expect(j.line, hasLength(1));
      expect(j.line.single, isA<JourneyMove>());
    });
  });

  group('what is next', () {
    test('is the first leg he has not completed', () {
      final inbound = _leg(
        role: LegRole.inbound,
        from: 'دمشق',
        to: 'جدة',
        status: LegStatus.completed,
        actualArrival: aWeekAgo,
      );
      final internal = _leg(
        role: LegRole.internal,
        from: 'مكة',
        to: 'المدينة',
        plannedDeparture: now.add(const Duration(days: 1)),
      );
      final outbound = _leg(
        role: LegRole.outbound,
        from: 'المدينة',
        to: 'دمشق',
        plannedDeparture: inTwelveDays,
      );
      final j = _journey([inbound, internal, outbound]);

      expect(j.currentLeg?.id, internal.id);
      expect(j.nextLeg?.id, outbound.id);
      expect(j.progress, closeTo(1 / 3, 0.001));
    });
  });

  group('planned against actual', () {
    test('a materially late departure is flagged; a punctual one is not', () {
      final planned = now.subtract(const Duration(days: 1));
      final late = _leg(
        role: LegRole.inbound,
        from: 'دمشق',
        to: 'جدة',
        status: LegStatus.completed,
        plannedDeparture: planned,
        actualDeparture: planned.add(const Duration(hours: 6)),
      );
      final punctual = _leg(
        role: LegRole.outbound,
        from: 'جدة',
        to: 'دمشق',
        status: LegStatus.completed,
        plannedDeparture: planned,
        actualDeparture: planned.add(const Duration(minutes: 4)),
      );
      expect(late.departedLate, isTrue);
      expect(punctual.departedLate, isFalse);
    });
  });
}
