import 'package:equatable/equatable.dart';

import 'prayer_alerts.dart';
import 'prayer_day.dart';

/// One notification to be laid down at a moment in the future.
class PrayerAlarm extends Equatable {
  const PrayerAlarm({
    required this.id,
    required this.slot,
    required this.at,
    required this.callAt,
    required this.isReminder,
  });

  /// Stable across runs — see [PrayerSchedule.idFor]. Re-scheduling the same
  /// prayer on the same day overwrites its own alarm rather than laying a
  /// second one beside it.
  final int id;

  final PrayerSlot slot;

  /// When this notification appears.
  final DateTime at;

  /// When the prayer itself is called. Equal to [at] for the call, and later
  /// than it for a reminder — which is what lets the text say "بعد ١٠ دقائق"
  /// and name the time it is counting toward.
  final DateTime callAt;

  /// Whether this is the warning before the call rather than the call.
  final bool isReminder;

  @override
  List<Object?> get props => [id, slot, at, callAt, isReminder];
}

/// Turns a run of days into the alarms to lay down for them.
///
/// This is the whole scheduling policy, and it is pure so that it can be
/// argued with in a test rather than on a phone at half past four in the
/// morning.
///
/// The shape of the problem: a prayer time is a different clock time every day,
/// so there is no "repeat daily at 04:32" to hand the system. Every single
/// occurrence has to be laid down individually, and the app is not running to
/// lay down tomorrow's — it may not be opened for a week. So a horizon of
/// [horizonDays] days is scheduled at once, and it is re-laid from scratch
/// every time the app comes up, every time the position moves and every time
/// the settings change. Seventy alarms is nothing against Android's limit of
/// about five hundred, and it means a phone left in a drawer for six days still
/// calls الفجر on the seventh.
class PrayerSchedule {
  const PrayerSchedule._();

  /// How far ahead alarms are laid down.
  static const horizonDays = 7;

  /// The block of notification ids this feature owns.
  ///
  /// Reserved as a range, so that cancelling can be "drop everything of mine"
  /// without touching the mission's own notifications sitting in the same tray
  /// — those are keyed by a message's hash and could be any int at all.
  static const idFloor = 910000;
  static const idCeiling = idFloor + horizonDays * _idsPerDay;

  /// Six slots for the calls, six for the reminders, per day.
  static const _idsPerDay = 16;

  /// The id a given occurrence always gets.
  static int idFor({
    required int dayIndex,
    required PrayerSlot slot,
    required bool isReminder,
  }) => idFloor + dayIndex * _idsPerDay + (isReminder ? 8 : 0) + slot.index;

  static bool owns(int id) => id >= idFloor && id < idCeiling;

  /// The alarms for [days], in the order they will fire.
  ///
  /// [days] is expected to be consecutive and to start at today — the index of
  /// a day in the list is what fixes its ids. Anything already past [now] is
  /// dropped: the platform refuses a date in the past outright, and a prayer
  /// whose time has come and gone is not news.
  static List<PrayerAlarm> alarmsFor({
    required List<PrayerDay> days,
    required PrayerAlerts alerts,
    required DateTime now,
  }) {
    if (!alerts.announces) return const [];

    final alarms = <PrayerAlarm>[];
    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final day = days[dayIndex];
      for (final slot in PrayerSlot.values) {
        if (!slot.isPrayer || !alerts.announcing(slot)) continue;
        final callAt = day.timeOf(slot);

        if (alerts.reminds) {
          final at = callAt.subtract(Duration(minutes: alerts.reminderMinutes));
          if (at.isAfter(now)) {
            alarms.add(
              PrayerAlarm(
                id: idFor(dayIndex: dayIndex, slot: slot, isReminder: true),
                slot: slot,
                at: at,
                callAt: callAt,
                isReminder: true,
              ),
            );
          }
        }

        if (callAt.isAfter(now)) {
          alarms.add(
            PrayerAlarm(
              id: idFor(dayIndex: dayIndex, slot: slot, isReminder: false),
              slot: slot,
              at: callAt,
              callAt: callAt,
              isReminder: false,
            ),
          );
        }
      }
    }

    alarms.sort((a, b) => a.at.compareTo(b.at));
    return alarms;
  }
}
