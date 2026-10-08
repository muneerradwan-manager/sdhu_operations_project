import 'package:equatable/equatable.dart';

/// The six marks a day is read by.
///
/// [sunrise] is one of them and is *not* one of the five: it is on this list
/// because it is on the wall of every mosque and because it is the boundary
/// that closes الفجر. Everything downstream that treats it as a prayer — a
/// highlight, a countdown labelled "الصلاة الحالية", a notification — is wrong,
/// and [isPrayer] is what the rest of this feature asks instead of comparing
/// against the name.
enum PrayerSlot {
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha;

  /// False for [sunrise] alone.
  bool get isPrayer => this != PrayerSlot.sunrise;
}

/// One local calendar day's times, plus the two that hang off its ends.
///
/// [previousIsha] and [nextFajr] are here because the day the *clock* runs
/// through is not the day the *calendar* holds. At one in the morning a person
/// is inside a window that opened last night, and at ten at night they are
/// waiting on a Fajr that belongs to tomorrow's page. A model that stopped at
/// midnight would have to answer "no current prayer" for the seven hours a
/// mission's night shift is actually working.
///
/// Every time here is LOCAL. The library computes in UTC and this is the one
/// place that converts, so nothing below has to remember which it was handed.
class PrayerDay extends Equatable {
  const PrayerDay({
    required this.day,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.previousIsha,
    required this.nextFajr,
  });

  /// Local midnight of the day these were computed for. Compared against
  /// today's to notice the page has turned.
  final DateTime day;

  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  /// Yesterday evening's عشاء — where the window running through midnight began.
  final DateTime previousIsha;

  /// Tomorrow morning's فجر — where the window running through midnight ends.
  final DateTime nextFajr;

  DateTime timeOf(PrayerSlot slot) => switch (slot) {
    PrayerSlot.fajr => fajr,
    PrayerSlot.sunrise => sunrise,
    PrayerSlot.dhuhr => dhuhr,
    PrayerSlot.asr => asr,
    PrayerSlot.maghrib => maghrib,
    PrayerSlot.isha => isha,
  };

  /// Whether [now] falls on the calendar day this was computed for.
  bool covers(DateTime now) =>
      now.year == day.year && now.month == day.month && now.day == day.day;

  /// Which window [now] is standing in.
  ///
  /// The seven cases are exhaustive and ordered, so the first one that holds is
  /// the answer:
  ///
  /// ```
  ///   … ── عشاء الأمس ──┤ الفجر ├─ الشروق ─┤ الظهر ├ العصر ┤ المغرب ┤ العشاء ── …
  ///   00:00          04:32     05:58     12:14   15:42   18:29   19:59   24:00
  /// ```
  ///
  /// The stretch between الشروق and الظهر is the one with no prayer in it, and
  /// it is not an edge case to be swept into "current = الشروق" and forgotten:
  /// it is six hours of every day, the longest window on the list, and the one
  /// a card that says "الصلاة الحالية" is lying about for a quarter of its life.
  /// It is reported by [PrayerWindow.inSunriseGap], and the strings and the
  /// colours both change for it.
  PrayerWindow windowAt(DateTime now) {
    if (now.isBefore(fajr)) {
      // Still last night's عشاء. Its own time is shown from today's column —
      // a few minutes off from the one that actually opened the window, and the
      // convention everywhere, because what a reader wants from that row is
      // tonight's answer.
      return PrayerWindow(
        current: PrayerSlot.isha,
        next: PrayerSlot.fajr,
        start: previousIsha,
        end: fajr,
        currentIsYesterday: true,
      );
    }
    if (now.isBefore(sunrise)) {
      return PrayerWindow(
        current: PrayerSlot.fajr,
        next: PrayerSlot.sunrise,
        start: fajr,
        end: sunrise,
      );
    }
    if (now.isBefore(dhuhr)) {
      return PrayerWindow(
        current: PrayerSlot.sunrise,
        next: PrayerSlot.dhuhr,
        start: sunrise,
        end: dhuhr,
      );
    }
    if (now.isBefore(asr)) {
      return PrayerWindow(
        current: PrayerSlot.dhuhr,
        next: PrayerSlot.asr,
        start: dhuhr,
        end: asr,
      );
    }
    if (now.isBefore(maghrib)) {
      return PrayerWindow(
        current: PrayerSlot.asr,
        next: PrayerSlot.maghrib,
        start: asr,
        end: maghrib,
      );
    }
    if (now.isBefore(isha)) {
      return PrayerWindow(
        current: PrayerSlot.maghrib,
        next: PrayerSlot.isha,
        start: maghrib,
        end: isha,
      );
    }
    return PrayerWindow(
      current: PrayerSlot.isha,
      next: PrayerSlot.fajr,
      start: isha,
      end: nextFajr,
      nextIsTomorrow: true,
    );
  }

  @override
  List<Object?> get props => [
    day,
    fajr,
    sunrise,
    dhuhr,
    asr,
    maghrib,
    isha,
    previousIsha,
    nextFajr,
  ];
}

/// The stretch of clock the reader is inside, and the two marks that bound it.
class PrayerWindow extends Equatable {
  const PrayerWindow({
    required this.current,
    required this.next,
    required this.start,
    required this.end,
    this.nextIsTomorrow = false,
    this.currentIsYesterday = false,
  });

  /// The slot whose window is open. [PrayerSlot.sunrise] means there is no
  /// prayer at all right now — see [inSunriseGap].
  final PrayerSlot current;

  /// The mark this window runs into. Not always a prayer: between الفجر and
  /// الشروق the thing being counted down to is the *end* of a prayer's time,
  /// which is a different sentence and gets one — see [endsAtSunrise].
  final PrayerSlot next;

  final DateTime start;
  final DateTime end;

  /// [next] belongs to tomorrow's column (فجر, from after العشاء).
  final bool nextIsTomorrow;

  /// [current] opened yesterday evening (عشاء, from before today's فجر).
  final bool currentIsYesterday;

  /// Between الشروق and الظهر: no prayer is owed and none may be offered.
  bool get inSunriseGap => current == PrayerSlot.sunrise;

  /// Inside الفجر, whose time expires at الشروق rather than at the next prayer.
  bool get endsAtSunrise => next == PrayerSlot.sunrise;

  Duration remainingAt(DateTime now) {
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// How far through the window [now] stands, 0…1.
  double progressAt(DateTime now) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 1;
    return (now.difference(start).inSeconds / total).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
    current,
    next,
    start,
    end,
    nextIsTomorrow,
    currentIsYesterday,
  ];
}
