import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/prayer_times/domain/prayer_alerts.dart';
import 'package:sdhu_operations_project/features/prayer_times/domain/prayer_day.dart';
import 'package:sdhu_operations_project/features/prayer_times/domain/prayer_schedule.dart';

/// What has to be true of a prayer alert BEFORE a phone is involved.
///
/// Everything below is the part of this feature that runs with no platform
/// under it: which occurrences get laid down, and what id each one is given.
/// The part that cannot be tested here — whether Android actually fires the
/// alarm — is the part this deliberately keeps thin.
void main() {
  PrayerDay dayAt(int day) => PrayerDay(
    day: DateTime(2026, 8, day),
    fajr: DateTime(2026, 8, day, 4, 30),
    sunrise: DateTime(2026, 8, day, 5, 55),
    dhuhr: DateTime(2026, 8, day, 12, 25),
    asr: DateTime(2026, 8, day, 15, 45),
    maghrib: DateTime(2026, 8, day, 19, 0),
    isha: DateTime(2026, 8, day, 20, 30),
    previousIsha: DateTime(2026, 8, day - 1, 20, 31),
    nextFajr: DateTime(2026, 8, day + 1, 4, 31),
  );

  final week = [for (var i = 0; i < 7; i++) dayAt(2 + i)];

  group('what gets laid down', () {
    test('nothing at all while the switch is off', () {
      final alarms = PrayerSchedule.alarmsFor(
        days: week,
        alerts: const PrayerAlerts(enabled: false),
        now: DateTime(2026, 8, 2, 3),
      );
      expect(alarms, isEmpty);
    });

    test('nothing when every prayer has been unticked', () {
      // Not the same as the switch being off, and it used to fall back to all
      // five: an empty set is a person saying "none of these", and a phone that
      // then announced all five would be arguing with them.
      final alarms = PrayerSchedule.alarmsFor(
        days: week,
        alerts: const PrayerAlerts(enabled: true, slots: {}),
        now: DateTime(2026, 8, 2, 3),
      );
      expect(alarms, isEmpty);
    });

    test('five a day for a week, and الشروق is not one of them', () {
      final alarms = PrayerSchedule.alarmsFor(
        days: week,
        alerts: const PrayerAlerts(enabled: true),
        now: DateTime(2026, 8, 2, 0, 1),
      );

      expect(alarms.length, 5 * 7);
      expect(alarms.any((a) => a.slot == PrayerSlot.sunrise), isFalse);
      // A week ahead is the point of the horizon: a phone left in a drawer for
      // six days still calls الفجر on the seventh.
      expect(alarms.last.at, DateTime(2026, 8, 8, 20, 30));
    });

    test('anything already past today is dropped', () {
      // The platform refuses a date in the past outright, so this is not a
      // nicety — one stale occurrence would throw and take the rest of the
      // week's scheduling down with it.
      final alarms = PrayerSchedule.alarmsFor(
        days: week,
        alerts: const PrayerAlerts(enabled: true),
        now: DateTime(2026, 8, 2, 13),
      );

      expect(alarms.first.slot, PrayerSlot.asr);
      expect(alarms.first.at, DateTime(2026, 8, 2, 15, 45));
      expect(alarms.length, 5 * 7 - 2);
    });

    test('only the prayers that were ticked', () {
      final alarms = PrayerSchedule.alarmsFor(
        days: week,
        alerts: const PrayerAlerts(
          enabled: true,
          slots: {PrayerSlot.fajr, PrayerSlot.maghrib},
        ),
        now: DateTime(2026, 8, 2),
      );

      expect(alarms.length, 2 * 7);
      expect(
        alarms.map((a) => a.slot).toSet(),
        {PrayerSlot.fajr, PrayerSlot.maghrib},
      );
    });
  });

  group('the warning before the call', () {
    test('doubles the count and lands the right number of minutes early', () {
      final alarms = PrayerSchedule.alarmsFor(
        days: [dayAt(2)],
        alerts: const PrayerAlerts(enabled: true, reminderMinutes: 15),
        now: DateTime(2026, 8, 2),
      );

      expect(alarms.length, 10);
      final first = alarms.first;
      expect(first.isReminder, isTrue);
      expect(first.at, DateTime(2026, 8, 2, 4, 15));
      // It names the moment it is counting toward, not its own — "الفجر بعد ١٥
      // دقيقة، الأذان الساعة ٤:٣٠" and not "الساعة ٤:١٥".
      expect(first.callAt, DateTime(2026, 8, 2, 4, 30));
    });

    test('a warning whose moment has passed goes, and its call stays', () {
      final alarms = PrayerSchedule.alarmsFor(
        days: [dayAt(2)],
        alerts: const PrayerAlerts(enabled: true, reminderMinutes: 15),
        // Between الفجر's warning and الفجر itself.
        now: DateTime(2026, 8, 2, 4, 20),
      );

      expect(alarms.first.isReminder, isFalse);
      expect(alarms.first.at, DateTime(2026, 8, 2, 4, 30));
    });
  });

  group('the ids', () {
    test('the same occurrence always gets the same one', () {
      // This is what makes re-laying the week idempotent: a second pass
      // overwrites its own alarms instead of laying a duplicate beside each.
      final once = PrayerSchedule.alarmsFor(
        days: week,
        alerts: const PrayerAlerts(enabled: true, reminderMinutes: 10),
        now: DateTime(2026, 8, 2),
      );
      final again = PrayerSchedule.alarmsFor(
        days: week,
        alerts: const PrayerAlerts(enabled: true, reminderMinutes: 10),
        now: DateTime(2026, 8, 2),
      );
      expect(once.map((a) => a.id), again.map((a) => a.id));
    });

    test('no two occurrences in a week collide', () {
      final alarms = PrayerSchedule.alarmsFor(
        days: week,
        alerts: const PrayerAlerts(enabled: true, reminderMinutes: 10),
        now: DateTime(2026, 8, 2),
      );
      expect(alarms.map((a) => a.id).toSet().length, alarms.length);
    });

    test('every id falls inside the block this feature owns', () {
      // The block is what lets a cancel-everything drop the prayer alarms
      // without touching the mission's own notifications in the same tray.
      final alarms = PrayerSchedule.alarmsFor(
        days: week,
        alerts: const PrayerAlerts(enabled: true, reminderMinutes: 30),
        now: DateTime(2026, 8, 2),
      );
      expect(alarms.every((a) => PrayerSchedule.owns(a.id)), isTrue);
      expect(PrayerSchedule.owns(PrayerSchedule.idFloor - 1), isFalse);
      expect(PrayerSchedule.owns(PrayerSchedule.idCeiling), isFalse);
    });
  });

  group('the choices themselves', () {
    test('الشروق cannot be ticked', () {
      // Not a guard against the UI, which never offers it: against the stored
      // list, which is a file on the device and can say anything.
      const alerts = PrayerAlerts(enabled: true);
      expect(alerts.toggling(PrayerSlot.sunrise), alerts);
    });

    test('toggling adds and removes', () {
      const alerts = PrayerAlerts(enabled: true);
      final without = alerts.toggling(PrayerSlot.asr);
      expect(without.announcing(PrayerSlot.asr), isFalse);
      expect(without.toggling(PrayerSlot.asr).announcing(PrayerSlot.asr), isTrue);
    });

    test('a reminder needs the alerts to be on at all', () {
      expect(
        const PrayerAlerts(reminderMinutes: 10).reminds,
        isFalse,
      );
      expect(
        const PrayerAlerts(enabled: true, reminderMinutes: 10).reminds,
        isTrue,
      );
    });
  });
}
