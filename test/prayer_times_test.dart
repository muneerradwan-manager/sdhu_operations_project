import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/prayer_times/data/prayer_times_repository.dart';
import 'package:sdhu_operations_project/features/prayer_times/domain/prayer_day.dart';
import 'package:sdhu_operations_project/features/prayer_times/domain/prayer_place.dart';

/// The three things a prayer card can be wrong about, and the tests that pin
/// each of them.
///
/// 1. WHICH WINDOW IS OPEN. The bug this feature was written around is the
///    stretch between الشروق and الظهر, in which no prayer is due — six hours,
///    the longest window of the day, and the one a card that dutifully fills a
///    "current prayer" slot lies about every single morning.
/// 2. WHERE. Manageable only because a Hajj mission stands in a handful of
///    named points; the radii around them overlap and the labels must not.
/// 3. WHEN. The astronomy is the library's, but which method it is asked for,
///    and whether the answer comes back in local time on the right day, is
///    this app's.
void main() {
  // A day of six marks, laid out at the hours a Makkah summer roughly puts
  // them, so that the arithmetic in each case is readable at a glance.
  final day = PrayerDay(
    day: DateTime(2026, 8, 2),
    fajr: DateTime(2026, 8, 2, 4, 30),
    sunrise: DateTime(2026, 8, 2, 5, 55),
    dhuhr: DateTime(2026, 8, 2, 12, 25),
    asr: DateTime(2026, 8, 2, 15, 45),
    maghrib: DateTime(2026, 8, 2, 19, 0),
    isha: DateTime(2026, 8, 2, 20, 30),
    previousIsha: DateTime(2026, 8, 1, 20, 31),
    nextFajr: DateTime(2026, 8, 3, 4, 31),
  );

  group('the window the clock stands in', () {
    test('before dawn it is still last night\'s عشاء, running into الفجر', () {
      final window = day.windowAt(DateTime(2026, 8, 2, 1, 15));
      expect(window.current, PrayerSlot.isha);
      expect(window.next, PrayerSlot.fajr);
      expect(window.currentIsYesterday, isTrue);
      // The window opened last night, which is what makes the progress bar
      // read as most of the night gone rather than as an hour of nothing.
      expect(window.start, day.previousIsha);
      expect(window.end, day.fajr);
    });

    test(
      'inside الفجر the countdown runs to الشروق, not to the next prayer',
      () {
        final window = day.windowAt(DateTime(2026, 8, 2, 5, 0));
        expect(window.current, PrayerSlot.fajr);
        expect(window.next, PrayerSlot.sunrise);
        // The card says "ينتهي وقت الفجر" rather than "الصلاة القادمة" off this.
        expect(window.endsAtSunrise, isTrue);
        expect(window.inSunriseGap, isFalse);
        expect(
          window.remainingAt(DateTime(2026, 8, 2, 5, 0)),
          const Duration(minutes: 55),
        );
      },
    );

    test('after الشروق nothing is due until الظهر, and it says so', () {
      final window = day.windowAt(DateTime(2026, 8, 2, 9, 0));
      // `current` is الشروق because that is the mark the reader is standing
      // past — but it is not a prayer, and the whole card branches on this.
      expect(window.current, PrayerSlot.sunrise);
      expect(window.current.isPrayer, isFalse);
      expect(window.inSunriseGap, isTrue);
      expect(window.next, PrayerSlot.dhuhr);
    });

    test('the gap closes the instant الظهر arrives', () {
      // Exactly on the boundary belongs to the window it opens, not to the one
      // it closes: at 12:25:00 الظهر is in, and the sunrise gap is over.
      final window = day.windowAt(day.dhuhr);
      expect(window.inSunriseGap, isFalse);
      expect(window.current, PrayerSlot.dhuhr);
      expect(window.next, PrayerSlot.asr);
    });

    test('the four ordinary windows run prayer to prayer', () {
      final cases = <DateTime, (PrayerSlot, PrayerSlot)>{
        DateTime(2026, 8, 2, 13, 0): (PrayerSlot.dhuhr, PrayerSlot.asr),
        DateTime(2026, 8, 2, 16, 0): (PrayerSlot.asr, PrayerSlot.maghrib),
        DateTime(2026, 8, 2, 19, 30): (PrayerSlot.maghrib, PrayerSlot.isha),
        DateTime(2026, 8, 2, 21, 0): (PrayerSlot.isha, PrayerSlot.fajr),
      };
      cases.forEach((now, expected) {
        final window = day.windowAt(now);
        expect(window.current, expected.$1, reason: '$now');
        expect(window.next, expected.$2, reason: '$now');
        expect(window.inSunriseGap, isFalse, reason: '$now');
      });
    });

    test('after العشاء the فجر being counted down to is tomorrow\'s', () {
      final window = day.windowAt(DateTime(2026, 8, 2, 23, 0));
      expect(window.next, PrayerSlot.fajr);
      expect(window.nextIsTomorrow, isTrue);
      // Not today's 04:30, which is eighteen hours in the past. Getting this
      // wrong is a countdown that shows a negative number all evening.
      expect(window.end, day.nextFajr);
      expect(
        window.remainingAt(DateTime(2026, 8, 2, 23, 0)),
        const Duration(hours: 5, minutes: 31),
      );
    });

    test('every minute of the day lands in exactly one window', () {
      // The seven cases are meant to be exhaustive and non-overlapping. This is
      // the check that they are: no minute may fall through, and each answer
      // must be internally consistent — the clock inside its own bounds.
      for (var minute = 0; minute < 24 * 60; minute++) {
        final now = DateTime(2026, 8, 2).add(Duration(minutes: minute));
        final window = day.windowAt(now);
        expect(now.isBefore(window.start), isFalse, reason: '$now');
        expect(now.isBefore(window.end), isTrue, reason: '$now');
        expect(window.progressAt(now), inInclusiveRange(0.0, 1.0));
      }
    });

    test('the countdown never goes negative on a boundary it missed', () {
      // The phone was asleep and the timer fired late. The card must show zero
      // and ask for a new window, not "-00:03".
      expect(
        day
            .windowAt(DateTime(2026, 8, 2, 13, 0))
            .remainingAt(DateTime(2026, 8, 2, 16, 0)),
        Duration.zero,
      );
    });
  });

  group('naming the place', () {
    test('the مشاعر do not swallow one another', () {
      // منى's centre is about eight kilometres from the Haram, which is why
      // مكة's radius is six and not the ten that would cover the city: at ten,
      // every night of التشريق would be labelled مكة المكرمة.
      expect(PrayerPlace.nearestTo(21.4225, 39.8262), PrayerPlace.makkah);
      expect(PrayerPlace.nearestTo(21.4133, 39.8933), PrayerPlace.mina);
      expect(PrayerPlace.nearestTo(21.3833, 39.9370), PrayerPlace.muzdalifah);
      expect(PrayerPlace.nearestTo(21.3550, 39.9840), PrayerPlace.arafat);
      expect(PrayerPlace.nearestTo(24.4672, 39.6111), PrayerPlace.madinah);
    });

    test('where two radii overlap, the nearer name wins', () {
      // مكة reaches six kilometres and منى three and a half, and they are eight
      // apart — so the road between them is covered twice over, on purpose.
      // What decides it there is distance, which is why the lookup takes the
      // nearest match and not the first one declared.
      expect(PrayerPlace.nearestTo(21.4160, 39.8750), PrayerPlace.mina);
    });

    test('outside every radius is nobody\'s, and says so', () {
      // The card falls back to "موقعك" rather than reaching for the nearest
      // name anyway, because a wrong place under a right time is worse than no
      // place at all.
      expect(PrayerPlace.nearestTo(21.5500, 39.7500), isNull);
      // Damascus — where the mission comes from, and nowhere near this list.
      expect(PrayerPlace.nearestTo(33.5138, 36.2765), isNull);
    });

    test('the distance is a great circle, not a difference of degrees', () {
      // Makkah to Madinah, which is about 340 km by air.
      final km = kilometresBetween(21.4225, 39.8262, 24.4672, 39.6111);
      expect(km, closeTo(340, 15));
    });
  });

  group('computing a day', () {
    final repository = PrayerTimesRepository();

    test('Makkah gets أم القرى, Damascus gets the Muslim World League', () {
      // Not a preference. The أم القرى times are the ones on the Haram\'s own
      // board and on every clock around it; showing a Makkah reader anything
      // else is simply wrong to them. Its ninety-minute Isha interval is
      // derived for this latitude, though, so it must not follow the mission
      // home.
      final makkah = PrayerTimesRepository.parametersFor(21.4225, 39.8262);
      expect(makkah.ishaInterval, 90);
      expect(makkah.fajrAngle, 18.5);

      final damascus = PrayerTimesRepository.parametersFor(33.5138, 36.2765);
      expect(damascus.ishaInterval, 0);
      expect(damascus.ishaAngle, 17);
    });

    test('the six marks come back in order, on the day that was asked for', () {
      final computed = repository.dayFor(
        latitude: 21.4225,
        longitude: 39.8262,
        at: DateTime(2026, 8, 2, 10),
      );

      final marks = [
        computed.fajr,
        computed.sunrise,
        computed.dhuhr,
        computed.asr,
        computed.maghrib,
        computed.isha,
      ];
      for (var i = 1; i < marks.length; i++) {
        expect(
          marks[i].isAfter(marks[i - 1]),
          isTrue,
          reason: '${marks[i]} should follow ${marks[i - 1]}',
        );
      }

      // Local, not UTC — the one conversion this feature does, and the one that
      // would silently shift every time on the card by three hours.
      expect(computed.fajr.isUtc, isFalse);
      expect(computed.day, DateTime(2026, 8, 2));

      // The two that hang off the ends belong to the neighbouring days.
      expect(computed.previousIsha.isBefore(computed.fajr), isTrue);
      expect(computed.nextFajr.isAfter(computed.isha), isTrue);
    });

    test(
      'الظهر falls at Makkah\'s solar noon, within the equation of time',
      () {
        // A check on the astronomy that needs no table to compare against: the
        // sun crosses the meridian at 12:00 UTC less four minutes per degree of
        // east longitude, give or take the ±16 minutes the equation of time
        // swings through over a year. Makkah is 39.83° E, so about 09:21 UTC.
        final computed = repository.dayFor(
          latitude: 21.4225,
          longitude: 39.8262,
          at: DateTime(2026, 8, 2, 10),
        );
        final noon = computed.dhuhr.toUtc();
        final minutesFromMidnightUtc = noon.hour * 60 + noon.minute;
        const meridianCrossing = 12 * 60 - 39.8262 * 4;
        expect(
          minutesFromMidnightUtc.toDouble(),
          closeTo(meridianCrossing, 20),
        );
      },
    );

    test('a day computed anywhere still divides into windows', () {
      // Damascus in winter, where the method differs and the night is long.
      final computed = repository.dayFor(
        latitude: 33.5138,
        longitude: 36.2765,
        at: DateTime(2026, 1, 15, 12),
      );

      // Asked at a moment taken from the computed day, not at a wall-clock
      // hour — and this is the whole point of the test rather than a detail of
      // it.
      //
      // The marks come back in the DEVICE's zone, and the device is not
      // standing in Damascus. This used to ask at «10:00», which is a
      // different INSTANT on every machine: 07:00 UTC on a laptop in the Gulf,
      // comfortably inside the gap, and 10:00 UTC on a runner set to UTC —
      // fifteen minutes past a الظهر that falls at 09:45 UTC. So the assertion
      // read as one about the astronomy and was really about where the machine
      // was sitting, and it passed for a year on the only machines anybody ran
      // it on.
      //
      // Halfway between الشروق and الظهر is inside the gap wherever the clock
      // is set, because all three are the same instants shifted by the same
      // offset.
      final gap = computed.dhuhr.difference(computed.sunrise);
      final midGap = computed.sunrise.add(gap ~/ 2);

      final window = computed.windowAt(midGap);
      expect(window.inSunriseGap, isTrue);
      expect(window.next, PrayerSlot.dhuhr);
    });
  });
}
