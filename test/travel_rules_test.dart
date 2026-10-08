import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/travel/domain/journey_leg.dart';
import 'package:sdhu_operations_project/features/travel/domain/travel_rules.dart';
import 'package:sdhu_operations_project/features/travel/domain/trip.dart';

/// The shape rules exist twice — once in [TravelRules] so the form offers only
/// what may be chosen, and once in `travel_shape_is_sane` (migration 0133) so
/// nothing else can write what the form would refuse.
///
/// Two copies of a rule is two chances to disagree, and the disagreement would
/// be silent in the worst direction: a form that offers the train for رحلة
/// القدوم and a database that refuses it, discovered by somebody entering
/// forty flights at two in the morning. So this test reads the MIGRATION and
/// holds the Dart to it — the same arrangement `check_in_radius_test.dart`
/// makes for the proximity arithmetic, and for the same reason.

TravelPoint _point(
  String name,
  String country,
  TravelPointKind kind, {
  String? city,
}) => TravelPoint(
  id: name,
  name: LocalizedName(ar: name),
  countryCode: country,
  kind: kind,
  city: city ?? name,
);

final damascus = _point('مطار دمشق الدولي', 'SY', TravelPointKind.airport,
    city: 'دمشق');
final aleppo = _point('مطار حلب الدولي', 'SY', TravelPointKind.airport,
    city: 'حلب');
final jeddahAir = _point('مطار الملك عبدالعزيز', 'SA', TravelPointKind.airport,
    city: 'جدة');
final madinahAir = _point('مطار الأمير محمد', 'SA', TravelPointKind.airport,
    city: 'المدينة المنورة');
final makkahStation = _point('محطة مكة المكرمة', 'SA', TravelPointKind.station,
    city: 'مكة المكرمة');
final madinahStation = _point('محطة المدينة', 'SA', TravelPointKind.station,
    city: 'المدينة المنورة');
final makkah = _point('مكة المكرمة', 'SA', TravelPointKind.city);
final madinah = _point('المدينة المنورة', 'SA', TravelPointKind.city);
final jeddahCity = _point('جدة', 'SA', TravelPointKind.city);

final all = [
  damascus,
  aleppo,
  jeddahAir,
  madinahAir,
  makkahStation,
  madinahStation,
  makkah,
  madinah,
  jeddahCity,
];

void main() {
  group('what may carry a movement', () {
    test('an arrival and a return are flights, and nothing else', () {
      expect(TravelRules.modesFor(LegRole.inbound), [TravelMode.air]);
      expect(TravelRules.modesFor(LegRole.outbound), [TravelMode.air]);
    });

    test('an internal movement is anything BUT a flight', () {
      final modes = TravelRules.modesFor(LegRole.internal);
      expect(modes, isNot(contains(TravelMode.air)));
      // The private car has to be among them — it is the case the whole
      // feature was asked to represent.
      expect(modes, contains(TravelMode.road));
      expect(modes, contains(TravelMode.rail));
      expect(modes, contains(TravelMode.other));
    });
  });

  group('where an arrival may run', () {
    test('out of a Syrian airport and into a Saudi one', () {
      expect(
        TravelRules.originsFor(LegRole.inbound, all),
        [damascus, aleppo],
      );
      expect(
        TravelRules.destinationsFor(LegRole.inbound, all),
        [jeddahAir, madinahAir],
      );
    });

    test('never out of a Saudi airport, never into a city', () {
      final origins = TravelRules.originsFor(LegRole.inbound, all);
      expect(origins, isNot(contains(jeddahAir)));
      final destinations = TravelRules.destinationsFor(LegRole.inbound, all);
      expect(destinations, isNot(contains(makkah)));
      expect(destinations, isNot(contains(jeddahCity)));
    });
  });

  group('where a return may run', () {
    test('is the arrival reversed', () {
      expect(
        TravelRules.originsFor(LegRole.outbound, all),
        TravelRules.destinationsFor(LegRole.inbound, all),
      );
      expect(
        TravelRules.destinationsFor(LegRole.outbound, all),
        TravelRules.originsFor(LegRole.inbound, all),
      );
    });
  });

  group('where an internal movement may run', () {
    test('between مكة and المدينة, and nowhere else', () {
      final points = TravelRules.originsFor(LegRole.internal, all);
      expect(points, [makkahStation, madinahStation, makkah, madinah]);
      // جدة is Saudi and is still not one of the two.
      expect(points, isNot(contains(jeddahCity)));
      expect(points, isNot(contains(jeddahAir)));
      expect(points, isNot(contains(damascus)));
    });

    test('and not the airport that happens to stand in one of them', () {
      // مطار الأمير محمد بن عبدالعزيز IS in المدينة المنورة, so a rule that
      // asked only about the city would offer it as the end of a car journey
      // from مكة. A man heading there is starting his return, not finishing an
      // internal movement.
      expect(
        TravelRules.destinationsFor(LegRole.internal, all),
        isNot(contains(madinahAir)),
      );
      expect(TravelRules.isInternalPoint(madinahAir), isFalse);
    });

    test('both ways, because a man posted to both cities makes it twice', () {
      expect(
        TravelRules.originsFor(LegRole.internal, all),
        TravelRules.destinationsFor(LegRole.internal, all),
      );
    });
  });

  group('the whole combination', () {
    test('accepts what the office actually does', () {
      expect(
        TravelRules.isValid(
          role: LegRole.inbound,
          mode: TravelMode.air,
          from: damascus,
          to: jeddahAir,
        ),
        isTrue,
      );
      expect(
        TravelRules.isValid(
          role: LegRole.internal,
          mode: TravelMode.road,
          from: makkah,
          to: madinah,
        ),
        isTrue,
      );
    });

    test('refuses an arrival by train, and one that never leaves Syria', () {
      expect(
        TravelRules.isValid(
          role: LegRole.inbound,
          mode: TravelMode.rail,
          from: damascus,
          to: jeddahAir,
        ),
        isFalse,
      );
      expect(
        TravelRules.isValid(
          role: LegRole.inbound,
          mode: TravelMode.air,
          from: damascus,
          to: aleppo,
        ),
        isFalse,
      );
    });

    test('refuses an internal flight, and one through جدة', () {
      expect(
        TravelRules.isValid(
          role: LegRole.internal,
          mode: TravelMode.air,
          from: makkah,
          to: madinah,
        ),
        isFalse,
      );
      expect(
        TravelRules.isValid(
          role: LegRole.internal,
          mode: TravelMode.road,
          from: jeddahCity,
          to: makkah,
        ),
        isFalse,
      );
    });

    test('refuses a movement that goes nowhere', () {
      expect(
        TravelRules.isValid(
          role: LegRole.internal,
          mode: TravelMode.road,
          from: makkah,
          to: makkah,
        ),
        isFalse,
      );
    });
  });

  group('where the record already puts him', () {
    // The season that asked for this rule: دمشق → جدة by air, then the train
    // مكة → المدينة, and then a SECOND مكة → المدينة recorded for a man who
    // was already in المدينة. Each movement is a legal train between the two
    // holy cities on its own, so `travel_shape_is_sane` passed all three — and
    // the chain came back out of `ensure_participant_stays` as «مكة ٢٠ يوماً»
    // followed by «مكة ١٠ أيام», with nothing between them that could have
    // carried him back.
    JourneyLeg leg(String id, String from, String to, DateTime at) =>
        JourneyLeg(
          id: id,
          role: LegRole.internal,
          mode: TravelMode.rail,
          status: LegStatus.completed,
          selfArranged: false,
          fromPointId: from,
          toPointId: to,
          plannedDepartureAt: at,
        );

    final toMadinah = leg(
      'to-madinah',
      makkahStation.id,
      madinahStation.id,
      DateTime(2026, 8, 14),
    );

    test('nothing recorded yet narrows nothing', () {
      expect(
        TravelRules.internalOriginCity(
          legs: const [],
          points: all,
          at: DateTime(2026, 8, 20),
        ),
        isNull,
      );
    });

    test('a movement sets out from where the last one left him', () {
      expect(
        TravelRules.internalOriginCity(
          legs: [toMadinah],
          points: all,
          at: DateTime(2026, 8, 20),
        ),
        'المدينة المنورة',
      );
    });

    test('so مكة is no longer somewhere he can leave from', () {
      final city = TravelRules.internalOriginCity(
        legs: [toMadinah],
        points: all,
        at: DateTime(2026, 8, 20),
      );
      expect(TravelRules.canDepartFrom(makkahStation, city), isFalse);
      expect(TravelRules.canDepartFrom(madinahStation, city), isTrue);
      expect(TravelRules.canDepartFrom(madinah, city), isTrue);
    });

    test('a movement backdated before that one is judged where he was', () {
      // Written down after the fact, for a day before the train ran: he was
      // in مكة then, and the record must be read at that date rather than at
      // the moment somebody is typing.
      expect(
        TravelRules.internalOriginCity(
          legs: [toMadinah],
          points: all,
          at: DateTime(2026, 8, 1),
        ),
        isNull,
      );
    });

    test('a point master data has no city for narrows nothing', () {
      final unknown = TravelPoint(
        id: 'nowhere',
        name: LocalizedName(ar: 'نقطة بلا مدينة'),
        countryCode: 'SA',
        kind: TravelPointKind.station,
      );
      expect(
        TravelRules.internalOriginCity(
          legs: [
            leg('x', makkahStation.id, unknown.id, DateTime(2026, 8, 14)),
          ],
          points: [...all, unknown],
          at: DateTime(2026, 8, 20),
        ),
        isNull,
      );
      // And an unknown city must never empty the picker.
      expect(TravelRules.canDepartFrom(makkahStation, null), isTrue);
    });
  });

  group('the migration is where this test gets its truth', () {
    final sql = File(
      'supabase/migrations/0133_a_point_knows_which_country_it_is_in.sql',
    ).readAsStringSync();

    test('the two holy cities are spelled the same in both languages', () {
      // `is_internal_travel_point` names them in SQL; [TravelRules] names them
      // in Dart. A rename on one side that missed the other would empty the
      // internal picker with no error anywhere.
      for (final city in TravelRules.internalCities) {
        expect(
          sql,
          contains(city),
          reason: '0133 does not mention $city — the two copies have drifted',
        );
      }
    });

    test('the migration still refuses what the app refuses', () {
      // Not a parse of the SQL — just that each rule this file asserts is
      // actually stated over there, so deleting one is a visible edit.
      expect(sql, contains('an arrival or a return is a flight'));
      expect(sql, contains('an internal movement is not a flight'));
      expect(sql, contains('a flight runs between airports'));
      expect(sql, contains('an arrival must leave Syria and land in the Kingdom'));
      expect(sql, contains('a return must leave the Kingdom and land in Syria'));
    });
  });
}
