import 'package:shared_preferences/shared_preferences.dart';

import '../domain/prayer_alerts.dart';
import '../domain/prayer_day.dart';

/// Where the prayer-alert choices live between runs.
///
/// On disk rather than only in a cubit because the scheduler is not a screen:
/// it runs at start-up, before any page is built, and it has to know what the
/// reader asked for the last time they were here.
class PrayerAlertsStore {
  const PrayerAlertsStore();

  static const _kEnabled = 'prayer.alerts.enabled';
  static const _kSlots = 'prayer.alerts.slots';
  static const _kReminder = 'prayer.alerts.reminderMinutes';
  static const _kSilent = 'prayer.alerts.silent';

  Future<PrayerAlerts> read() async =>
      readFrom(await SharedPreferences.getInstance());

  /// The same read, for a caller that already holds the preferences.
  PrayerAlerts readFrom(SharedPreferences prefs) {
    final names = prefs.getStringList(_kSlots);
    return PrayerAlerts(
      enabled: prefs.getBool(_kEnabled) ?? false,
      // A stored list that has been emptied is a real answer — "none of them" —
      // and must not fall back to all five. Only its ABSENCE means "never
      // chosen", which is where the default belongs.
      slots: names == null ? PrayerAlerts.everyPrayer : _slotsFrom(names),
      reminderMinutes: prefs.getInt(_kReminder) ?? 0,
      silent: prefs.getBool(_kSilent) ?? false,
    );
  }

  Future<void> write(PrayerAlerts alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, alerts.enabled);
    await prefs.setStringList(_kSlots, [
      for (final slot in alerts.slots) slot.name,
    ]);
    await prefs.setInt(_kReminder, alerts.reminderMinutes);
    await prefs.setBool(_kSilent, alerts.silent);
  }

  static Set<PrayerSlot> _slotsFrom(List<String> names) => {
    for (final name in names)
      for (final slot in PrayerSlot.values)
        // Unknown names are dropped rather than crashing: the list survives a
        // downgrade, and الشروق cannot be smuggled in by hand-editing the file.
        if (slot.name == name && slot.isPrayer) slot,
  };
}
