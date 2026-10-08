import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/settings/settings_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../data/prayer_alerts_store.dart';
import '../data/prayer_notifications.dart';
import '../data/prayer_times_repository.dart';
import '../domain/prayer_alerts.dart';
import '../domain/prayer_schedule.dart';
import '../domain/prayer_text.dart';

/// Keeps the one thing OUTSIDE the app in step with the choices inside it:
/// the alarms sitting in Android's scheduler.
///
/// They survive the app being closed, and cannot ask a question when they
/// wake up — so they have to be given a week of answers in advance, and
/// re-given them whenever an answer changes. There are exactly four things
/// that change one:
///
///   * the position moved (a new fix, or the first one);
///   * the reader changed what they want announced;
///   * the reader changed the app's language, which the notification text is
///     written in;
///   * a week went by — which is caught by re-laying everything at start-up.
///
/// Rather than four call sites each assembling their own arguments, every one
/// of them calls [refresh] and this reads the current answers back off disk.
/// The position is already persisted by [PrayerTimesRepository], the choices by
/// [PrayerAlertsStore] and the language by [SettingsCubit] — so "what is true
/// now" is a question with one answer and no parameters, which is what makes it
/// safe to call this from a start-up path that knows nothing about any of it.
class PrayerScheduler {
  PrayerScheduler._();
  static final instance = PrayerScheduler._();

  final _repository = PrayerTimesRepository();
  final _store = const PrayerAlertsStore();

  Future<void>? _running;
  bool _asked = false;

  /// Re-lays the alarms from whatever is on disk.
  ///
  /// Calls made while one is already in flight do not queue up one behind the
  /// other — they collapse into a single extra pass at the end, because they
  /// would all read the same state and lay down the same seventy alarms.
  Future<void> refresh() async {
    if (_running != null) {
      _asked = true;
      return _running;
    }
    _running = _refresh();
    try {
      await _running;
    } finally {
      _running = null;
    }
    if (_asked) {
      _asked = false;
      await refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alerts = _store.readFrom(prefs);
      final l = await _strings(prefs);
      final fix = await _repository.lastKnownFix();

      final now = DateTime.now();
      final latitude = fix?.latitude ?? PrayerTimesRepository.fallbackLatitude;
      final longitude =
          fix?.longitude ?? PrayerTimesRepository.fallbackLongitude;

      final days = [
        for (var i = 0; i < PrayerSchedule.horizonDays; i++)
          _repository.dayFor(
            latitude: latitude,
            longitude: longitude,
            // Built by field rather than by adding a Duration: `now + 24h` is
            // an hour short of tomorrow on the day a zone comes off summer
            // time, and lands on the same calendar day twice.
            at: DateTime(now.year, now.month, now.day + i),
          ),
      ];

      // No fix means the times on screen are مكة's, shown to somebody who may
      // be a thousand miles from it and labelled "موقع تقريبي" for exactly that
      // reason. A card may say so; a phone that goes off in the dark may not —
      // so nothing is scheduled until the app knows where it is standing.
      if (alerts.announces && fix != null) {
        await PrayerNotifications.instance.apply(
          PrayerSchedule.alarmsFor(days: days, alerts: alerts, now: now),
          text: (alarm) => _textFor(l, alarm, alerts),
          silent: alerts.silent,
        );
      } else {
        await PrayerNotifications.instance.cancelAll();
      }
    } catch (e, s) {
      AppLogger.error('prayer', 'scheduler refresh failed', e, s);
    }
  }

  /// Turns off everything this device says about prayer, and forgets it.
  ///
  /// Called on sign-out: the next person to hold this phone should not be told
  /// when to pray by an app they have not signed into.
  Future<void> stop() async {
    await PrayerNotifications.instance.cancelAll();
    await _store.write(const PrayerAlerts());
  }

  // ── What an alarm says ─────────────────────────────────────────────────

  PrayerAlarmText _textFor(
    AppLocalizations l,
    PrayerAlarm alarm,
    PrayerAlerts alerts,
  ) {
    final name = slotName(l, alarm.slot);
    final clock = clockText(l, alarm.callAt);
    return alarm.isReminder
        ? PrayerAlarmText(
            title: l.prayerAlertBefore(name, alerts.reminderMinutes),
            body: l.prayerAlertBeforeBody(clock),
          )
        : PrayerAlarmText(
            title: l.prayerAlertNow(name),
            body: l.prayerAlertNowBody(clock),
          );
  }

  // ── Which language all of that is in ───────────────────────────────────

  /// The app's own language, not the phone's.
  ///
  /// A notification raised while the app is closed still belongs to the app,
  /// and somebody who set this app to Arabic on an English phone did so on
  /// purpose. The device's list is only consulted when they made no choice —
  /// which is what "follow the system" means in the settings page.
  Future<AppLocalizations> _strings(SharedPreferences prefs) {
    final chosen = prefs.getString(SettingsCubit.localeKey);
    // Three cases, not two. `null` is somebody who has never opened the
    // settings and gets the app's own default; the sentinel is somebody who
    // asked for the device's language on purpose; anything else is a language
    // they named. Reading the sentinel as a language code would try to load a
    // `Locale('system')` and fall back to whatever the delegate does with it.
    final locale = switch (chosen) {
      null => const Locale('ar'),
      SettingsCubit.followSystem => _deviceLocale(),
      final code => Locale(code),
    };
    return AppLocalizations.delegate.load(locale);
  }

  static Locale _deviceLocale() {
    for (final wanted in PlatformDispatcher.instance.locales) {
      for (final supported in AppLocalizations.supportedLocales) {
        if (supported.languageCode == wanted.languageCode) return supported;
      }
    }
    return AppLocalizations.supportedLocales.first;
  }
}
